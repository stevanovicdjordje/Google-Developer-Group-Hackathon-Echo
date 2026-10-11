package auth

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// MemIdentity is an in-memory Identity for tests.
type MemIdentity struct {
	mu       sync.Mutex
	byEmail  map[string]memUser
	sessions map[string]Claims
}

type memUser struct {
	Claims
	password string
}

func NewMemIdentity() *MemIdentity {
	return &MemIdentity{byEmail: map[string]memUser{}, sessions: map[string]Claims{}}
}

func (m *MemIdentity) SignUp(_ context.Context, email, password, name string, role users.Role) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.byEmail[email]; ok {
		return "", users.ErrEmailTaken
	}
	uid := id.New()
	m.byEmail[email] = memUser{Claims: Claims{UID: uid, Email: email, Name: name, Role: role}, password: password}
	return uid, nil
}

func (m *MemIdentity) SignIn(_ context.Context, email, password string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	u, ok := m.byEmail[email]
	if !ok || u.password != password {
		return "", ErrInvalidCredentials
	}
	return "idtoken:" + email, nil
}

func (m *MemIdentity) NewSession(_ context.Context, idToken string, _ time.Duration) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	u, ok := m.byEmail[strings.TrimPrefix(idToken, "idtoken:")]
	if !ok {
		return "", ErrInvalidSession
	}
	tok := id.Token(32)
	m.sessions[tok] = u.Claims
	return tok, nil
}

func (m *MemIdentity) VerifySession(_ context.Context, cookie string) (Claims, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	c, ok := m.sessions[cookie]
	if !ok {
		return Claims{}, ErrInvalidSession
	}
	return c, nil
}
