// Package store persists events and venue maps. Handlers depend on the Store
// interface; FirestoreStore is the production implementation and MemStore an
// in-memory fake for tests and local experiments.
package store

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"errors"
	"strings"

	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Errors returned by Store implementations.
var (
	ErrNotFound = errors.New("not found")
)

// Store is the persistence boundary. All map operations act on the draft;
// Publish copies the draft to the published version atomically.
type Store interface {
	CreateEvent(ctx context.Context, e *venue.Event) error
	GetEvent(ctx context.Context, eventID string) (*venue.Event, error)
	ListEventsByOwner(ctx context.Context, ownerUID string) ([]venue.Event, error)
	UpdateEvent(ctx context.Context, e *venue.Event) error
	DeleteEvent(ctx context.Context, eventID string) error

	// GetDraft returns the full draft map of an event.
	GetDraft(ctx context.Context, eventID string) (*venue.Map, error)
	// GetPublished returns the published map and its version (0 if never published).
	GetPublished(ctx context.Context, eventID string) (*venue.Map, int, error)

	PutFloor(ctx context.Context, eventID string, f *venue.Floor) error
	// DeleteFloor removes the floor, its graph and all its features.
	DeleteFloor(ctx context.Context, eventID, floorID string) error
	PutFeature(ctx context.Context, eventID string, f *venue.Feature) error
	DeleteFeature(ctx context.Context, eventID, featureID string) error
	PutGraph(ctx context.Context, eventID string, g *venue.Graph) error

	// Publish runs check on the current draft inside a transaction; if check
	// returns nil, the draft replaces the published map, the event's
	// publishedVersion is incremented and the new version is returned.
	Publish(ctx context.Context, eventID string, check func(*venue.Map) error) (int, error)
}

// NewID returns a random URL-safe identifier (16 lowercase base32 chars, 80 bits).
func NewID() string {
	var b [10]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err) // crypto/rand never fails on supported platforms
	}
	return strings.ToLower(base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b[:]))
}
