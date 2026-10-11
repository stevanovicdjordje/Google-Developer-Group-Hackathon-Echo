// Package store persists Find data. Handlers depend on the Store interface;
// FirestoreStore is the production implementation and MemStore an in-memory
// fake for tests.
package store

import (
	"context"
	"crypto/rand"
	"errors"
	"time"
)

// Errors returned by Store implementations.
var (
	ErrNotFound = errors.New("not found")
	// ErrNoProfile is returned by Join when the user has no profile.
	ErrNoProfile = errors.New("no profile")
)

// Contact states as stored.
const (
	StateRequested = "requested"
	StateAccepted  = "accepted"
)

// Event is the part of the venue-map event document Find needs.
type Event struct {
	Name             string `firestore:"name"`
	PublishedVersion int    `firestore:"publishedVersion"`
}

// Published reports whether attendees can see the event.
func (e Event) Published() bool { return e.PublishedVersion > 0 }

// ProfileFields are what the attendee sets (ProfileInput in the contract).
type ProfileFields struct {
	Name             string   `firestore:"name"`
	Headline         string   `firestore:"headline"`
	Interests        []string `firestore:"interests"`
	LookingFor       string   `firestore:"lookingFor"`
	VisibleInFind    bool     `firestore:"visibleInFind"`
	AllowContact     bool     `firestore:"allowContact"`
	ShareMeetingSpot bool     `firestore:"shareMeetingSpot"`
}

// Profile is the stored profile. PersonID, Events and Demo are managed by the
// service; the UID is the document ID and never leaves the service.
type Profile struct {
	ProfileFields
	UID       string    `firestore:"-"`
	UpdatedAt time.Time `firestore:"updatedAt"`
	// PersonID is the opaque public ID (Person.id), generated on first save.
	PersonID string `firestore:"personId"`
	// Events are the event IDs the user is present at (for deletion).
	Events []string `firestore:"events"`
	// Demo marks seeded attendees, who accept contact requests at once.
	Demo bool `firestore:"demo"`
}

// Attendee is a person present at an event, with their profile.
type Attendee struct {
	Profile
	JoinedAt time.Time
}

// MeetingSpot is an agreed place on the venue map.
type MeetingSpot struct {
	Place string `firestore:"place"`
	// Time is the agreed time of day, "HH:mm" (24 h), or "".
	Time      string    `firestore:"time,omitempty"`
	SetBy     string    `firestore:"setBy"`
	UpdatedAt time.Time `firestore:"updatedAt"`
}

// Contact is a contact request between two attendees at an event. A < B.
type Contact struct {
	A           string       `firestore:"a"`
	B           string       `firestore:"b"`
	From        string       `firestore:"from"`
	State       string       `firestore:"state"`
	CreatedAt   time.Time    `firestore:"createdAt"`
	MeetingSpot *MeetingSpot `firestore:"meetingSpot,omitempty"`
}

// Other returns the uid of the side that isn't uid.
func (c Contact) Other(uid string) string {
	if c.A == uid {
		return c.B
	}
	return c.A
}

// Pair returns the two uids sorted, and the contact document ID.
func Pair(x, y string) (a, b, id string) {
	if y < x {
		x, y = y, x
	}
	return x, y, x + "_" + y
}

// Store is the persistence boundary of the Find service.
type Store interface {
	GetEvent(ctx context.Context, id string) (Event, error)

	// GetProfile returns ErrNotFound when the user has no profile.
	GetProfile(ctx context.Context, uid string) (Profile, error)
	// SaveProfile creates or replaces the attendee-set fields, keeping (or
	// generating) PersonID, Events and Demo.
	SaveProfile(ctx context.Context, uid string, f ProfileFields, now time.Time) (Profile, error)
	// DeleteProfile removes the profile, its presence docs and the user's
	// contacts at those events. No error when there is nothing to delete.
	DeleteProfile(ctx context.Context, uid string) error

	// Join marks uid present at the event (ErrNoProfile without a profile).
	Join(ctx context.Context, eventID, uid string, now time.Time) error
	// Leave removes the presence (no error when absent).
	Leave(ctx context.Context, eventID, uid string) error
	// IsPresent reports whether uid is present at the event.
	IsPresent(ctx context.Context, eventID, uid string) (bool, error)
	// People returns everyone present at the event who has a profile.
	People(ctx context.Context, eventID string) ([]Attendee, error)
	// PersonByID resolves a personId present at the event (ErrNotFound otherwise).
	PersonByID(ctx context.Context, eventID, personID string) (Attendee, error)

	// GetContact returns the contact between x and y (ErrNotFound if none).
	GetContact(ctx context.Context, eventID, x, y string) (Contact, error)
	// UpdateContact runs fn on the contact between x and y atomically. c is
	// nil when there is none; fn returns the contact to store (nil = no write).
	UpdateContact(ctx context.Context, eventID, x, y string, fn func(c *Contact) (*Contact, error)) (Contact, error)
	// Contacts returns uid's contacts at the event, in any order.
	Contacts(ctx context.Context, eventID, uid string) ([]Contact, error)

	// FeatureName returns the published venue-map feature whose name matches
	// place case-insensitively, in the map's spelling (ErrNotFound if none).
	FeatureName(ctx context.Context, eventID, place string) (string, error)
}

const idAlphabet = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"

// NewPersonID returns a random opaque 16-character ID.
func NewPersonID() string {
	// Rejection sampling keeps every character equally likely.
	limit := byte(256 / len(idAlphabet) * len(idAlphabet))
	out := make([]byte, 0, 16)
	buf := make([]byte, 32)
	for len(out) < 16 {
		if _, err := rand.Read(buf); err != nil {
			panic(err)
		}
		for _, c := range buf {
			if c < limit && len(out) < 16 {
				out = append(out, idAlphabet[int(c)%len(idAlphabet)])
			}
		}
	}
	return string(out)
}
