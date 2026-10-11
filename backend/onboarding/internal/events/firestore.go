package events

import (
	"context"
	"errors"
	"fmt"
	"io"
	"sort"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// FirestoreRepo reads and writes the shared event documents.
//
//	events/{eventId}                          shared with backend/maps and backend/events:
//	                                          name, startDate, endDate, address, ownerUid,
//	                                          publishedVersion (map, read only here), createdAt, updatedAt;
//	                                          added by this module: description, startsAt, endsAt,
//	                                          lat, lng, listedAt
//	events/{eventId}/draft/map                created with a new event, so the map editor can open it
//	events/{eventId}/published/agenda         the agenda (same format as backend/events)
//	events/{eventId}/published/map/{floors,features}  the venue map (read only here)
//
// Other services update the event document field by field, so the extra
// fields survive their writes and vice versa.
type FirestoreRepo struct {
	c   *firestore.Client
	loc *time.Location
}

func NewFirestoreRepo(c *firestore.Client, loc *time.Location) *FirestoreRepo {
	return &FirestoreRepo{c: c, loc: loc}
}

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

func (r *FirestoreRepo) doc(id string) *firestore.DocumentRef {
	return r.c.Collection("events").Doc(id)
}

type eventDoc struct {
	Name             string     `firestore:"name"`
	StartDate        string     `firestore:"startDate"`
	EndDate          string     `firestore:"endDate"`
	Address          string     `firestore:"address"`
	OwnerUID         string     `firestore:"ownerUid"`
	PublishedVersion int        `firestore:"publishedVersion"`
	CreatedAt        time.Time  `firestore:"createdAt"`
	UpdatedAt        time.Time  `firestore:"updatedAt"`
	Description      string     `firestore:"description"`
	StartsAt         *time.Time `firestore:"startsAt"`
	EndsAt           *time.Time `firestore:"endsAt"`
	Lat              *float64   `firestore:"lat"`
	Lng              *float64   `firestore:"lng"`
	ListedAt         *time.Time `firestore:"listedAt"`
}

func (r *FirestoreRepo) date(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.In(r.loc).Format(dayLayout)
}

func (r *FirestoreRepo) toEvent(id string, d eventDoc) Event {
	e := Event{ID: id, OwnerUID: d.OwnerUID, Title: d.Name, Description: d.Description, Address: d.Address,
		StartsAt: d.StartsAt, EndsAt: d.EndsAt, Lat: d.Lat, Lng: d.Lng, PublishedAt: d.ListedAt,
		MapVersion: d.PublishedVersion, CreatedAt: d.CreatedAt, UpdatedAt: d.UpdatedAt}
	// Events created in the app only have dates: span the whole days.
	if e.StartsAt == nil && d.StartDate != "" {
		if t, err := time.ParseInLocation(dayLayout, d.StartDate, r.loc); err == nil {
			t = t.UTC()
			e.StartsAt = &t
		}
	}
	if e.EndsAt == nil {
		end := d.EndDate
		if end == "" {
			end = d.StartDate
		}
		if t, err := time.ParseInLocation(dayLayout, end, r.loc); err == nil {
			// Until the end of that day (23:59).
			t = t.AddDate(0, 0, 1).Add(-time.Minute).UTC()
			e.EndsAt = &t
		}
	}
	return e
}

func (r *FirestoreRepo) Create(ctx context.Context, e Event) error {
	batch := r.c.Batch()
	batch.Create(r.doc(e.ID), eventDoc{Name: e.Title, StartDate: r.date(e.StartsAt), EndDate: r.date(e.EndsAt),
		Address: e.Address, OwnerUID: e.OwnerUID, CreatedAt: e.CreatedAt, UpdatedAt: e.UpdatedAt,
		Description: e.Description, StartsAt: e.StartsAt, EndsAt: e.EndsAt, Lat: e.Lat, Lng: e.Lng, ListedAt: e.PublishedAt})
	batch.Set(r.doc(e.ID).Collection("draft").Doc("map"), map[string]any{"updatedAt": e.CreatedAt})
	_, err := batch.Commit(ctx)
	return err
}

func (r *FirestoreRepo) Update(ctx context.Context, e Event) error {
	_, err := r.doc(e.ID).Update(ctx, []firestore.Update{
		{Path: "name", Value: e.Title},
		{Path: "startDate", Value: r.date(e.StartsAt)},
		{Path: "endDate", Value: r.date(e.EndsAt)},
		{Path: "address", Value: e.Address},
		{Path: "updatedAt", Value: e.UpdatedAt},
		{Path: "description", Value: e.Description},
		{Path: "startsAt", Value: e.StartsAt},
		{Path: "endsAt", Value: e.EndsAt},
		{Path: "lat", Value: e.Lat},
		{Path: "lng", Value: e.Lng},
		{Path: "listedAt", Value: e.PublishedAt},
	})
	if isNotFound(err) {
		return ErrNotFound
	}
	return err
}

func (r *FirestoreRepo) Get(ctx context.Context, id string) (Event, error) {
	snap, err := r.doc(id).Get(ctx)
	if isNotFound(err) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, err
	}
	var d eventDoc
	if err := snap.DataTo(&d); err != nil {
		return Event{}, fmt.Errorf("decode event %s: %w", id, err)
	}
	return r.toEvent(id, d), nil
}

func (r *FirestoreRepo) ListByOwner(ctx context.Context, uid string) ([]Event, error) {
	snaps, err := r.c.Collection("events").Where("ownerUid", "==", uid).Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	out := make([]Event, 0, len(snaps))
	for _, snap := range snaps {
		var d eventDoc
		if err := snap.DataTo(&d); err != nil {
			return nil, fmt.Errorf("decode event %s: %w", snap.Ref.ID, err)
		}
		out = append(out, r.toEvent(snap.Ref.ID, d))
	}
	return out, nil
}

func (r *FirestoreRepo) agenda(id string) *firestore.DocumentRef {
	return r.doc(id).Collection("published").Doc("agenda")
}

func (r *FirestoreRepo) GetAgenda(ctx context.Context, id string) (Agenda, error) {
	snap, err := r.agenda(id).Get(ctx)
	if isNotFound(err) {
		return Agenda{}, nil
	}
	if err != nil {
		return Agenda{}, err
	}
	var a Agenda
	if err := snap.DataTo(&a); err != nil {
		return Agenda{}, fmt.Errorf("decode agenda %s: %w", id, err)
	}
	return a, nil
}

func (r *FirestoreRepo) SaveAgenda(ctx context.Context, id string, a Agenda) error {
	a.Normalize()
	_, err := r.agenda(id).Set(ctx, a)
	return err
}

func (r *FirestoreRepo) GetPublishedMap(ctx context.Context, id string) (Map, error) {
	pub := r.doc(id).Collection("published").Doc("map")
	floors, err := pub.Collection("floors").Documents(ctx).GetAll()
	if err != nil {
		return Map{}, err
	}
	var m Map
	for _, s := range floors {
		var f Floor
		if err := s.DataTo(&f); err != nil {
			return Map{}, fmt.Errorf("decode floor: %w", err)
		}
		f.ID = s.Ref.ID
		m.Floors = append(m.Floors, f)
	}
	features, err := pub.Collection("features").Documents(ctx).GetAll()
	if err != nil {
		return Map{}, err
	}
	for _, s := range features {
		var f Feature
		if err := s.DataTo(&f); err != nil {
			return Map{}, fmt.Errorf("decode feature: %w", err)
		}
		f.ID = s.Ref.ID
		m.Features = append(m.Features, f)
	}
	sort.SliceStable(m.Features, func(i, j int) bool { return m.Features[i].Name < m.Features[j].Name })
	return m, nil
}

// StorageImages reads floor-plan images from the project's Storage bucket.
type StorageImages struct {
	Bucket *storage.BucketHandle
}

func (s StorageImages) FloorImage(ctx context.Context, path string) (io.ReadCloser, string, error) {
	rd, err := s.Bucket.Object(path).NewReader(ctx)
	if errors.Is(err, storage.ErrObjectNotExist) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", err
	}
	return rd, rd.Attrs.ContentType, nil
}
