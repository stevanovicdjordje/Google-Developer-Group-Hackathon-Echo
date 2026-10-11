package store

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/Ilij4n/eho/backend/maps/internal/stats"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Firestore layout (clients may read published/**, see contracts/maps/realtime.md):
//
//	events/{eventId}                                  venue.Event
//	events/{eventId}/draft/map                        {updatedAt}
//	events/{eventId}/draft/map/floors/{floorId}       venue.Floor
//	events/{eventId}/draft/map/features/{featureId}   venue.Feature
//	events/{eventId}/draft/map/graphs/{floorId}       venue.Graph
//	events/{eventId}/published/map                    {version, publishedAt}
//	events/{eventId}/published/map/...                same as draft
//	events/{eventId}/stats/{yyyy-mm-dd}               stats.Day (owner only)
const (
	colEvents   = "events"
	colFloors   = "floors"
	colFeatures = "features"
	colGraphs   = "graphs"
	colStats    = "stats"
	mapDocID    = "map"
)

// FirestoreStore implements Store on Cloud Firestore.
type FirestoreStore struct {
	c *firestore.Client
}

// NewFirestoreStore wraps a Firestore client.
func NewFirestoreStore(c *firestore.Client) *FirestoreStore { return &FirestoreStore{c: c} }

var _ Store = (*FirestoreStore)(nil)

func (s *FirestoreStore) event(id string) *firestore.DocumentRef {
	return s.c.Collection(colEvents).Doc(id)
}

func (s *FirestoreStore) mapDoc(id, version string) *firestore.DocumentRef {
	return s.event(id).Collection(version).Doc(mapDocID)
}

func (s *FirestoreStore) draft(id string) *firestore.DocumentRef { return s.mapDoc(id, "draft") }

func (s *FirestoreStore) published(id string) *firestore.DocumentRef {
	return s.mapDoc(id, "published")
}

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

func (s *FirestoreStore) CreateEvent(ctx context.Context, e *venue.Event) error {
	batch := s.c.Batch()
	batch.Create(s.event(e.ID), e)
	batch.Set(s.draft(e.ID), map[string]any{"updatedAt": e.CreatedAt})
	if _, err := batch.Commit(ctx); err != nil {
		if status.Code(err) == codes.AlreadyExists {
			return ErrConflict
		}
		return fmt.Errorf("create event: %w", err)
	}
	return nil
}

func (s *FirestoreStore) GetEvent(ctx context.Context, id string) (*venue.Event, error) {
	snap, err := s.event(id).Get(ctx)
	if isNotFound(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get event: %w", err)
	}
	var e venue.Event
	if err := snap.DataTo(&e); err != nil {
		return nil, fmt.Errorf("decode event: %w", err)
	}
	e.ID = snap.Ref.ID
	return &e, nil
}

func (s *FirestoreStore) ListEventsByOwner(ctx context.Context, owner string) ([]venue.Event, error) {
	snaps, err := s.c.Collection(colEvents).Where("ownerUid", "==", owner).Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("list events: %w", err)
	}
	out := make([]venue.Event, 0, len(snaps))
	for _, snap := range snaps {
		var e venue.Event
		if err := snap.DataTo(&e); err != nil {
			return nil, fmt.Errorf("decode event %s: %w", snap.Ref.ID, err)
		}
		e.ID = snap.Ref.ID
		out = append(out, e)
	}
	// Sorted here to avoid needing a composite index.
	slices.SortFunc(out, func(a, b venue.Event) int { return b.CreatedAt.Compare(a.CreatedAt) })
	return out, nil
}

func (s *FirestoreStore) UpdateEvent(ctx context.Context, e *venue.Event) error {
	_, err := s.event(e.ID).Update(ctx, []firestore.Update{
		{Path: "name", Value: e.Name},
		{Path: "startDate", Value: e.StartDate},
		{Path: "endDate", Value: e.EndDate},
		{Path: "address", Value: e.Address},
		{Path: "updatedAt", Value: e.UpdatedAt},
	})
	if isNotFound(err) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("update event: %w", err)
	}
	return nil
}

func (s *FirestoreStore) DeleteEvent(ctx context.Context, id string) error {
	if _, err := s.GetEvent(ctx, id); err != nil {
		return err
	}
	bw := s.c.BulkWriter(ctx)
	for _, version := range []string{"draft", "published"} {
		m := s.mapDoc(id, version)
		for _, col := range []string{colFloors, colFeatures, colGraphs} {
			refs, err := m.Collection(col).DocumentRefs(ctx).GetAll()
			if err != nil {
				return fmt.Errorf("list %s/%s: %w", version, col, err)
			}
			for _, r := range refs {
				if _, err := bw.Delete(r); err != nil {
					return fmt.Errorf("delete %s: %w", r.Path, err)
				}
			}
		}
		if _, err := bw.Delete(m); err != nil {
			return fmt.Errorf("delete %s: %w", m.Path, err)
		}
	}
	statRefs, err := s.event(id).Collection(colStats).DocumentRefs(ctx).GetAll()
	if err != nil {
		return fmt.Errorf("list stats: %w", err)
	}
	for _, r := range statRefs {
		if _, err := bw.Delete(r); err != nil {
			return fmt.Errorf("delete %s: %w", r.Path, err)
		}
	}
	bw.End()
	if _, err := s.event(id).Delete(ctx); err != nil {
		return fmt.Errorf("delete event: %w", err)
	}
	return nil
}

func decodeAll[T any](snaps []*firestore.DocumentSnapshot, setID func(*T, string)) ([]T, error) {
	out := make([]T, 0, len(snaps))
	for _, snap := range snaps {
		var v T
		if err := snap.DataTo(&v); err != nil {
			return nil, fmt.Errorf("decode %s: %w", snap.Ref.Path, err)
		}
		setID(&v, snap.Ref.ID)
		out = append(out, v)
	}
	return out, nil
}

// readMap loads a whole map (draft or published). If tx is non-nil, reads happen in it.
func (s *FirestoreStore) readMap(ctx context.Context, tx *firestore.Transaction, m *firestore.DocumentRef) (*venue.Map, error) {
	get := func(col string) ([]*firestore.DocumentSnapshot, error) {
		q := m.Collection(col).Query
		if tx != nil {
			return tx.Documents(q).GetAll()
		}
		return q.Documents(ctx).GetAll()
	}
	floors, err := get(colFloors)
	if err != nil {
		return nil, fmt.Errorf("read floors: %w", err)
	}
	features, err := get(colFeatures)
	if err != nil {
		return nil, fmt.Errorf("read features: %w", err)
	}
	graphs, err := get(colGraphs)
	if err != nil {
		return nil, fmt.Errorf("read graphs: %w", err)
	}
	var out venue.Map
	if out.Floors, err = decodeAll(floors, func(f *venue.Floor, id string) { f.ID = id }); err != nil {
		return nil, err
	}
	if out.Features, err = decodeAll(features, func(f *venue.Feature, id string) { f.ID = id }); err != nil {
		return nil, err
	}
	if out.Graphs, err = decodeAll(graphs, func(g *venue.Graph, id string) { g.FloorID = id }); err != nil {
		return nil, err
	}
	slices.SortFunc(out.Floors, func(a, b venue.Floor) int { return a.Order - b.Order })
	return &out, nil
}

func (s *FirestoreStore) GetDraft(ctx context.Context, id string) (*venue.Map, error) {
	if _, err := s.GetEvent(ctx, id); err != nil {
		return nil, err
	}
	return s.readMap(ctx, nil, s.draft(id))
}

func (s *FirestoreStore) GetPublished(ctx context.Context, id string) (*venue.Map, int, error) {
	e, err := s.GetEvent(ctx, id)
	if err != nil {
		return nil, 0, err
	}
	if !e.Published() {
		return &venue.Map{}, 0, nil
	}
	// Read the map and its version marker together so they are consistent.
	var m *venue.Map
	var version int
	err = s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(s.published(id))
		if err != nil {
			return err
		}
		v, err := snap.DataAt("version")
		if err != nil {
			return err
		}
		version = int(v.(int64))
		m, err = s.readMap(ctx, tx, s.published(id))
		return err
	}, firestore.ReadOnly)
	if err != nil {
		return nil, 0, fmt.Errorf("read published map: %w", err)
	}
	return m, version, nil
}

func (s *FirestoreStore) touchDraft(ctx context.Context, id string) {
	// Best effort: lets an editor on another device listen for draft changes.
	_, _ = s.draft(id).Set(ctx, map[string]any{"updatedAt": time.Now().UTC()})
}

func (s *FirestoreStore) PutFloor(ctx context.Context, id string, f *venue.Floor) error {
	if _, err := s.draft(id).Collection(colFloors).Doc(f.ID).Set(ctx, f); err != nil {
		return fmt.Errorf("put floor: %w", err)
	}
	s.touchDraft(ctx, id)
	return nil
}

func (s *FirestoreStore) DeleteFloor(ctx context.Context, id, floorID string) error {
	d := s.draft(id)
	return s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		floorRef := d.Collection(colFloors).Doc(floorID)
		if _, err := tx.Get(floorRef); err != nil {
			if isNotFound(err) {
				return ErrNotFound
			}
			return fmt.Errorf("get floor: %w", err)
		}
		features, err := tx.Documents(d.Collection(colFeatures).Where("floorId", "==", floorID)).GetAll()
		if err != nil {
			return fmt.Errorf("list floor features: %w", err)
		}
		for _, f := range features {
			if err := tx.Delete(f.Ref); err != nil {
				return err
			}
		}
		if err := tx.Delete(d.Collection(colGraphs).Doc(floorID)); err != nil {
			return err
		}
		return tx.Delete(floorRef)
	})
}

func (s *FirestoreStore) PutFeature(ctx context.Context, id string, f *venue.Feature) error {
	if _, err := s.draft(id).Collection(colFeatures).Doc(f.ID).Set(ctx, f); err != nil {
		return fmt.Errorf("put feature: %w", err)
	}
	s.touchDraft(ctx, id)
	return nil
}

func (s *FirestoreStore) DeleteFeature(ctx context.Context, id, featureID string) error {
	ref := s.draft(id).Collection(colFeatures).Doc(featureID)
	if _, err := ref.Delete(ctx, firestore.Exists); err != nil {
		if isNotFound(err) {
			return ErrNotFound
		}
		return fmt.Errorf("delete feature: %w", err)
	}
	s.touchDraft(ctx, id)
	return nil
}

func (s *FirestoreStore) PutGraph(ctx context.Context, id string, g *venue.Graph) error {
	if _, err := s.draft(id).Collection(colGraphs).Doc(g.FloorID).Set(ctx, g); err != nil {
		return fmt.Errorf("put graph: %w", err)
	}
	s.touchDraft(ctx, id)
	return nil
}

func (s *FirestoreStore) Publish(ctx context.Context, id string, check func(*venue.Map) error) (int, error) {
	var version int
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		// All reads first (Firestore transactions require reads before writes).
		evSnap, err := tx.Get(s.event(id))
		if err != nil {
			if isNotFound(err) {
				return ErrNotFound
			}
			return err
		}
		var e venue.Event
		if err := evSnap.DataTo(&e); err != nil {
			return fmt.Errorf("decode event: %w", err)
		}
		draft, err := s.readMap(ctx, tx, s.draft(id))
		if err != nil {
			return err
		}
		pub := s.published(id)
		var oldRefs []*firestore.DocumentRef
		for _, col := range []string{colFloors, colFeatures, colGraphs} {
			snaps, err := tx.Documents(pub.Collection(col).Query).GetAll()
			if err != nil {
				return fmt.Errorf("read published %s: %w", col, err)
			}
			for _, sn := range snaps {
				oldRefs = append(oldRefs, sn.Ref)
			}
		}
		if err := check(draft); err != nil {
			return err
		}

		// Writes: replace the published map with the draft.
		keep := map[string]bool{}
		for i := range draft.Floors {
			ref := pub.Collection(colFloors).Doc(draft.Floors[i].ID)
			keep[ref.Path] = true
			if err := tx.Set(ref, &draft.Floors[i]); err != nil {
				return err
			}
		}
		for i := range draft.Features {
			ref := pub.Collection(colFeatures).Doc(draft.Features[i].ID)
			keep[ref.Path] = true
			if err := tx.Set(ref, &draft.Features[i]); err != nil {
				return err
			}
		}
		for i := range draft.Graphs {
			if draft.Floor(draft.Graphs[i].FloorID) == nil {
				continue
			}
			ref := pub.Collection(colGraphs).Doc(draft.Graphs[i].FloorID)
			keep[ref.Path] = true
			if err := tx.Set(ref, &draft.Graphs[i]); err != nil {
				return err
			}
		}
		for _, ref := range oldRefs {
			if !keep[ref.Path] {
				if err := tx.Delete(ref); err != nil {
					return err
				}
			}
		}
		now := time.Now().UTC()
		version = e.PublishedVersion + 1
		if err := tx.Set(pub, map[string]any{"version": version, "publishedAt": now}); err != nil {
			return err
		}
		return tx.Update(s.event(id), []firestore.Update{
			{Path: "publishedVersion", Value: version},
			{Path: "publishedAt", Value: now},
			{Path: "updatedAt", Value: now},
		})
	})
	if err != nil {
		var ve venue.ValidationError
		if errors.Is(err, ErrNotFound) || errors.As(err, &ve) {
			return 0, err
		}
		return 0, fmt.Errorf("publish: %w", err)
	}
	return version, nil
}

func (s *FirestoreStore) AddStats(ctx context.Context, id string, d *stats.Day) error {
	ref := s.event(id).Collection(colStats).Doc(d.Date)
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		// Read, add and write the whole day: the map keys are search terms,
		// which field-path increments can't always address.
		day := stats.NewDay(d.Date)
		snap, err := tx.Get(ref)
		switch {
		case err == nil:
			if err := snap.DataTo(day); err != nil {
				return fmt.Errorf("decode stats: %w", err)
			}
		case !isNotFound(err):
			return err
		}
		day.Merge(d)
		return tx.Set(ref, day)
	})
	if err != nil {
		return fmt.Errorf("add stats: %w", err)
	}
	return nil
}

func (s *FirestoreStore) ListStats(ctx context.Context, id, from, to string) ([]stats.Day, error) {
	if _, err := s.GetEvent(ctx, id); err != nil {
		return nil, err
	}
	// A range on one field needs no composite index.
	snaps, err := s.event(id).Collection(colStats).
		Where("date", ">=", from).Where("date", "<=", to).OrderBy("date", firestore.Asc).
		Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("list stats: %w", err)
	}
	return decodeAll(snaps, func(*stats.Day, string) {})
}
