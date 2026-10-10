package store

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"cloud.google.com/go/firestore"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
	"github.com/Ilij4n/eho/backend/maps/internal/stats"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Runs against the Firestore emulator only: `make dev` (or `firebase emulators:start`)
// then `FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 go test ./internal/store/`.
func emulatorStore(t *testing.T) *FirestoreStore {
	t.Helper()
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		t.Skip("FIRESTORE_EMULATOR_HOST not set")
	}
	c, err := firestore.NewClient(context.Background(), "demo-eho-test")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return NewFirestoreStore(c)
}

func TestFirestoreStoreLifecycle(t *testing.T) {
	s := emulatorStore(t)
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Millisecond)
	e := &venue.Event{ID: NewID(), Name: "Test", StartDate: "2026-10-10", EndDate: "2026-10-10", OwnerUID: "owner-" + NewID(), CreatedAt: now, UpdatedAt: now}
	if err := s.CreateEvent(ctx, e); err != nil {
		t.Fatal(err)
	}
	got, err := s.GetEvent(ctx, e.ID)
	if err != nil || got.Name != "Test" || got.ID != e.ID {
		t.Fatalf("GetEvent = %+v, %v", got, err)
	}
	list, err := s.ListEventsByOwner(ctx, e.OwnerUID)
	if err != nil || len(list) != 1 {
		t.Fatalf("ListEventsByOwner = %v, %v", list, err)
	}

	f := &venue.Floor{ID: "f1", Name: "P", ImagePath: "events/x/floors/p.png", Width: 100, Height: 100}
	g := &venue.Graph{FloorID: "f1", Nodes: []venue.Node{{ID: "a", X: 1, Y: 1}, {ID: "b", X: 50, Y: 1, Connector: "L", ConnectorKind: "lift"}}, Edges: []venue.Edge{{From: "a", To: "b"}}}
	ft := &venue.Feature{ID: "s1", Type: venue.TypeStand, FloorID: "f1", Name: "S", Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{{X: 2, Y: 2}}}, EntranceNodeID: "a"}
	for _, err := range []error{s.PutFloor(ctx, e.ID, f), s.PutGraph(ctx, e.ID, g), s.PutFeature(ctx, e.ID, ft)} {
		if err != nil {
			t.Fatal(err)
		}
	}
	d, err := s.GetDraft(ctx, e.ID)
	if err != nil || len(d.Floors) != 1 || len(d.Features) != 1 || len(d.Graphs) != 1 || d.Graphs[0].Nodes[1].Connector != "L" {
		t.Fatalf("draft = %+v, %v", d, err)
	}

	blocked := errors.New("blocked")
	if _, err := s.Publish(ctx, e.ID, func(*venue.Map) error { return blocked }); !errors.Is(err, blocked) {
		t.Fatalf("Publish check error not propagated: %v", err)
	}
	v, err := s.Publish(ctx, e.ID, func(*venue.Map) error { return nil })
	if err != nil || v != 1 {
		t.Fatalf("Publish = %d, %v", v, err)
	}
	if err := s.DeleteFeature(ctx, e.ID, "s1"); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteFeature(ctx, e.ID, "s1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("second delete = %v", err)
	}
	pub, pv, err := s.GetPublished(ctx, e.ID)
	if err != nil || pv != 1 || len(pub.Features) != 1 {
		t.Fatalf("published = %+v v=%d err=%v", pub, pv, err)
	}
	if v, _ := s.Publish(ctx, e.ID, func(*venue.Map) error { return nil }); v != 2 {
		t.Fatalf("second publish version = %d", v)
	}
	pub, _, _ = s.GetPublished(ctx, e.ID)
	if len(pub.Features) != 0 {
		t.Fatalf("removed feature still published: %+v", pub.Features)
	}

	if err := s.DeleteFloor(ctx, e.ID, "f1"); err != nil {
		t.Fatal(err)
	}
	if d, _ := s.GetDraft(ctx, e.ID); len(d.Floors)+len(d.Graphs)+len(d.Features) != 0 {
		t.Fatalf("floor cascade failed: %+v", d)
	}
	if err := s.DeleteEvent(ctx, e.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetEvent(ctx, e.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("after delete: %v", err)
	}
}

func TestFirestoreStats(t *testing.T) {
	s := emulatorStore(t)
	ctx := context.Background()
	now := time.Now().UTC()
	e := &venue.Event{ID: NewID(), Name: "Stats", StartDate: "2026-10-10", EndDate: "2026-10-10", OwnerUID: "o", CreatedAt: now, UpdatedAt: now}
	if err := s.CreateEvent(ctx, e); err != nil {
		t.Fatal(err)
	}
	// Search terms are arbitrary text: dots, slashes and backticks must survive.
	odd := []string{"a.b", "c/d", "`x`", "kafa i čaj"}
	for _, date := range []string{"2026-10-10", "2026-10-11", "2026-10-11", "2026-10-12"} {
		d := stats.NewDay(date)
		for _, q := range odd {
			d.Add(stats.Event{Kind: stats.Search, Query: q})
		}
		d.Add(stats.Event{Kind: stats.Route, FeatureID: "s1"})
		if err := s.AddStats(ctx, e.ID, d); err != nil {
			t.Fatal(err)
		}
	}
	days, err := s.ListStats(ctx, e.ID, "2026-10-11", "2026-10-12")
	if err != nil {
		t.Fatal(err)
	}
	if len(days) != 2 || days[0].Date != "2026-10-11" || days[0].Routes != 2 || days[1].Routes != 1 {
		t.Fatalf("days = %+v", days)
	}
	for _, q := range odd {
		if days[0].SearchTerms[q] != 2 || days[0].NoResultTerms[q] != 2 {
			t.Errorf("term %q = %d", q, days[0].SearchTerms[q])
		}
	}
	if err := s.DeleteEvent(ctx, e.ID); err != nil {
		t.Fatal(err)
	}
	refs, err := s.event(e.ID).Collection(colStats).DocumentRefs(ctx).GetAll()
	if err != nil || len(refs) != 0 {
		t.Fatalf("stats left after delete: %d, %v", len(refs), err)
	}
}
