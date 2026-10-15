package store

import (
	"context"
	"encoding/json"
	"slices"
	"sync"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

// MemStore is an in-memory Store for tests.
type MemStore struct {
	mu      sync.Mutex
	events  map[string]Event
	rooms   map[string][]string // published map rooms; key present = map published
	agendas map[string]agenda.Agenda
	members map[string]map[string]time.Time
	drafts  map[string]Draft
}

var _ Store = (*MemStore)(nil)

// NewMemStore returns an empty store.
func NewMemStore() *MemStore {
	return &MemStore{
		events: map[string]Event{}, rooms: map[string][]string{}, agendas: map[string]agenda.Agenda{},
		members: map[string]map[string]time.Time{}, drafts: map[string]Draft{},
	}
}

// PutEvent adds an event doc as the venue map would (tests).
func (s *MemStore) PutEvent(e Event, rooms ...string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events[e.ID] = e
	if e.PublishedVersion > 0 {
		s.rooms[e.ID] = rooms
	}
}

// deep copies through JSON so callers never share slices with the store.
func deep[T any](v T) T {
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

func (s *MemStore) GetEvent(_ context.Context, id string) (*Event, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.events[id]
	if !ok {
		return nil, ErrNotFound
	}
	return &e, nil
}

func (s *MemStore) RoomNames(_ context.Context, id string) ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.rooms[id]), nil
}

func (s *MemStore) HasMap(_ context.Context, id string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.rooms[id]
	return ok, nil
}

func (s *MemStore) GetAgenda(_ context.Context, id string) (*agenda.Agenda, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ok := s.agendas[id]
	if !ok {
		return nil, ErrNotFound
	}
	a = deep(a)
	a.EventID = id
	return &a, nil
}

func (s *MemStore) PublishAgenda(_ context.Context, p Publication) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, exists := s.events[p.Event.ID]
	switch {
	case p.Create && exists:
		return ErrConflict
	case !p.Create && !exists:
		return ErrNotFound
	case p.Create:
		e = p.Event
	default:
		e.Name, e.StartDate, e.EndDate, e.Address = p.Event.Name, p.Event.StartDate, p.Event.EndDate, p.Event.Address
	}
	if p.DraftID != "" {
		d, ok := s.drafts[p.DraftID]
		if !ok {
			return ErrNotFound
		}
		d.PublishedEventID = p.Event.ID
		s.drafts[p.DraftID] = d
	}
	s.events[e.ID] = e
	s.agendas[e.ID] = deep(p.Agenda)
	return nil
}

func (s *MemStore) Join(_ context.Context, uid, eventID string, at time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.members[uid] == nil {
		s.members[uid] = map[string]time.Time{}
	}
	if _, ok := s.members[uid][eventID]; !ok {
		s.members[uid][eventID] = at
	}
	return nil
}

func (s *MemStore) Leave(_ context.Context, uid, eventID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.members[uid], eventID)
	return nil
}

func (s *MemStore) ListMemberships(_ context.Context, uid string) ([]Membership, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []Membership{}
	for id, at := range s.members[uid] {
		out = append(out, Membership{EventID: id, JoinedAt: at})
	}
	sortMemberships(out)
	return out, nil
}

func sortMemberships(m []Membership) {
	slices.SortFunc(m, func(a, b Membership) int { return b.JoinedAt.Compare(a.JoinedAt) })
}

func (s *MemStore) CreateDraft(_ context.Context, d *Draft) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.drafts[d.ID]; ok {
		return ErrConflict
	}
	s.drafts[d.ID] = deep(*d)
	return nil
}

func (s *MemStore) GetDraft(_ context.Context, id string) (*Draft, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d, ok := s.drafts[id]
	if !ok {
		return nil, ErrNotFound
	}
	d = deep(d)
	return &d, nil
}

func (s *MemStore) UpdateDraft(_ context.Context, d *Draft) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.drafts[d.ID]; !ok {
		return ErrNotFound
	}
	s.drafts[d.ID] = deep(*d)
	return nil
}
