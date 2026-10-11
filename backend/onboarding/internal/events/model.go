// Package events holds events, venue maps, zones and the session schedule.
package events

import (
	"errors"
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

var (
	ErrNotFound = errors.New("events: not found")
)

type Event struct {
	ID             string
	OrganizationID string
	Title          string
	Description    string
	StartsAt       *time.Time
	EndsAt         *time.Time
	Address        string
	Lat, Lng       *float64
	PublishedAt    *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Status derives the lifecycle: draft until published, then upcoming /
// ongoing / finished from the event dates.
func (e Event) Status(now time.Time) Status {
	if e.PublishedAt == nil || e.StartsAt == nil || e.EndsAt == nil {
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

type ZoneKind string

var ZoneKinds = []ZoneKind{"hall", "booth", "entrance", "toilet", "food", "info", "other"}

const ZoneHall ZoneKind = "hall"

func (k ZoneKind) Valid() bool {
	for _, x := range ZoneKinds {
		if x == k {
			return true
		}
	}
	return false
}

// Zone is a rectangle on the floor plan, in percent of the image size.
type Zone struct {
	ID      string
	EventID string
	Name    string
	Kind    ZoneKind
	X, Y    float64
	W, H    float64
	Created time.Time
}

type VenueMap struct {
	EventID     string
	FileName    string
	ContentType string
	Width       int
	Height      int
	UploadedAt  time.Time
}

type Session struct {
	ID          string
	EventID     string
	ZoneID      string // "" when no hall is assigned
	Title       string
	Description string
	Speaker     string
	StartsAt    time.Time
	EndsAt      time.Time
	Tags        []string
}

type Repository interface {
	Create(e Event) error
	Update(e Event) error
	Get(id string) (Event, error)
	ListByOrganization(orgID string) ([]Summary, error)
	StatsFor(eventID string) (Stats, error)

	GetVenueMap(eventID string) (VenueMap, error)
	SaveVenueMap(m VenueMap) error
	ListZones(eventID string) ([]Zone, error)
	CreateZone(z Zone) error
	DeleteZone(eventID, zoneID string) error

	ListSessions(eventID string) ([]Session, error)
	CreateSession(s Session) error
	DeleteSession(eventID, sessionID string) error
}
