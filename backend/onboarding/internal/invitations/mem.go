package invitations

import (
	"context"
	"sync"
	"time"
)

// MemRepo is an in-memory Repository for tests.
type MemRepo struct {
	mu      sync.Mutex
	byID    map[string]Invitation
	members map[string]bool // uid/eventId
}

func NewMemRepo() *MemRepo {
	return &MemRepo{byID: map[string]Invitation{}, members: map[string]bool{}}
}

func (m *MemRepo) Create(_ context.Context, inv Invitation) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	id := DocID(inv.EventID, inv.Email)
	if _, ok := m.byID[id]; ok {
		return ErrDuplicate
	}
	inv.ID = id
	m.byID[id] = inv
	return nil
}

func (m *MemRepo) filter(keep func(Invitation) bool) []Invitation {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Invitation
	for _, inv := range m.byID {
		if keep(inv) {
			out = append(out, inv)
		}
	}
	return out
}

func (m *MemRepo) ListByEvent(_ context.Context, eventID string) ([]Invitation, error) {
	return m.filter(func(i Invitation) bool { return i.EventID == eventID }), nil
}

func (m *MemRepo) GetByToken(_ context.Context, token string) (Invitation, error) {
	list := m.filter(func(i Invitation) bool { return i.Token == token })
	if len(list) == 0 {
		return Invitation{}, ErrNotFound
	}
	return list[0], nil
}

func (m *MemRepo) Respond(_ context.Context, inv Invitation, userID string, st Status, at time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cur, ok := m.byID[inv.ID]
	if !ok {
		return ErrNotFound
	}
	cur.Status, cur.RespondedAt = st, &at
	if userID != "" {
		cur.UserID = userID
	}
	m.byID[inv.ID] = cur
	if cur.UserID != "" {
		m.members[cur.UserID+"/"+cur.EventID] = st == StatusAccepted
	}
	return nil
}

// IsMember reports whether the event is in the user's "My events" (tests).
func (m *MemRepo) IsMember(uid, eventID string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.members[uid+"/"+eventID]
}

func (m *MemRepo) HasAccepted(_ context.Context, eventID, userID string) (bool, error) {
	return len(m.filter(func(i Invitation) bool {
		return i.EventID == eventID && i.UserID == userID && i.Status == StatusAccepted
	})) > 0, nil
}

func (m *MemRepo) ListForParticipant(_ context.Context, userID, email string) ([]Invitation, error) {
	return m.filter(func(i Invitation) bool {
		return i.UserID == userID || (i.UserID == "" && i.Email == email)
	}), nil
}
