package users

import (
	"context"
	"sync"
	"time"
)

// MemRepo is an in-memory Repository for tests.
type MemRepo struct {
	mu       sync.Mutex
	orgs     map[string]Organization
	profiles map[string]Profile
	consents map[string][]string
}

func NewMemRepo() *MemRepo {
	return &MemRepo{orgs: map[string]Organization{}, profiles: map[string]Profile{}, consents: map[string][]string{}}
}

func (m *MemRepo) SaveOrganization(_ context.Context, o Organization) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.orgs[o.OwnerUID] = o
	return nil
}

func (m *MemRepo) GetOrganization(_ context.Context, uid string) (Organization, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	o, ok := m.orgs[uid]
	if !ok {
		return Organization{}, ErrNotFound
	}
	return o, nil
}

func (m *MemRepo) CreateProfile(_ context.Context, uid string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.profiles[uid]; !ok {
		m.profiles[uid] = Profile{UserID: uid, OnboardingStep: 1}
	}
	return nil
}

func (m *MemRepo) GetProfile(_ context.Context, uid string) (Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[uid]
	if !ok {
		return Profile{}, ErrNotFound
	}
	return p, nil
}

func (m *MemRepo) SaveProfile(_ context.Context, p Profile) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.profiles[p.UserID]; !ok {
		return ErrNotFound
	}
	m.profiles[p.UserID] = p
	return nil
}

func (m *MemRepo) GrantConsent(_ context.Context, uid, kind, _ string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.profiles[uid]; !ok {
		return ErrNotFound
	}
	m.consents[uid] = append(m.consents[uid], kind)
	return nil
}
