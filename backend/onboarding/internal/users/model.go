// Package users holds the user, organization and participant-profile domain.
package users

import (
	"errors"
	"time"
)

type Role string

const (
	RoleOrganizer   Role = "organizer"
	RoleParticipant Role = "participant"
	// RoleAdmin is reserved for a future platform super-admin. Nothing grants it yet.
	RoleAdmin Role = "admin"
)

func (r Role) Valid() bool {
	return r == RoleOrganizer || r == RoleParticipant || r == RoleAdmin
}

type Goal string

const (
	GoalLearn      Goal = "learn"
	GoalJob        Goal = "job"
	GoalHiring     Goal = "hiring"
	GoalPartners   Goal = "partners"
	GoalNetworking Goal = "networking"
)

var Goals = []Goal{GoalLearn, GoalJob, GoalHiring, GoalPartners, GoalNetworking}

func (g Goal) Valid() bool {
	for _, x := range Goals {
		if x == g {
			return true
		}
	}
	return false
}

var (
	ErrNotFound   = errors.New("users: not found")
	ErrEmailTaken = errors.New("users: email already registered")
)

type User struct {
	ID           string
	Email        string
	FullName     string
	Role         Role
	PasswordHash string
	CreatedAt    time.Time
}

type Organization struct {
	ID        string
	OwnerID   string
	Name      string
	Website   string
	CreatedAt time.Time
}

// Profile is the participant's onboarding data. Interests, goal and visibility
// are stored in a structured way so they can later feed AI matching.
type Profile struct {
	UserID          string
	CaptionLanguage string
	Interests       []string
	CustomInterests []string // subset of Interests that came from free text
	Goal            Goal
	Visible         bool // networking opt-in, default false
	OnboardingStep  int  // 1..5 = next step to complete; 6 = finished
	CompletedAt     *time.Time
}

const (
	OnboardingSteps = 5
	// GDPRConsentVersion identifies the wording the user agreed to.
	GDPRConsentVersion = "2026-10-draft"
	ConsentGDPR        = "gdpr"
)

func (p Profile) Completed() bool { return p.CompletedAt != nil }

// Repository is the persistence boundary; SQLite is the first implementation.
type Repository interface {
	CreateOrganizer(u User, org Organization) error
	CreateParticipant(u User) error
	GetByID(id string) (User, error)
	GetByEmail(email string) (User, error)
	GetOrganizationByOwner(ownerID string) (Organization, error)

	GetProfile(userID string) (Profile, error)
	SaveProfile(p Profile) error
	GrantConsent(userID, kind, version string) error
	HasConsent(userID, kind string) (bool, error)
}
