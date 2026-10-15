package reviews

import (
	"context"
	"sync"
)

// MemRepo is an in-memory Repository for tests.
type MemRepo struct {
	mu   sync.Mutex
	byID map[string]WithAuthor // eventId/uid
}

func NewMemRepo() *MemRepo { return &MemRepo{byID: map[string]WithAuthor{}} }

func (m *MemRepo) Get(_ context.Context, eventID, userID string) (Review, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	w, ok := m.byID[eventID+"/"+userID]
	if !ok {
		return Review{}, ErrNotFound
	}
	return w.Review, nil
}

func (m *MemRepo) Save(_ context.Context, w WithAuthor) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := w.EventID + "/" + w.UserID
	if old, ok := m.byID[key]; ok {
		w.CreatedAt = old.CreatedAt
	}
	m.byID[key] = w
	return nil
}

func (m *MemRepo) ListByEvent(_ context.Context, eventID string) ([]WithAuthor, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []WithAuthor
	for _, w := range m.byID {
		if w.EventID == eventID {
			out = append(out, w)
		}
	}
	return out, nil
}
