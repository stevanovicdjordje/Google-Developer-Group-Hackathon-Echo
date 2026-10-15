package events

import (
	"bytes"
	"context"
	"io"
	"sync"
)

// MemRepo is an in-memory Repository (and Images) for tests.
type MemRepo struct {
	mu      sync.Mutex
	events  map[string]Event
	agendas map[string]Agenda
	maps    map[string]Map
	images  map[string][]byte
}

func NewMemRepo() *MemRepo {
	return &MemRepo{events: map[string]Event{}, agendas: map[string]Agenda{}, maps: map[string]Map{}, images: map[string][]byte{}}
}

func (m *MemRepo) Create(_ context.Context, e Event) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.events[e.ID] = e
	return nil
}

func (m *MemRepo) Update(_ context.Context, e Event) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	old, ok := m.events[e.ID]
	if !ok {
		return ErrNotFound
	}
	e.MapVersion, e.OwnerUID, e.CreatedAt = old.MapVersion, old.OwnerUID, old.CreatedAt
	m.events[e.ID] = e
	return nil
}

func (m *MemRepo) Get(_ context.Context, id string) (Event, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.events[id]
	if !ok {
		return Event{}, ErrNotFound
	}
	return e, nil
}

func (m *MemRepo) ListByOwner(_ context.Context, uid string) ([]Event, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Event
	for _, e := range m.events {
		if e.OwnerUID == uid {
			out = append(out, e)
		}
	}
	return out, nil
}

func (m *MemRepo) ListPublished(_ context.Context) ([]Event, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Event
	for _, e := range m.events {
		if e.Published() {
			out = append(out, e)
		}
	}
	return out, nil
}

// ListAll returns every event (tests).
func (m *MemRepo) ListAll() []Event {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Event
	for _, e := range m.events {
		out = append(out, e)
	}
	return out
}

func (m *MemRepo) GetAgenda(_ context.Context, id string) (Agenda, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.agendas[id], nil
}

func (m *MemRepo) SaveAgenda(_ context.Context, id string, a Agenda) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	a.Normalize()
	m.agendas[id] = a
	return nil
}

func (m *MemRepo) GetPublishedMap(_ context.Context, id string) (Map, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.maps[id], nil
}

// PublishMap simulates backend/maps publishing a venue map with a floor image.
func (m *MemRepo) PublishMap(eventID string, mp Map, images map[string][]byte) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.maps[eventID] = mp
	for k, v := range images {
		m.images[k] = v
	}
	if e, ok := m.events[eventID]; ok {
		e.MapVersion++
		m.events[eventID] = e
	}
}

func (m *MemRepo) FloorImage(_ context.Context, path string) (io.ReadCloser, string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	b, ok := m.images[path]
	if !ok {
		return nil, "", ErrNotFound
	}
	return io.NopCloser(bytes.NewReader(b)), "image/png", nil
}
