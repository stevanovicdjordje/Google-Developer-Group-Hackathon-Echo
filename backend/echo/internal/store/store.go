// Package store persists Echo data. Handlers depend on the Store interface;
// FirestoreStore is the production implementation and MemStore an in-memory
// fake for tests.
package store

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"errors"
	"strings"
	"time"
)

// Errors returned by Store implementations.
var (
	ErrNotFound     = errors.New("not found")
	ErrNoTranscript = errors.New("no transcript")
)

// Session statuses (contracts/echo/realtime.md).
const (
	StatusLive  = "live"
	StatusEnded = "ended"
)

// Event is the part of the venue-map event document Echo needs.
type Event struct {
	OwnerUID         string `firestore:"ownerUid"`
	PublishedVersion int    `firestore:"publishedVersion"`
}

// Published reports whether attendees can see the event.
func (e Event) Published() bool { return e.PublishedVersion > 0 }

// Line is one transcript line.
type Line struct {
	Index     int    `json:"index" firestore:"index"`
	AtSeconds int    `json:"atSeconds" firestore:"atSeconds"`
	Text      string `json:"text" firestore:"text"`
}

// Transcript is a session's transcript revealed so far.
type Transcript struct {
	Status   string
	Language string
	Title    string
	Speaker  string
	Lines    []Line
}

// Question is an audience question. AuthorUID and VoterUIDs never leave the
// service.
type Question struct {
	ID        string    `firestore:"-"`
	Text      string    `firestore:"text"`
	AuthorUID string    `firestore:"authorUid"`
	VoterUIDs []string  `firestore:"voterUids"`
	CreatedAt time.Time `firestore:"createdAt"`
}

// Votes is the number of votes.
func (q Question) Votes() int { return len(q.VoterUIDs) }

// VotedBy reports whether uid has voted.
func (q Question) VotedBy(uid string) bool {
	for _, v := range q.VoterUIDs {
		if v == uid {
			return true
		}
	}
	return false
}

// Store is the persistence boundary.
type Store interface {
	GetEvent(ctx context.Context, eventID string) (Event, error)
	// GetTranscript returns the lines written so far, ordered by index.
	GetTranscript(ctx context.Context, eventID, sessionID string) (Transcript, error)

	ListQuestions(ctx context.Context, eventID, sessionID string) ([]Question, error)
	CreateQuestion(ctx context.Context, eventID, sessionID string, q *Question) error
	// SetVote adds or removes uid's vote and returns the updated question.
	SetVote(ctx context.Context, eventID, sessionID, questionID, uid string, on bool) (Question, error)

	// GetCached returns a cached AI result for key, or ok=false.
	GetCached(ctx context.Context, eventID, sessionID, key string) (value Cached, ok bool, err error)
	PutCached(ctx context.Context, eventID, sessionID, key string, value Cached) error
	// GetTranslations returns cached line translations for a language, by line index.
	GetTranslations(ctx context.Context, eventID, sessionID, language string) (map[int]string, error)
	PutTranslations(ctx context.Context, eventID, sessionID, language string, lines map[int]string) error
}

// Cached is a stored AI answer.
type Cached struct {
	Text  string `firestore:"text"`
	Model string `firestore:"model"`
	Lines int    `firestore:"basedOnLines"`
}

// Replayer writes the transcript (cmd/replay).
type Replayer interface {
	// ResetTranscript deletes old lines and marks the session live with 0 lines.
	ResetTranscript(ctx context.Context, eventID, sessionID string, meta SessionMeta) error
	// AppendLine writes one line; last marks the session ended.
	AppendLine(ctx context.Context, eventID, sessionID string, l Line, last bool) error
}

// SessionMeta describes the talk a transcript belongs to.
type SessionMeta struct {
	Language string
	Title    string
	Speaker  string
}

// NewID returns a random, URL-safe ID with the given prefix.
func NewID(prefix string) string {
	b := make([]byte, 10)
	_, _ = rand.Read(b)
	return prefix + strings.ToLower(base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b))
}
