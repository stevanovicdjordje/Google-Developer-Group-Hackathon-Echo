package auth

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

var ErrInvalidCredentials = errors.New("auth: invalid credentials")

const SessionTTL = 14 * 24 * time.Hour

type OrganizerInput struct {
	FullName, Email, Password, PasswordConfirm, OrgName, Website string
}

type ParticipantInput struct {
	FullName, Email, Password, PasswordConfirm string
}

type Service struct {
	users users.Repository
	db    *sql.DB
	now   func() time.Time
}

func NewService(repo users.Repository, db *sql.DB) *Service {
	return &Service{users: repo, db: db, now: time.Now}
}

func (s *Service) RegisterOrganizer(in OrganizerInput) (users.User, error) {
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
	hash, err := HashPassword(in.Password)
	if err != nil {
		return users.User{}, err
	}
	now := s.now().UTC()
	u := users.User{ID: id.New(), Email: in.Email, FullName: in.FullName,
		Role: users.RoleOrganizer, PasswordHash: hash, CreatedAt: now}
	org := users.Organization{ID: id.New(), OwnerID: u.ID, Name: in.OrgName, Website: site, CreatedAt: now}
	if err := s.users.CreateOrganizer(u, org); err != nil {
		if errors.Is(err, users.ErrEmailTaken) {
			return users.User{}, FieldErrors{"email": "err.email_taken"}
		}
		return users.User{}, err
	}
	return u, nil
}

func (s *Service) RegisterParticipant(in ParticipantInput) (users.User, error) {
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
	hash, err := HashPassword(in.Password)
	if err != nil {
		return users.User{}, err
	}
	u := users.User{ID: id.New(), Email: in.Email, FullName: in.FullName,
		Role: users.RoleParticipant, PasswordHash: hash, CreatedAt: s.now().UTC()}
	if err := s.users.CreateParticipant(u); err != nil {
		if errors.Is(err, users.ErrEmailTaken) {
			return users.User{}, FieldErrors{"email": "err.email_taken"}
		}
		return users.User{}, err
	}
	return u, nil
}

// Login checks credentials. It returns ErrInvalidCredentials for both an
// unknown email and a wrong password.
func (s *Service) Login(email, password string) (users.User, error) {
	u, err := s.users.GetByEmail(NormalizeEmail(email))
	if errors.Is(err, users.ErrNotFound) {
		CheckPassword(dummyHash, password)
		return users.User{}, ErrInvalidCredentials
	}
	if err != nil {
		return users.User{}, err
	}
	if !CheckPassword(u.PasswordHash, password) {
		return users.User{}, ErrInvalidCredentials
	}
	return u, nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// CreateSession stores a new session and returns the opaque cookie token.
func (s *Service) CreateSession(ctx context.Context, userID string) (string, time.Time, error) {
	token := id.Token(32)
	now := s.now().UTC()
	exp := now.Add(SessionTTL)
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO auth_sessions (token_hash, user_id, created_at, expires_at) VALUES (?,?,?,?)`,
		hashToken(token), userID, now.Unix(), exp.Unix())
	return token, exp, err
}

// UserForSession resolves a cookie token to its user; expired sessions are removed.
func (s *Service) UserForSession(ctx context.Context, token string) (users.User, error) {
	var userID string
	var exp int64
	err := s.db.QueryRowContext(ctx,
		`SELECT user_id, expires_at FROM auth_sessions WHERE token_hash = ?`, hashToken(token)).Scan(&userID, &exp)
	if errors.Is(err, sql.ErrNoRows) {
		return users.User{}, users.ErrNotFound
	}
	if err != nil {
		return users.User{}, err
	}
	if s.now().Unix() >= exp {
		_ = s.DestroySession(ctx, token)
		return users.User{}, users.ErrNotFound
	}
	return s.users.GetByID(userID)
}

func (s *Service) DestroySession(ctx context.Context, token string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM auth_sessions WHERE token_hash = ?`, hashToken(token))
	return err
}
