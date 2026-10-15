// Package store is the persistence boundary of the events service.
//
// Firestore layout (Admin SDK only; security rules deny clients):
//
//	events/{eventId}                         event doc, shared with the venue map (contracts/maps):
//	                                         name, startDate, endDate, address, ownerUid, publishedVersion, …
//	events/{eventId}/draft/map               created with a new event, so the map editor can open it
//	events/{eventId}/published/map/features  venue-map features (read only here: type, name)
//	events/{eventId}/published/agenda        the published agenda (stages, speakers, sessions, publishedAt)
//	members/{uid}/events/{eventId}           joinedAt: the caller's "My events"
//	organizerDrafts/{draftId}                ownerUid, the extracted/edited draft, issues, model, source files
package store

import (
	"context"
	"crypto/rand"
	"errors"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

// Errors returned by Store implementations.
var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("already exists")
)

// Event is the part of the shared event doc this service reads and writes.
type Event struct {
	ID               string
	Name             string
	StartDate        string
	EndDate          string
	Address          string
	OwnerUID         string
	PublishedVersion int
}

// SourceFile describes an uploaded file (the file itself is not stored).
type SourceFile struct {
	Name      string `json:"name" firestore:"name"`
	SizeBytes int    `json:"sizeBytes" firestore:"sizeBytes"`
	Type      string `json:"type" firestore:"type"`
}

// Draft is an organizer's extracted event before (and after) publishing.
type Draft struct {
	ID               string
	OwnerUID         string
	Fields           agenda.Fields
	Issues           []agenda.Issue
	Model            string
	SourceFiles      []SourceFile
	PublishedEventID string
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// Membership is one joined event.
type Membership struct {
	EventID  string
	JoinedAt time.Time
}

// Publication is what PublishAgenda writes.
type Publication struct {
	// Event carries the new name, dates and address (and, when Create is
	// set, the owner and ID of the new event).
	Event  Event
	Create bool
	Agenda agenda.Agenda
	// DraftID is marked as published into Event.ID.
	DraftID string
}

// Store is implemented by FirestoreStore and MemStore.
type Store interface {
	GetEvent(ctx context.Context, id string) (*Event, error)
	// RoomNames lists the names of rooms on the published venue map (empty
	// if no map is published).
	RoomNames(ctx context.Context, eventID string) ([]string, error)
	HasMap(ctx context.Context, eventID string) (bool, error)

	GetAgenda(ctx context.Context, eventID string) (*agenda.Agenda, error)
	// PublishAgenda creates or updates the event doc and replaces its agenda
	// in one transaction.
	PublishAgenda(ctx context.Context, p Publication) error

	Join(ctx context.Context, uid, eventID string, at time.Time) error
	Leave(ctx context.Context, uid, eventID string) error
	ListMemberships(ctx context.Context, uid string) ([]Membership, error)

	CreateDraft(ctx context.Context, d *Draft) error
	GetDraft(ctx context.Context, id string) (*Draft, error)
	UpdateDraft(ctx context.Context, d *Draft) error
}

// NewID returns a random 16-character ID [a-z0-9].
func NewID() string {
	const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = alphabet[int(b[i])%len(alphabet)]
	}
	return string(b)
}
