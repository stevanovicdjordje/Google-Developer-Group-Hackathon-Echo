// Package reviews holds participant reviews of finished events and sessions.
package reviews

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
)

var (
	ErrNotFound    = errors.New("reviews: not found")
	ErrNotAllowed  = errors.New("reviews: only participants who accepted the invitation may review")
	ErrNotFinished = errors.New("reviews: event has not finished yet")
)

const MaxComment = 2000

type Review struct {
	ID        string
	EventID   string
	UserID    string
	Rating    int
	Comment   string
	Anonymous bool // hide the author from the organizer
	// SessionRatings maps session ID to an optional 1-5 rating.
	SessionRatings map[string]int
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// WithAuthor is a review joined with its author, for the organizer report.
// Callers must blank the author for anonymous reviews before display.
type WithAuthor struct {
	Review
	AuthorName  string
	AuthorEmail string
}

// CanReview: one must have accepted the invitation and the event must be over.
func CanReview(ev events.Event, accepted bool, now time.Time) error {
	if !accepted {
		return ErrNotAllowed
	}
	if ev.Status(now) != events.StatusFinished {
		return ErrNotFinished
	}
	return nil
}

type Input struct {
	Rating         string
	Comment        string
	Anonymous      bool
	SessionRatings map[string]string // session ID -> "" or "1".."5"
}

func parseStars(s string) (int, bool) {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	return n, err == nil && n >= 1 && n <= 5
}

// Parse validates the form. Ratings for sessions that don't belong to the
// event are ignored; empty session ratings are allowed.
func Parse(in Input, sessions []events.Session) (Review, map[string]string) {
	errs := map[string]string{}
	r := Review{Comment: strings.TrimSpace(in.Comment), Anonymous: in.Anonymous, SessionRatings: map[string]int{}}
	var ok bool
	if r.Rating, ok = parseStars(in.Rating); !ok {
		errs["rating"] = "err.rating"
	}
	if utf8.RuneCountInString(r.Comment) > MaxComment {
		errs["comment"] = "err.too_long"
	}
	for _, s := range sessions {
		raw := strings.TrimSpace(in.SessionRatings[s.ID])
		if raw == "" {
			continue
		}
		n, ok := parseStars(raw)
		if !ok {
			errs["sessions"] = "err.rating"
			continue
		}
		r.SessionRatings[s.ID] = n
	}
	if len(errs) > 0 {
		return Review{}, errs
	}
	return r, nil
}

type Repository interface {
	Get(ctx context.Context, eventID, userID string) (Review, error)
	// Save inserts or replaces the user's review for the event (keeping the
	// original CreatedAt). The author is stored for the organizer report;
	// it is hidden there when the review is anonymous.
	Save(ctx context.Context, r WithAuthor) error
	ListByEvent(ctx context.Context, eventID string) ([]WithAuthor, error)
}
