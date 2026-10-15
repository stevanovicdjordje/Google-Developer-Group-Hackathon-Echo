package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Firestore layout. Written only by the service (Admin SDK); security rules
// deny clients every path below except the venue map.
//
//	profiles/{uid}                                 Profile
//	events/{eventId}                               venue-map event (read only here)
//	events/{eventId}/published/map/features/{id}   venue-map feature (read only here, `name`)
//	events/{eventId}/people/{uid}                  {personId, joinedAt}
//	events/{eventId}/contacts/{uidA_uidB}          Contact (uids sorted)
const (
	colProfiles = "profiles"
	colEvents   = "events"
	colPeople   = "people"
	colContacts = "contacts"
)

// FirestoreStore implements Store on Cloud Firestore.
type FirestoreStore struct {
	c *firestore.Client
}

// NewFirestoreStore wraps a Firestore client.
func NewFirestoreStore(c *firestore.Client) *FirestoreStore { return &FirestoreStore{c: c} }

var _ Store = (*FirestoreStore)(nil)

type presenceDoc struct {
	PersonID string    `firestore:"personId"`
	JoinedAt time.Time `firestore:"joinedAt"`
}

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

func (s *FirestoreStore) profile(uid string) *firestore.DocumentRef {
	return s.c.Collection(colProfiles).Doc(uid)
}

func (s *FirestoreStore) event(id string) *firestore.DocumentRef {
	return s.c.Collection(colEvents).Doc(id)
}

func (s *FirestoreStore) presence(eventID, uid string) *firestore.DocumentRef {
	return s.event(eventID).Collection(colPeople).Doc(uid)
}

func (s *FirestoreStore) contact(eventID, x, y string) *firestore.DocumentRef {
	_, _, id := Pair(x, y)
	return s.event(eventID).Collection(colContacts).Doc(id)
}

func (s *FirestoreStore) GetEvent(ctx context.Context, id string) (Event, error) {
	snap, err := s.event(id).Get(ctx)
	if isNotFound(err) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("get event: %w", err)
	}
	var e Event
	if err := snap.DataTo(&e); err != nil {
		return Event{}, fmt.Errorf("decode event: %w", err)
	}
	return e, nil
}

func decodeProfile(snap *firestore.DocumentSnapshot) (Profile, error) {
	var p Profile
	if err := snap.DataTo(&p); err != nil {
		return Profile{}, fmt.Errorf("decode profile: %w", err)
	}
	p.UID = snap.Ref.ID
	return p, nil
}

func (s *FirestoreStore) GetProfile(ctx context.Context, uid string) (Profile, error) {
	snap, err := s.profile(uid).Get(ctx)
	if isNotFound(err) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, fmt.Errorf("get profile: %w", err)
	}
	return decodeProfile(snap)
}

func (s *FirestoreStore) SaveProfile(ctx context.Context, uid string, f ProfileFields, now time.Time) (Profile, error) {
	var out Profile
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		ref := s.profile(uid)
		p := Profile{UID: uid}
		snap, err := tx.Get(ref)
		switch {
		case err == nil:
			if p, err = decodeProfile(snap); err != nil {
				return err
			}
		case !isNotFound(err):
			return fmt.Errorf("get profile: %w", err)
		}
		p.ProfileFields = f
		p.UpdatedAt = now
		if p.PersonID == "" {
			p.PersonID = NewPersonID()
		}
		if p.Interests == nil {
			p.Interests = []string{}
		}
		if p.Events == nil {
			p.Events = []string{}
		}
		out = p
		return tx.Set(ref, p)
	})
	if err != nil {
		return Profile{}, fmt.Errorf("save profile: %w", err)
	}
	return out, nil
}

func (s *FirestoreStore) DeleteProfile(ctx context.Context, uid string) error {
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		ref := s.profile(uid)
		snap, err := tx.Get(ref)
		if isNotFound(err) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("get profile: %w", err)
		}
		p, err := decodeProfile(snap)
		if err != nil {
			return err
		}
		var dels []*firestore.DocumentRef
		for _, ev := range p.Events {
			dels = append(dels, s.presence(ev, uid))
			for _, side := range []string{"a", "b"} {
				q := s.event(ev).Collection(colContacts).Where(side, "==", uid)
				docs, err := tx.Documents(q).GetAll()
				if err != nil {
					return fmt.Errorf("list contacts: %w", err)
				}
				for _, d := range docs {
					dels = append(dels, d.Ref)
				}
			}
		}
		for _, d := range append(dels, ref) {
			if err := tx.Delete(d); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("delete profile: %w", err)
	}
	return nil
}

func (s *FirestoreStore) Join(ctx context.Context, eventID, uid string, now time.Time) error {
	return s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(s.profile(uid))
		if isNotFound(err) {
			return ErrNoProfile
		}
		if err != nil {
			return fmt.Errorf("get profile: %w", err)
		}
		p, err := decodeProfile(snap)
		if err != nil {
			return err
		}
		pres := s.presence(eventID, uid)
		psnap, err := tx.Get(pres)
		if err != nil && !isNotFound(err) {
			return fmt.Errorf("get presence: %w", err)
		}
		joined := now
		if err == nil {
			var d presenceDoc
			if derr := psnap.DataTo(&d); derr == nil && !d.JoinedAt.IsZero() {
				joined = d.JoinedAt
			}
		}
		if err := tx.Set(pres, presenceDoc{PersonID: p.PersonID, JoinedAt: joined}); err != nil {
			return err
		}
		return tx.Update(s.profile(uid), []firestore.Update{{Path: "events", Value: firestore.ArrayUnion(eventID)}})
	})
}

func (s *FirestoreStore) Leave(ctx context.Context, eventID, uid string) error {
	if _, err := s.presence(eventID, uid).Delete(ctx); err != nil {
		return fmt.Errorf("delete presence: %w", err)
	}
	_, err := s.profile(uid).Update(ctx, []firestore.Update{{Path: "events", Value: firestore.ArrayRemove(eventID)}})
	if err != nil && !isNotFound(err) {
		return fmt.Errorf("update profile: %w", err)
	}
	return nil
}

func (s *FirestoreStore) IsPresent(ctx context.Context, eventID, uid string) (bool, error) {
	_, err := s.presence(eventID, uid).Get(ctx)
	if isNotFound(err) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("get presence: %w", err)
	}
	return true, nil
}

func (s *FirestoreStore) People(ctx context.Context, eventID string) ([]Attendee, error) {
	docs, err := s.event(eventID).Collection(colPeople).Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("list people: %w", err)
	}
	if len(docs) == 0 {
		return nil, nil
	}
	joined := make(map[string]time.Time, len(docs))
	refs := make([]*firestore.DocumentRef, 0, len(docs))
	for _, d := range docs {
		var pd presenceDoc
		_ = d.DataTo(&pd)
		joined[d.Ref.ID] = pd.JoinedAt
		refs = append(refs, s.profile(d.Ref.ID))
	}
	snaps, err := s.c.GetAll(ctx, refs)
	if err != nil {
		return nil, fmt.Errorf("get profiles: %w", err)
	}
	out := make([]Attendee, 0, len(snaps))
	for _, snap := range snaps {
		if !snap.Exists() {
			continue
		}
		p, err := decodeProfile(snap)
		if err != nil {
			return nil, err
		}
		out = append(out, Attendee{Profile: p, JoinedAt: joined[p.UID]})
	}
	return out, nil
}

func (s *FirestoreStore) PersonByID(ctx context.Context, eventID, personID string) (Attendee, error) {
	it := s.event(eventID).Collection(colPeople).Where("personId", "==", personID).Limit(1).Documents(ctx)
	defer it.Stop()
	d, err := it.Next()
	if errors.Is(err, iterator.Done) {
		return Attendee{}, ErrNotFound
	}
	if err != nil {
		return Attendee{}, fmt.Errorf("find person: %w", err)
	}
	var pd presenceDoc
	_ = d.DataTo(&pd)
	p, err := s.GetProfile(ctx, d.Ref.ID)
	if err != nil {
		return Attendee{}, err
	}
	if p.PersonID != personID {
		return Attendee{}, ErrNotFound
	}
	return Attendee{Profile: p, JoinedAt: pd.JoinedAt}, nil
}

func (s *FirestoreStore) GetContact(ctx context.Context, eventID, x, y string) (Contact, error) {
	snap, err := s.contact(eventID, x, y).Get(ctx)
	if isNotFound(err) {
		return Contact{}, ErrNotFound
	}
	if err != nil {
		return Contact{}, fmt.Errorf("get contact: %w", err)
	}
	var c Contact
	if err := snap.DataTo(&c); err != nil {
		return Contact{}, fmt.Errorf("decode contact: %w", err)
	}
	return c, nil
}

func (s *FirestoreStore) UpdateContact(ctx context.Context, eventID, x, y string, fn func(c *Contact) (*Contact, error)) (Contact, error) {
	a, b, _ := Pair(x, y)
	ref := s.contact(eventID, x, y)
	var out Contact
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		var cur *Contact
		snap, err := tx.Get(ref)
		switch {
		case err == nil:
			var c Contact
			if err := snap.DataTo(&c); err != nil {
				return fmt.Errorf("decode contact: %w", err)
			}
			cur = &c
		case !isNotFound(err):
			return fmt.Errorf("get contact: %w", err)
		}
		next, err := fn(cur)
		if err != nil {
			return err
		}
		if next == nil {
			if cur == nil {
				return ErrNotFound
			}
			out = *cur
			return nil
		}
		next.A, next.B = a, b
		out = *next
		return tx.Set(ref, *next)
	})
	if err != nil {
		return Contact{}, err
	}
	return out, nil
}

func (s *FirestoreStore) Contacts(ctx context.Context, eventID, uid string) ([]Contact, error) {
	var out []Contact
	for _, side := range []string{"a", "b"} {
		docs, err := s.event(eventID).Collection(colContacts).Where(side, "==", uid).Documents(ctx).GetAll()
		if err != nil {
			return nil, fmt.Errorf("list contacts: %w", err)
		}
		for _, d := range docs {
			var c Contact
			if err := d.DataTo(&c); err != nil {
				return nil, fmt.Errorf("decode contact: %w", err)
			}
			out = append(out, c)
		}
	}
	return out, nil
}

func (s *FirestoreStore) FeatureName(ctx context.Context, eventID, place string) (string, error) {
	place = strings.TrimSpace(place)
	it := s.event(eventID).Collection("published").Doc("map").Collection("features").Documents(ctx)
	defer it.Stop()
	for {
		d, err := it.Next()
		if errors.Is(err, iterator.Done) {
			return "", ErrNotFound
		}
		if err != nil {
			return "", fmt.Errorf("list features: %w", err)
		}
		if name, _ := d.Data()["name"].(string); name != "" && strings.EqualFold(strings.TrimSpace(name), place) {
			return name, nil
		}
	}
}
