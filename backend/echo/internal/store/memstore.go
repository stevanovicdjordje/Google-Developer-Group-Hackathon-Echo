package store

import (
	"context"
	"slices"
	"sync"
	"time"
)

// MemStore is an in-memory Store and Replayer for tests.
type MemStore struct {
	mu        sync.Mutex
	events    map[string]Event
	sessions  map[string]*Transcript
	questions map[string][]Question
	cache     map[string]Cached
	trans     map[string]map[int]string
}

// NewMemStore returns an empty MemStore.
func NewMemStore() *MemStore {
	return &MemStore{
		events:    map[string]Event{},
		sessions:  map[string]*Transcript{},
		questions: map[string][]Question{},
		cache:     map[string]Cached{},
		trans:     map[string]map[int]string{},
	}
}

var (
	_ Store    = (*MemStore)(nil)
	_ Replayer = (*MemStore)(nil)
)

func sk(eventID, sessionID string) string { return eventID + "/" + sessionID }

// PutEvent seeds an event.
func (m *MemStore) PutEvent(id string, e Event) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.events[id] = e
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

func (m *MemStore) GetTranscript(_ context.Context, eventID, sessionID string) (Transcript, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, ok := m.sessions[sk(eventID, sessionID)]
	if !ok {
		return Transcript{}, ErrNoTranscript
	}
	c := *t
	c.Lines = slices.Clone(t.Lines)
	return c, nil
}

func (m *MemStore) ResetTranscript(_ context.Context, eventID, sessionID string, meta SessionMeta) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions[sk(eventID, sessionID)] = &Transcript{Status: StatusLive, Language: meta.Language, Title: meta.Title, Speaker: meta.Speaker}
	return nil
}

func (m *MemStore) AppendLine(_ context.Context, eventID, sessionID string, l Line, last bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, ok := m.sessions[sk(eventID, sessionID)]
	if !ok {
		return ErrNoTranscript
	}
	t.Lines = append(t.Lines, l)
	if last {
		t.Status = StatusEnded
	}
	return nil
}

func (m *MemStore) ListQuestions(_ context.Context, eventID, sessionID string) ([]Question, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]Question, 0, len(m.questions[sk(eventID, sessionID)]))
	for _, q := range m.questions[sk(eventID, sessionID)] {
		q.VoterUIDs = slices.Clone(q.VoterUIDs)
		out = append(out, q)
	}
	return out, nil
}

func (m *MemStore) CreateQuestion(_ context.Context, eventID, sessionID string, q *Question) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if q.ID == "" {
		q.ID = NewID("q_")
	}
	if q.CreatedAt.IsZero() {
		q.CreatedAt = time.Now().UTC()
	}
	c := *q
	c.VoterUIDs = slices.Clone(q.VoterUIDs)
	m.questions[sk(eventID, sessionID)] = append(m.questions[sk(eventID, sessionID)], c)
	return nil
}

func (m *MemStore) SetVote(_ context.Context, eventID, sessionID, questionID, uid string, on bool) (Question, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	qs := m.questions[sk(eventID, sessionID)]
	for i := range qs {
		if qs[i].ID != questionID {
			continue
		}
		qs[i].VoterUIDs = setVoter(qs[i].VoterUIDs, uid, on)
		q := qs[i]
		q.VoterUIDs = slices.Clone(q.VoterUIDs)
		return q, nil
	}
	return Question{}, ErrNotFound
}

func setVoter(voters []string, uid string, on bool) []string {
	i := slices.Index(voters, uid)
	switch {
	case on && i < 0:
		return append(voters, uid)
	case !on && i >= 0:
		return slices.Delete(voters, i, i+1)
	}
	return voters
}

func (m *MemStore) GetCached(_ context.Context, eventID, sessionID, key string) (Cached, bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	c, ok := m.cache[sk(eventID, sessionID)+"/"+key]
	return c, ok, nil
}

func (m *MemStore) PutCached(_ context.Context, eventID, sessionID, key string, v Cached) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cache[sk(eventID, sessionID)+"/"+key] = v
	return nil
}

func (m *MemStore) GetTranslations(_ context.Context, eventID, sessionID, language string) (map[int]string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := map[int]string{}
	for k, v := range m.trans[sk(eventID, sessionID)+"/"+language] {
		out[k] = v
	}
	return out, nil
}

func (m *MemStore) PutTranslations(_ context.Context, eventID, sessionID, language string, lines map[int]string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	k := sk(eventID, sessionID) + "/" + language
	if m.trans[k] == nil {
		m.trans[k] = map[int]string{}
	}
	for i, t := range lines {
		m.trans[k][i] = t
	}
	return nil
}
