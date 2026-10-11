package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

// FirestoreStore implements Store on Cloud Firestore (layout in store.go).
type FirestoreStore struct {
	c *firestore.Client
}

var _ Store = (*FirestoreStore)(nil)

// NewFirestoreStore wraps a Firestore client.
func NewFirestoreStore(c *firestore.Client) *FirestoreStore { return &FirestoreStore{c: c} }

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

func (s *FirestoreStore) event(id string) *firestore.DocumentRef {
	return s.c.Collection("events").Doc(id)
}

func (s *FirestoreStore) agendaDoc(id string) *firestore.DocumentRef {
	return s.event(id).Collection("published").Doc("agenda")
}

// eventDoc mirrors the venue map's event fields (backend/maps venue.Event).
type eventDoc struct {
	Name             string    `firestore:"name"`
	StartDate        string    `firestore:"startDate"`
	EndDate          string    `firestore:"endDate"`
	Address          string    `firestore:"address"`
	OwnerUID         string    `firestore:"ownerUid"`
	PublishedVersion int       `firestore:"publishedVersion"`
	CreatedAt        time.Time `firestore:"createdAt"`
	UpdatedAt        time.Time `firestore:"updatedAt"`
}

func (s *FirestoreStore) GetEvent(ctx context.Context, id string) (*Event, error) {
	snap, err := s.event(id).Get(ctx)
	if isNotFound(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get event: %w", err)
	}
	var d eventDoc
	if err := snap.DataTo(&d); err != nil {
		return nil, fmt.Errorf("decode event: %w", err)
	}
	return &Event{ID: id, Name: d.Name, StartDate: d.StartDate, EndDate: d.EndDate, Address: d.Address,
		OwnerUID: d.OwnerUID, PublishedVersion: d.PublishedVersion}, nil
}

func (s *FirestoreStore) HasMap(ctx context.Context, id string) (bool, error) {
	e, err := s.GetEvent(ctx, id)
	if errors.Is(err, ErrNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return e.PublishedVersion > 0, nil
}

func (s *FirestoreStore) RoomNames(ctx context.Context, id string) ([]string, error) {
	it := s.event(id).Collection("published").Doc("map").Collection("features").
		Where("type", "==", "room").Documents(ctx)
	defer it.Stop()
	var out []string
	for {
		snap, err := it.Next()
		if errors.Is(err, iterator.Done) {
			return out, nil
		}
		if err != nil {
			return nil, fmt.Errorf("list rooms: %w", err)
		}
		if n, ok := snap.Data()["name"].(string); ok && n != "" {
			out = append(out, n)
		}
	}
}

func (s *FirestoreStore) GetAgenda(ctx context.Context, id string) (*agenda.Agenda, error) {
	snap, err := s.agendaDoc(id).Get(ctx)
	if isNotFound(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get agenda: %w", err)
	}
	var a agenda.Agenda
	if err := snap.DataTo(&a); err != nil {
		return nil, fmt.Errorf("decode agenda: %w", err)
	}
	a.EventID = id
	fixNil(&a)
	return &a, nil
}

// fixNil turns Firestore's missing arrays into empty ones (JSON [] not null).
func fixNil(a *agenda.Agenda) {
	if a.Stages == nil {
		a.Stages = []string{}
	}
	if a.Speakers == nil {
		a.Speakers = []agenda.Speaker{}
	}
	if a.Sessions == nil {
		a.Sessions = []agenda.Session{}
	}
	for i := range a.Sessions {
		if a.Sessions[i].Speakers == nil {
			a.Sessions[i].Speakers = []agenda.Speaker{}
		}
	}
}

func (s *FirestoreStore) PublishAgenda(ctx context.Context, p Publication) error {
	ref := s.event(p.Event.ID)
	now := p.Agenda.PublishedAt
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		_, err := tx.Get(ref)
		exists := err == nil
		if err != nil && !isNotFound(err) {
			return err
		}
		var draftRef *firestore.DocumentRef
		if p.DraftID != "" {
			draftRef = s.c.Collection("organizerDrafts").Doc(p.DraftID)
			if _, err := tx.Get(draftRef); err != nil {
				if isNotFound(err) {
					return ErrNotFound
				}
				return err
			}
		}
		switch {
		case p.Create && exists:
			return ErrConflict
		case !p.Create && !exists:
			return ErrNotFound
		case p.Create:
			e := p.Event
			if err := tx.Create(ref, eventDoc{Name: e.Name, StartDate: e.StartDate, EndDate: e.EndDate,
				Address: e.Address, OwnerUID: e.OwnerUID, CreatedAt: now, UpdatedAt: now}); err != nil {
				return err
			}
			// The venue map's editor expects a draft map doc for every event.
			if err := tx.Set(ref.Collection("draft").Doc("map"), map[string]any{"updatedAt": now}); err != nil {
				return err
			}
		default:
			if err := tx.Update(ref, []firestore.Update{
				{Path: "name", Value: p.Event.Name}, {Path: "startDate", Value: p.Event.StartDate},
				{Path: "endDate", Value: p.Event.EndDate}, {Path: "address", Value: p.Event.Address},
				{Path: "updatedAt", Value: now},
			}); err != nil {
				return err
			}
		}
		if err := tx.Set(s.agendaDoc(p.Event.ID), p.Agenda); err != nil {
			return err
		}
		if draftRef != nil {
			return tx.Update(draftRef, []firestore.Update{{Path: "publishedEventId", Value: p.Event.ID}})
		}
		return nil
	})
	if errors.Is(err, ErrNotFound) || errors.Is(err, ErrConflict) {
		return err
	}
	if err != nil {
		return fmt.Errorf("publish agenda: %w", err)
	}
	return nil
}

func (s *FirestoreStore) member(uid, eventID string) *firestore.DocumentRef {
	return s.c.Collection("members").Doc(uid).Collection("events").Doc(eventID)
}

func (s *FirestoreStore) Join(ctx context.Context, uid, eventID string, at time.Time) error {
	_, err := s.member(uid, eventID).Create(ctx, map[string]any{"joinedAt": at})
	if status.Code(err) == codes.AlreadyExists {
		return nil // keep the first join time
	}
	if err != nil {
		return fmt.Errorf("join: %w", err)
	}
	return nil
}

func (s *FirestoreStore) Leave(ctx context.Context, uid, eventID string) error {
	if _, err := s.member(uid, eventID).Delete(ctx); err != nil && !isNotFound(err) {
		return fmt.Errorf("leave: %w", err)
	}
	return nil
}

func (s *FirestoreStore) ListMemberships(ctx context.Context, uid string) ([]Membership, error) {
	snaps, err := s.c.Collection("members").Doc(uid).Collection("events").Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("list memberships: %w", err)
	}
	out := []Membership{}
	for _, snap := range snaps {
		at, _ := snap.Data()["joinedAt"].(time.Time)
		out = append(out, Membership{EventID: snap.Ref.ID, JoinedAt: at})
	}
	sortMemberships(out)
	return out, nil
}

type draftDoc struct {
	OwnerUID         string         `firestore:"ownerUid"`
	Fields           agenda.Fields  `firestore:"fields"`
	Issues           []agenda.Issue `firestore:"issues"`
	Model            string         `firestore:"model"`
	SourceFiles      []SourceFile   `firestore:"sourceFiles"`
	PublishedEventID string         `firestore:"publishedEventId"`
	CreatedAt        time.Time      `firestore:"createdAt"`
	UpdatedAt        time.Time      `firestore:"updatedAt"`
}

func toDoc(d *Draft) draftDoc {
	return draftDoc{OwnerUID: d.OwnerUID, Fields: d.Fields, Issues: d.Issues, Model: d.Model, SourceFiles: d.SourceFiles,
		PublishedEventID: d.PublishedEventID, CreatedAt: d.CreatedAt, UpdatedAt: d.UpdatedAt}
}

func (s *FirestoreStore) draft(id string) *firestore.DocumentRef {
	return s.c.Collection("organizerDrafts").Doc(id)
}

func (s *FirestoreStore) CreateDraft(ctx context.Context, d *Draft) error {
	_, err := s.draft(d.ID).Create(ctx, toDoc(d))
	if status.Code(err) == codes.AlreadyExists {
		return ErrConflict
	}
	if err != nil {
		return fmt.Errorf("create draft: %w", err)
	}
	return nil
}

func (s *FirestoreStore) GetDraft(ctx context.Context, id string) (*Draft, error) {
	snap, err := s.draft(id).Get(ctx)
	if isNotFound(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get draft: %w", err)
	}
	var doc draftDoc
	if err := snap.DataTo(&doc); err != nil {
		return nil, fmt.Errorf("decode draft: %w", err)
	}
	a := agenda.Agenda{Stages: doc.Fields.Stages, Speakers: doc.Fields.Speakers, Sessions: doc.Fields.Sessions}
	fixNil(&a)
	doc.Fields.Stages, doc.Fields.Speakers, doc.Fields.Sessions = a.Stages, a.Speakers, a.Sessions
	if doc.Issues == nil {
		doc.Issues = []agenda.Issue{}
	}
	if doc.SourceFiles == nil {
		doc.SourceFiles = []SourceFile{}
	}
	return &Draft{ID: id, OwnerUID: doc.OwnerUID, Fields: doc.Fields, Issues: doc.Issues, Model: doc.Model,
		SourceFiles: doc.SourceFiles, PublishedEventID: doc.PublishedEventID, CreatedAt: doc.CreatedAt, UpdatedAt: doc.UpdatedAt}, nil
}

func (s *FirestoreStore) UpdateDraft(ctx context.Context, d *Draft) error {
	_, err := s.draft(d.ID).Set(ctx, toDoc(d))
	if err != nil {
		return fmt.Errorf("update draft: %w", err)
	}
	return nil
}
