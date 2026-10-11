package store

import (
	"context"
	"slices"
	"strings"
	"sync"
	"time"
)

// MemStore is an in-memory Store for tests.
type MemStore struct {
	mu       sync.Mutex
	events   map[string]Event
	features map[string][]string             // eventID -> feature names
	profiles map[string]Profile              // uid -> profile
	presence map[string]map[string]time.Time // eventID -> uid -> joinedAt
	contacts map[string]map[string]Contact   // eventID -> pair ID -> contact
}

var _ Store = (*MemStore)(nil)

// NewMemStore returns an empty MemStore.
func NewMemStore() *MemStore {
	return &MemStore{
		events:   map[string]Event{},
		features: map[string][]string{},
		profiles: map[string]Profile{},
		presence: map[string]map[string]time.Time{},
		contacts: map[string]map[string]Contact{},
	}
}

// PutEvent creates or replaces an event.
func (m *MemStore) PutEvent(id string, e Event) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.events[id] = e
}

// PutFeatures sets the published map feature names of an event.
func (m *MemStore) PutFeatures(eventID string, names ...string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.features[eventID] = names
}

// SetDemo marks a profile as a seeded demo attendee.
func (m *MemStore) SetDemo(uid string, demo bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p := m.profiles[uid]
	p.Demo = demo
	m.profiles[uid] = p
}

func (m *MemStore) GetEvent(_ context.Context, id string) (Event, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.events[id]
	if !ok {
		return Event{}, ErrNotFound
	}
	return e, nil
}

func (m *MemStore) GetProfile(_ context.Context, uid string) (Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[uid]
	if !ok {
		return Profile{}, ErrNotFound
	}
	return clone(p), nil
}

func clone(p Profile) Profile {
	p.Interests = slices.Clone(p.Interests)
	p.Events = slices.Clone(p.Events)
	return p
}

func (m *MemStore) SaveProfile(_ context.Context, uid string, f ProfileFields, now time.Time) (Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p := m.profiles[uid]
	p.ProfileFields = f
	p.UID = uid
	p.UpdatedAt = now
	if p.PersonID == "" {
		p.PersonID = NewPersonID()
	}
	m.profiles[uid] = clone(p)
	return clone(p), nil
}

func (m *MemStore) DeleteProfile(_ context.Context, uid string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[uid]
	if !ok {
		return nil
	}
	for _, ev := range p.Events {
		delete(m.presence[ev], uid)
		for id, c := range m.contacts[ev] {
			if c.A == uid || c.B == uid {
				delete(m.contacts[ev], id)
			}
		}
	}
	delete(m.profiles, uid)
	return nil
}

func (m *MemStore) Join(_ context.Context, eventID, uid string, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[uid]
	if !ok {
		return ErrNoProfile
	}
	if m.presence[eventID] == nil {
		m.presence[eventID] = map[string]time.Time{}
	}
	if _, ok := m.presence[eventID][uid]; !ok {
		m.presence[eventID][uid] = now
	}
	if !slices.Contains(p.Events, eventID) {
		p.Events = append(slices.Clone(p.Events), eventID)
		m.profiles[uid] = p
	}
	return nil
}

func (m *MemStore) Leave(_ context.Context, eventID, uid string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.presence[eventID], uid)
	if p, ok := m.profiles[uid]; ok {
		p.Events = slices.DeleteFunc(slices.Clone(p.Events), func(e string) bool { return e == eventID })
		m.profiles[uid] = p
	}
	return nil
}

func (m *MemStore) IsPresent(_ context.Context, eventID, uid string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, ok := m.presence[eventID][uid]
	return ok, nil
}

func (m *MemStore) People(_ context.Context, eventID string) ([]Attendee, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Attendee
	for uid, at := range m.presence[eventID] {
		if p, ok := m.profiles[uid]; ok {
			out = append(out, Attendee{Profile: clone(p), JoinedAt: at})
		}
	}
	return out, nil
}

func (m *MemStore) PersonByID(_ context.Context, eventID, personID string) (Attendee, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for uid, at := range m.presence[eventID] {
		if p, ok := m.profiles[uid]; ok && p.PersonID == personID {
			return Attendee{Profile: clone(p), JoinedAt: at}, nil
		}
	}
	return Attendee{}, ErrNotFound
}

func (m *MemStore) GetContact(_ context.Context, eventID, x, y string) (Contact, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, _, id := Pair(x, y)
	c, ok := m.contacts[eventID][id]
	if !ok {
		return Contact{}, ErrNotFound
	}
	return cloneContact(c), nil
}

func cloneContact(c Contact) Contact {
	if c.MeetingSpot != nil {
		ms := *c.MeetingSpot
		c.MeetingSpot = &ms
	}
	return c
}

func (m *MemStore) UpdateContact(_ context.Context, eventID, x, y string, fn func(c *Contact) (*Contact, error)) (Contact, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	a, b, id := Pair(x, y)
	var cur *Contact
	if c, ok := m.contacts[eventID][id]; ok {
		cc := cloneContact(c)
		cur = &cc
	}
	next, err := fn(cur)
	if err != nil {
		return Contact{}, err
	}
	if next == nil {
		if cur == nil {
			return Contact{}, ErrNotFound
		}
		return *cur, nil
	}
	next.A, next.B = a, b
	if m.contacts[eventID] == nil {
		m.contacts[eventID] = map[string]Contact{}
	}
	m.contacts[eventID][id] = cloneContact(*next)
	return cloneContact(*next), nil
}

func (m *MemStore) Contacts(_ context.Context, eventID, uid string) ([]Contact, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Contact
	for _, c := range m.contacts[eventID] {
		if c.A == uid || c.B == uid {
			out = append(out, cloneContact(c))
		}
	}
	return out, nil
}

func (m *MemStore) FeatureName(_ context.Context, eventID, place string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, n := range m.features[eventID] {
		if strings.EqualFold(strings.TrimSpace(n), strings.TrimSpace(place)) {
			return n, nil
		}
	}
	return "", ErrNotFound
}
