// Package events: the organizer's events, their agenda (schedule) and the
// published venue map. Events are the shared events/{eventId} documents of
// the Echo backend (backend/maps, backend/events), so an event created here
// also appears in the map editor and the Flutter app, and vice versa.
package events

import (
	"context"
	"crypto/rand"
	"errors"
	"io"
	"time"
)

type Status string

const (
	StatusDraft     Status = "draft"
	StatusPublished Status = "published" // published, not started yet ("upcoming")
	StatusOngoing   Status = "ongoing"
	StatusFinished  Status = "finished"
)

// Statuses in the order the organizer list shows them.
var Statuses = []Status{StatusDraft, StatusPublished, StatusOngoing, StatusFinished}

func ParseStatus(s string) (Status, bool) {
	for _, x := range Statuses {
		if string(x) == s {
			return x, true
		}
	}
	return "", false
}

var ErrNotFound = errors.New("events: not found")

type Event struct {
	ID          string
	OwnerUID    string
	Title       string // shared field "name"
	Description string
	// StartsAt/EndsAt are exact times. Events created elsewhere only have
	// startDate/endDate; then they span those whole days.
	StartsAt *time.Time
	EndsAt   *time.Time
	Address  string
	Lat, Lng *float64
	// PublishedAt is set when the organizer publishes the event here.
	PublishedAt *time.Time
	// MapVersion is the venue map's publishedVersion (>0: the map is
	// published and attendees already see the event in the app).
	MapVersion int
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// Published reports whether attendees can see the event.
func (e Event) Published() bool { return e.PublishedAt != nil || e.MapVersion > 0 }

// Status derives the lifecycle: draft until published, then upcoming /
// ongoing / finished from the event dates.
func (e Event) Status(now time.Time) Status {
	if !e.Published() || e.StartsAt == nil || e.EndsAt == nil {
		return StatusDraft
	}
	switch {
	case now.Before(*e.StartsAt):
		return StatusPublished
	case now.Before(*e.EndsAt):
		return StatusOngoing
	default:
		return StatusFinished
	}
}

// Editable reports whether the organizer may still change the event.
func (e Event) Editable(now time.Time) bool { return e.Status(now) != StatusFinished }

// Stats are the list/report counters for one event.
type Stats struct {
	Invited   int
	Accepted  int
	Declined  int
	Reviews   int
	AvgRating float64 // 0 when there are no reviews
}

type Summary struct {
	Event
	Stats
}

// Session is one agenda item with its times resolved to instants.
type Session struct {
	ID          string
	Title       string
	Stage       string // hall / room name; matches a room on the venue map
	Speaker     string // names joined with ", "
	Description string
	StartsAt    time.Time
	EndsAt      time.Time
	Tags        []string // the agenda's "track", split on commas
	IsBreak     bool
}

// NewID returns a random 16-character [a-z0-9] ID, the same format the
// other backend services use for events.
func NewID() string {
	const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = alphabet[int(b[i])%len(alphabet)]
	}
	return string(b)
}

type Repository interface {
	Create(ctx context.Context, e Event) error
	Update(ctx context.Context, e Event) error
	Get(ctx context.Context, id string) (Event, error)
	ListByOwner(ctx context.Context, uid string) ([]Event, error)
	// ListPublished returns every event attendees can see (any organizer).
	ListPublished(ctx context.Context) ([]Event, error)

	// GetAgenda returns the published agenda, or an empty one.
	GetAgenda(ctx context.Context, eventID string) (Agenda, error)
	SaveAgenda(ctx context.Context, eventID string, a Agenda) error
	// GetPublishedMap returns the published venue map, or an empty one.
	GetPublishedMap(ctx context.Context, eventID string) (Map, error)
}

// Images reads floor-plan images (Cloud Storage).
type Images interface {
	FloorImage(ctx context.Context, path string) (io.ReadCloser, string, error)
}

// StatsSource counts invitations and reviews for an event.
type StatsSource interface {
	EventStats(ctx context.Context, eventID string) (Stats, error)
}
