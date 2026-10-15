package auth

import (
	"context"
	"errors"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

var (
	ErrInvalidCredentials = errors.New("auth: invalid credentials")
	ErrTooManyAttempts    = errors.New("auth: too many attempts")
	ErrInvalidSession     = errors.New("auth: invalid or expired session")
)

// SessionTTL is the Firebase session cookie lifetime (Firebase allows at most 14 days).
const SessionTTL = 14 * 24 * time.Hour

// Claims is what a verified session says about the user.
type Claims struct {
	UID       string
	Email     string
	Name      string
	Role      users.Role
	Anonymous bool
}

// Identity is the account provider: Firebase Auth in production and with the
// emulator, an in-memory fake in tests. The same accounts are used by the
// Flutter app and the other backend services.
type Identity interface {
	// SignUp creates an email/password account with the role as a custom claim.
	// It returns users.ErrEmailTaken when the email is registered.
	SignUp(ctx context.Context, email, password, name string, role users.Role) (uid string, err error)
	// SignIn checks the password and returns a Firebase ID token.
	SignIn(ctx context.Context, email, password string) (idToken string, err error)
	// NewSession exchanges an ID token for a session cookie value.
	NewSession(ctx context.Context, idToken string, ttl time.Duration) (string, error)
	VerifySession(ctx context.Context, cookie string) (Claims, error)
}

// ResolveRole reads the role custom claim. Accounts without it (created in
// the Flutter app) follow the team rule: anonymous = attendee, email/password
// = organizer.
func ResolveRole(claim any, anonymous bool) users.Role {
	if s, ok := claim.(string); ok && users.Role(s).Valid() {
		return users.Role(s)
	}
	if anonymous {
		return users.RoleParticipant
	}
	return users.RoleOrganizer
}
