package auth

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

type OrganizerInput struct {
	FullName, Email, Password, PasswordConfirm, OrgName, Website string
}

type ParticipantInput struct {
	FullName, Email, Password, PasswordConfirm string
}

type Service struct {
	id    Identity
	users users.Repository
	now   func() time.Time
}

func NewService(identity Identity, repo users.Repository) *Service {
	return &Service{id: identity, users: repo, now: time.Now}
}

func (s *Service) RegisterOrganizer(ctx context.Context, in OrganizerInput) (users.User, error) {
	f := FieldErrors{}
	in.FullName = strings.TrimSpace(in.FullName)
	in.OrgName = strings.TrimSpace(in.OrgName)
	in.Email = NormalizeEmail(in.Email)
	checkName(f, "full_name", in.FullName, 2, 100, "err.name_len")
	checkName(f, "org_name", in.OrgName, 2, 120, "err.org_name_len")
	if !ValidEmail(in.Email) {
		f.Add("email", "err.email")
	}
	checkPassword(f, in.Password, in.PasswordConfirm)
	site, ok := normalizeWebsite(in.Website)
	if !ok {
		f.Add("website", "err.website")
	}
	if !f.Empty() {
		return users.User{}, f
	}
	uid, err := s.id.SignUp(ctx, in.Email, in.Password, in.FullName, users.RoleOrganizer)
	if errors.Is(err, users.ErrEmailTaken) {
		return users.User{}, FieldErrors{"email": "err.email_taken"}
	}
	if err != nil {
		return users.User{}, err
	}
	org := users.Organization{OwnerUID: uid, Name: in.OrgName, Website: site, CreatedAt: s.now().UTC()}
	if err := s.users.SaveOrganization(ctx, org); err != nil {
		// The account exists; the organization can be re-entered later.
		log.Printf("auth: save organization for %s: %v", uid, err)
	}
	return users.User{ID: uid, Email: in.Email, FullName: in.FullName, Role: users.RoleOrganizer}, nil
}

func (s *Service) RegisterParticipant(ctx context.Context, in ParticipantInput) (users.User, error) {
	f := FieldErrors{}
	in.FullName = strings.TrimSpace(in.FullName)
	in.Email = NormalizeEmail(in.Email)
	checkName(f, "full_name", in.FullName, 2, 100, "err.name_len")
	if !ValidEmail(in.Email) {
		f.Add("email", "err.email")
	}
	checkPassword(f, in.Password, in.PasswordConfirm)
	if !f.Empty() {
		return users.User{}, f
	}
	uid, err := s.id.SignUp(ctx, in.Email, in.Password, in.FullName, users.RoleParticipant)
	if errors.Is(err, users.ErrEmailTaken) {
		return users.User{}, FieldErrors{"email": "err.email_taken"}
	}
	if err != nil {
		return users.User{}, err
	}
	if err := s.users.CreateProfile(ctx, uid, s.now().UTC()); err != nil {
		return users.User{}, err
	}
	return users.User{ID: uid, Email: in.Email, FullName: in.FullName, Role: users.RoleParticipant}, nil
}

// StartSession checks the password and returns a session cookie value.
func (s *Service) StartSession(ctx context.Context, email, password string) (string, time.Time, error) {
	idToken, err := s.id.SignIn(ctx, NormalizeEmail(email), password)
	if err != nil {
		return "", time.Time{}, err
	}
	cookie, err := s.id.NewSession(ctx, idToken, SessionTTL)
	if err != nil {
		return "", time.Time{}, err
	}
	return cookie, s.now().Add(SessionTTL), nil
}

func (s *Service) Verify(ctx context.Context, cookie string) (Claims, error) {
	return s.id.VerifySession(ctx, cookie)
}
