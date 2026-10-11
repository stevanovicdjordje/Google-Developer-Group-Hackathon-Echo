// Package invitations holds event invitations, the public accept/decline
// flow and the participant's event panel.
package invitations

import (
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/auth"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
)

type Status string

const (
	StatusSent     Status = "sent"
	StatusAccepted Status = "accepted"
	StatusDeclined Status = "declined"
	// StatusExpired is derived: a sent invitation past its TTL or whose event ended.
	StatusExpired Status = "expired"
)

var Statuses = []Status{StatusSent, StatusAccepted, StatusDeclined, StatusExpired}

func ParseStatus(s string) (Status, bool) {
	for _, x := range Statuses {
		if string(x) == s {
			return x, true
		}
	}
	return "", false
}

// TTL is how long an unanswered invitation stays valid.
const TTL = 30 * 24 * time.Hour

var (
	ErrNotFound  = errors.New("invitations: not found")
	ErrDuplicate = errors.New("invitations: already invited")
	ErrNotOpen   = errors.New("invitations: event is not open for responses")
	ErrExpired   = errors.New("invitations: expired")
	ErrTaken     = errors.New("invitations: used by another account")
)

type Invitation struct {
	ID          string
	EventID     string
	Email       string
	Token       string
	Status      Status // stored status: sent / accepted / declined
	UserID      string
	ExpiresAt   time.Time
	CreatedAt   time.Time
	RespondedAt *time.Time
}

// Effective returns the status shown to people, deriving "expired".
func (i Invitation) Effective(ev events.Event, now time.Time) Status {
	if i.Status == StatusSent && (!now.Before(i.ExpiresAt) || ev.Status(now) == events.StatusFinished) {
		return StatusExpired
	}
	return i.Status
}

// CheckRespond decides whether userID may accept/decline now. A response can
// be changed until the event ends; once bound to an account, only that
// account may respond. userID may be "" for an anonymous decline.
func CheckRespond(inv Invitation, ev events.Event, userID string, now time.Time) error {
	switch ev.Status(now) {
	case events.StatusPublished, events.StatusOngoing:
	default:
		return ErrNotOpen
	}
	if inv.Effective(ev, now) == StatusExpired {
		return ErrExpired
	}
	if inv.UserID != "" && inv.UserID != userID {
		return ErrTaken
	}
	return nil
}

var emailSplit = regexp.MustCompile(`[\s,;]+`)

// MaxBatch caps how many addresses one paste may add.
const MaxBatch = 500

// ParseEmails splits a pasted list (newlines, commas, semicolons, spaces),
// normalizes and deduplicates it. Invalid entries are returned separately.
func ParseEmails(raw string) (valid, invalid []string) {
	seen := map[string]bool{}
	for _, part := range emailSplit.Split(raw, -1) {
		e := auth.NormalizeEmail(strings.Trim(part, "<>\"'"))
		if e == "" || seen[e] {
			continue
		}
		seen[e] = true
		if auth.ValidEmail(e) {
			valid = append(valid, e)
		} else {
			invalid = append(invalid, part)
		}
	}
	return valid, invalid
}

// Row is an invitation joined with its event, for the participant panel.
type Row struct {
	Invitation
	Event events.Event
}

type Repository interface {
	Create(inv Invitation) error
	ListByEvent(eventID string) ([]Invitation, error)
	GetByToken(token string) (Invitation, error)
	Respond(id, userID string, st Status, at time.Time) error
	HasAccepted(eventID, userID string) (bool, error)
	// ListForParticipant returns invitations bound to userID plus unbound
	// ones sent to email.
	ListForParticipant(userID, email string) ([]Invitation, error)
}
