package store

import (
	"context"
	"encoding/json"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/Ilij4n/eho/backend/maps/internal/stats"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// MemStore is an in-memory Store. Values are deep-copied on the way in and out.
type MemStore struct {
	mu        sync.Mutex
	events    map[string]venue.Event
	draft     map[string]*venue.Map
	published map[string]*venue.Map
	stats     map[string]map[string]*stats.Day // eventID → date → day
}

// NewMemStore returns an empty MemStore.
func NewMemStore() *MemStore {
	return &MemStore{
		events: map[string]venue.Event{}, draft: map[string]*venue.Map{}, published: map[string]*venue.Map{},
		stats: map[string]map[string]*stats.Day{},
	}
}

var _ Store = (*MemStore)(nil)

func clone[T any](v T) T {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	var out T
	if err := json.Unmarshal(b, &out); err != nil {
		panic(err)
	}
	return out
}

func (s *MemStore) CreateEvent(_ context.Context, e *venue.Event) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events[e.ID] = clone(*e)
	s.draft[e.ID] = &venue.Map{}
	return nil
}

func (s *MemStore) GetEvent(_ context.Context, id string) (*venue.Event, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.events[id]
	if !ok {
		return nil, ErrNotFound
	}
	c := clone(e)
	return &c, nil
}

func (s *MemStore) ListEventsByOwner(_ context.Context, owner string) ([]venue.Event, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []venue.Event{}
	for _, e := range s.events {
		if e.OwnerUID == owner {
			out = append(out, clone(e))
		}
	}
	slices.SortFunc(out, func(a, b venue.Event) int { return b.CreatedAt.Compare(a.CreatedAt) })
	return out, nil
}

func (s *MemStore) UpdateEvent(_ context.Context, e *venue.Event) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.events[e.ID]; !ok {
		return ErrNotFound
	}
	s.events[e.ID] = clone(*e)
	return nil
}

func (s *MemStore) DeleteEvent(_ context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.events[id]; !ok {
		return ErrNotFound
	}
	delete(s.events, id)
	delete(s.draft, id)
	delete(s.published, id)
	delete(s.stats, id)
	return nil
}

func (s *MemStore) draftOf(id string) (*venue.Map, error) {
	m, ok := s.draft[id]
	if !ok {
		return nil, ErrNotFound
	}
	return m, nil
}

func (s *MemStore) GetDraft(_ context.Context, id string) (*venue.Map, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return nil, err
	}
	c := clone(*m)
	return &c, nil
}

func (s *MemStore) GetPublished(_ context.Context, id string) (*venue.Map, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.events[id]
	if !ok {
		return nil, 0, ErrNotFound
	}
	m, ok := s.published[id]
	if !ok {
		return &venue.Map{}, 0, nil
	}
	c := clone(*m)
	return &c, e.PublishedVersion, nil
}

func (s *MemStore) PutFloor(_ context.Context, id string, f *venue.Floor) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return err
	}
	if i := slices.IndexFunc(m.Floors, func(x venue.Floor) bool { return x.ID == f.ID }); i >= 0 {
		m.Floors[i] = clone(*f)
	} else {
		m.Floors = append(m.Floors, clone(*f))
	}
	return nil
}

func (s *MemStore) DeleteFloor(_ context.Context, id, floorID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return err
	}
	n := len(m.Floors)
	m.Floors = slices.DeleteFunc(m.Floors, func(f venue.Floor) bool { return f.ID == floorID })
	if len(m.Floors) == n {
		return ErrNotFound
	}
	m.Features = slices.DeleteFunc(m.Features, func(f venue.Feature) bool { return f.FloorID == floorID })
	m.Graphs = slices.DeleteFunc(m.Graphs, func(g venue.Graph) bool { return g.FloorID == floorID })
	return nil
}

func (s *MemStore) PutFeature(_ context.Context, id string, f *venue.Feature) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return err
	}
	if i := slices.IndexFunc(m.Features, func(x venue.Feature) bool { return x.ID == f.ID }); i >= 0 {
		m.Features[i] = clone(*f)
	} else {
		m.Features = append(m.Features, clone(*f))
	}
	return nil
}

func (s *MemStore) DeleteFeature(_ context.Context, id, featureID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return err
	}
	n := len(m.Features)
	m.Features = slices.DeleteFunc(m.Features, func(f venue.Feature) bool { return f.ID == featureID })
	if len(m.Features) == n {
		return ErrNotFound
	}
	return nil
}

func (s *MemStore) PutGraph(_ context.Context, id string, g *venue.Graph) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, err := s.draftOf(id)
	if err != nil {
		return err
	}
	if i := slices.IndexFunc(m.Graphs, func(x venue.Graph) bool { return x.FloorID == g.FloorID }); i >= 0 {
		m.Graphs[i] = clone(*g)
	} else {
		m.Graphs = append(m.Graphs, clone(*g))
	}
	return nil
}

func (s *MemStore) Publish(_ context.Context, id string, check func(*venue.Map) error) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.events[id]
	if !ok {
		return 0, ErrNotFound
	}
	d := clone(*s.draft[id])
	if err := check(&d); err != nil {
		return 0, err
	}
	s.published[id] = &d
	now := time.Now().UTC()
	e.PublishedVersion++
	e.PublishedAt = &now
	e.UpdatedAt = now
	s.events[id] = e
	return e.PublishedVersion, nil
}

func (s *MemStore) AddStats(_ context.Context, id string, d *stats.Day) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.events[id]; !ok {
		return ErrNotFound
	}
	days := s.stats[id]
	if days == nil {
		days = map[string]*stats.Day{}
		s.stats[id] = days
	}
	cur := days[d.Date]
	if cur == nil {
		cur = stats.NewDay(d.Date)
		days[d.Date] = cur
	}
	cur.Merge(d)
	return nil
}

func (s *MemStore) ListStats(_ context.Context, id, from, to string) ([]stats.Day, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.events[id]; !ok {
		return nil, ErrNotFound
	}
	out := []stats.Day{}
	for date, d := range s.stats[id] {
		if date >= from && date <= to {
			out = append(out, clone(*d))
		}
	}
	slices.SortFunc(out, func(a, b stats.Day) int { return strings.Compare(a.Date, b.Date) })
	return out, nil
}
