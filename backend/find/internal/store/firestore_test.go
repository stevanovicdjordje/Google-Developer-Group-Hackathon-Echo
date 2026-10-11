package store

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"cloud.google.com/go/firestore"
)

// Runs only against the Firestore emulator (FIRESTORE_EMULATOR_HOST).
func newEmulatorStore(t *testing.T) (*FirestoreStore, *firestore.Client) {
	t.Helper()
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		t.Skip("FIRESTORE_EMULATOR_HOST not set")
	}
	c, err := firestore.NewClient(context.Background(), "demo-eho-test")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return NewFirestoreStore(c), c
}

func TestFirestoreStore(t *testing.T) {
	s, c := newEmulatorStore(t)
	ctx := context.Background()
	ev := "ev_" + NewPersonID()
	u1, u2 := "u1_"+NewPersonID(), "u2_"+NewPersonID()
	now := time.Date(2026, 10, 11, 9, 0, 0, 0, time.UTC)

	if _, err := c.Collection("events").Doc(ev).Set(ctx, map[string]any{"name": "x", "publishedVersion": 2}); err != nil {
		t.Fatal(err)
	}
	if _, err := c.Doc("events/"+ev+"/published/map/features/f1").Set(ctx, map[string]any{"name": "Info pult", "type": "poi"}); err != nil {
		t.Fatal(err)
	}
	if e, err := s.GetEvent(ctx, ev); err != nil || !e.Published() {
		t.Fatalf("event %+v %v", e, err)
	}
	if _, err := s.GetEvent(ctx, "missing-"+ev); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing event: %v", err)
	}
	if name, err := s.FeatureName(ctx, ev, " info PULT"); err != nil || name != "Info pult" {
		t.Fatalf("feature %q %v", name, err)
	}
	if _, err := s.FeatureName(ctx, ev, "Mars"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unknown feature: %v", err)
	}

	if _, err := s.GetProfile(ctx, u1); !errors.Is(err, ErrNotFound) {
		t.Fatalf("no profile: %v", err)
	}
	if err := s.Join(ctx, ev, u1, now); !errors.Is(err, ErrNoProfile) {
		t.Fatalf("join without profile: %v", err)
	}
	p1, err := s.SaveProfile(ctx, u1, ProfileFields{Name: "A", Interests: []string{"Mobile"}, VisibleInFind: true, AllowContact: true}, now)
	if err != nil || len(p1.PersonID) != 16 {
		t.Fatalf("save %+v %v", p1, err)
	}
	again, err := s.SaveProfile(ctx, u1, ProfileFields{Name: "A2", VisibleInFind: true}, now.Add(time.Minute))
	if err != nil || again.PersonID != p1.PersonID || again.Name != "A2" {
		t.Fatalf("resave %+v %v", again, err)
	}
	p2, _ := s.SaveProfile(ctx, u2, ProfileFields{Name: "B", VisibleInFind: true}, now)
	for _, u := range []string{u1, u2} {
		if err := s.Join(ctx, ev, u, now); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.Join(ctx, ev, u1, now.Add(time.Hour)); err != nil { // idempotent
		t.Fatal(err)
	}
	got, _ := s.GetProfile(ctx, u1)
	if len(got.Events) != 1 || got.Events[0] != ev || got.UID != u1 || got.Name != "A2" {
		t.Fatalf("profile %+v", got)
	}
	if ok, _ := s.IsPresent(ctx, ev, u1); !ok {
		t.Fatal("not present")
	}
	people, err := s.People(ctx, ev)
	if err != nil || len(people) != 2 {
		t.Fatalf("people %v %v", people, err)
	}
	a, err := s.PersonByID(ctx, ev, p2.PersonID)
	if err != nil || a.UID != u2 || !a.JoinedAt.Equal(now) {
		t.Fatalf("person %+v %v", a, err)
	}
	if _, err := s.PersonByID(ctx, ev, "nobody"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unknown person: %v", err)
	}

	if _, err := s.GetContact(ctx, ev, u1, u2); !errors.Is(err, ErrNotFound) {
		t.Fatalf("no contact: %v", err)
	}
	if _, err := s.UpdateContact(ctx, ev, u2, u1, func(c *Contact) (*Contact, error) { return nil, nil }); !errors.Is(err, ErrNotFound) {
		t.Fatalf("noop on missing: %v", err)
	}
	ct, err := s.UpdateContact(ctx, ev, u2, u1, func(c *Contact) (*Contact, error) {
		if c != nil {
			t.Fatal("expected none")
		}
		return &Contact{From: u2, State: StateRequested, CreatedAt: now}, nil
	})
	if err != nil || ct.From != u2 {
		t.Fatal(ct, err)
	}
	ct, err = s.UpdateContact(ctx, ev, u1, u2, func(c *Contact) (*Contact, error) {
		c.State = StateAccepted
		c.MeetingSpot = &MeetingSpot{Place: "Info pult", SetBy: u1, UpdatedAt: now}
		return c, nil
	})
	if err != nil || ct.State != StateAccepted {
		t.Fatal(ct, err)
	}
	if cs, _ := s.Contacts(ctx, ev, u2); len(cs) != 1 || cs[0].MeetingSpot == nil || cs[0].MeetingSpot.Place != "Info pult" {
		t.Fatalf("contacts %+v", cs)
	}
	sentinel := errors.New("stop")
	if _, err := s.UpdateContact(ctx, ev, u1, u2, func(c *Contact) (*Contact, error) { return nil, sentinel }); !errors.Is(err, sentinel) {
		t.Fatalf("fn error: %v", err)
	}

	if err := s.Leave(ctx, ev, u2); err != nil {
		t.Fatal(err)
	}
	if ok, _ := s.IsPresent(ctx, ev, u2); ok {
		t.Fatal("still present")
	}
	if p, _ := s.GetProfile(ctx, u2); len(p.Events) != 0 {
		t.Fatalf("events %v", p.Events)
	}

	if err := s.DeleteProfile(ctx, u1); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteProfile(ctx, u1); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetProfile(ctx, u1); !errors.Is(err, ErrNotFound) {
		t.Fatal("profile left")
	}
	if ok, _ := s.IsPresent(ctx, ev, u1); ok {
		t.Fatal("presence left")
	}
	if cs, _ := s.Contacts(ctx, ev, u2); len(cs) != 0 {
		t.Fatalf("contacts left %+v", cs)
	}
}
