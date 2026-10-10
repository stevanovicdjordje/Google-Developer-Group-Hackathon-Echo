package store

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strconv"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Firestore layout. Clients may read published/** (contracts/echo/realtime.md);
// everything under echoSessions is private to the service.
//
//	events/{eventId}                                                 venue-map event (read only here)
//	events/{eventId}/published/echo/sessions/{sessionId}             EchoSession
//	events/{eventId}/published/echo/sessions/{sessionId}/lines/{n}   Line (n zero-padded)
//	events/{eventId}/echoSessions/{sessionId}/questions/{qId}        Question
//	events/{eventId}/echoSessions/{sessionId}/cache/{key}            Cached
//	events/{eventId}/echoSessions/{sessionId}/translations/{lang}    {lines: {"<index>": text}}
const (
	colEvents       = "events"
	colLines        = "lines"
	colQuestions    = "questions"
	colCache        = "cache"
	colTranslations = "translations"
)

// FirestoreStore implements Store and Replayer on Cloud Firestore.
type FirestoreStore struct {
	c *firestore.Client
}

// NewFirestoreStore wraps a Firestore client.
func NewFirestoreStore(c *firestore.Client) *FirestoreStore { return &FirestoreStore{c: c} }

var (
	_ Store    = (*FirestoreStore)(nil)
	_ Replayer = (*FirestoreStore)(nil)
)

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

func (s *FirestoreStore) event(id string) *firestore.DocumentRef {
	return s.c.Collection(colEvents).Doc(id)
}

func (s *FirestoreStore) session(eventID, sessionID string) *firestore.DocumentRef {
	return s.event(eventID).Collection("published").Doc("echo").Collection("sessions").Doc(sessionID)
}

func (s *FirestoreStore) private(eventID, sessionID string) *firestore.DocumentRef {
	return s.event(eventID).Collection("echoSessions").Doc(sessionID)
}

// LineDocID is the document ID of line index i.
func LineDocID(i int) string { return fmt.Sprintf("%05d", i) }

func (s *FirestoreStore) GetEvent(ctx context.Context, id string) (Event, error) {
	snap, err := s.event(id).Get(ctx)
	if isNotFound(err) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("get event: %w", err)
	}
	var e Event
	if err := snap.DataTo(&e); err != nil {
		return Event{}, fmt.Errorf("decode event: %w", err)
	}
	return e, nil
}

type sessionDoc struct {
	Status    string    `firestore:"status"`
	LineCount int       `firestore:"lineCount"`
	Language  string    `firestore:"language"`
	Title     string    `firestore:"title,omitempty"`
	Speaker   string    `firestore:"speaker,omitempty"`
	StartedAt time.Time `firestore:"startedAt"`
	UpdatedAt time.Time `firestore:"updatedAt"`
}

func (s *FirestoreStore) GetTranscript(ctx context.Context, eventID, sessionID string) (Transcript, error) {
	snap, err := s.session(eventID, sessionID).Get(ctx)
	if isNotFound(err) {
		return Transcript{}, ErrNoTranscript
	}
	if err != nil {
		return Transcript{}, fmt.Errorf("get session: %w", err)
	}
	var sd sessionDoc
	if err := snap.DataTo(&sd); err != nil {
		return Transcript{}, fmt.Errorf("decode session: %w", err)
	}
	t := Transcript{Status: sd.Status, Language: sd.Language, Title: sd.Title, Speaker: sd.Speaker}
	it := snap.Ref.Collection(colLines).OrderBy("index", firestore.Asc).Documents(ctx)
	defer it.Stop()
	for {
		d, err := it.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return Transcript{}, fmt.Errorf("list lines: %w", err)
		}
		var l Line
		if err := d.DataTo(&l); err != nil {
			return Transcript{}, fmt.Errorf("decode line %s: %w", d.Ref.ID, err)
		}
		t.Lines = append(t.Lines, l)
	}
	return t, nil
}

func (s *FirestoreStore) ResetTranscript(ctx context.Context, eventID, sessionID string, meta SessionMeta) error {
	ref := s.session(eventID, sessionID)
	refs, err := ref.Collection(colLines).DocumentRefs(ctx).GetAll()
	if err != nil {
		return fmt.Errorf("list old lines: %w", err)
	}
	bw := s.c.BulkWriter(ctx)
	for _, r := range refs {
		if _, err := bw.Delete(r); err != nil {
			return fmt.Errorf("delete %s: %w", r.Path, err)
		}
	}
	bw.End()
	now := time.Now().UTC()
	if _, err := ref.Set(ctx, sessionDoc{
		Status: StatusLive, Language: meta.Language, Title: meta.Title, Speaker: meta.Speaker, StartedAt: now, UpdatedAt: now,
	}); err != nil {
		return fmt.Errorf("reset session: %w", err)
	}
	return nil
}

func (s *FirestoreStore) AppendLine(ctx context.Context, eventID, sessionID string, l Line, last bool) error {
	ref := s.session(eventID, sessionID)
	st := StatusLive
	if last {
		st = StatusEnded
	}
	batch := s.c.Batch()
	batch.Set(ref.Collection(colLines).Doc(LineDocID(l.Index)), l)
	batch.Update(ref, []firestore.Update{
		{Path: "lineCount", Value: l.Index + 1},
		{Path: "status", Value: st},
		{Path: "updatedAt", Value: time.Now().UTC()},
	})
	if _, err := batch.Commit(ctx); err != nil {
		return fmt.Errorf("append line %d: %w", l.Index, err)
	}
	return nil
}

func (s *FirestoreStore) ListQuestions(ctx context.Context, eventID, sessionID string) ([]Question, error) {
	docs, err := s.private(eventID, sessionID).Collection(colQuestions).Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("list questions: %w", err)
	}
	out := make([]Question, 0, len(docs))
	for _, d := range docs {
		var q Question
		if err := d.DataTo(&q); err != nil {
			return nil, fmt.Errorf("decode question %s: %w", d.Ref.ID, err)
		}
		q.ID = d.Ref.ID
		out = append(out, q)
	}
	return out, nil
}

func (s *FirestoreStore) CreateQuestion(ctx context.Context, eventID, sessionID string, q *Question) error {
	if q.ID == "" {
		q.ID = NewID("q_")
	}
	if q.CreatedAt.IsZero() {
		q.CreatedAt = time.Now().UTC()
	}
	if q.VoterUIDs == nil {
		q.VoterUIDs = []string{}
	}
	if q.AskerUIDs == nil {
		q.AskerUIDs = []string{q.AuthorUID}
	}
	if _, err := s.private(eventID, sessionID).Collection(colQuestions).Doc(q.ID).Create(ctx, q); err != nil {
		return fmt.Errorf("create question: %w", err)
	}
	return nil
}

func (s *FirestoreStore) MergeInto(ctx context.Context, eventID, sessionID, questionID, uid string) (Question, error) {
	return s.updateQuestion(ctx, eventID, sessionID, questionID, func(q *Question) []firestore.Update {
		q.AskerUIDs = setVoter(slices.Clone(q.Askers()), uid, true)
		q.VoterUIDs = setVoter(q.VoterUIDs, uid, true)
		return []firestore.Update{{Path: "askerUids", Value: q.AskerUIDs}, {Path: "voterUids", Value: q.VoterUIDs}}
	})
}

func (s *FirestoreStore) SetVote(ctx context.Context, eventID, sessionID, questionID, uid string, on bool) (Question, error) {
	return s.updateQuestion(ctx, eventID, sessionID, questionID, func(q *Question) []firestore.Update {
		q.VoterUIDs = setVoter(q.VoterUIDs, uid, on)
		return []firestore.Update{{Path: "voterUids", Value: q.VoterUIDs}}
	})
}

func (s *FirestoreStore) updateQuestion(ctx context.Context, eventID, sessionID, questionID string,
	change func(*Question) []firestore.Update) (Question, error) {
	ref := s.private(eventID, sessionID).Collection(colQuestions).Doc(questionID)
	var q Question
	err := s.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(ref)
		if isNotFound(err) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if err := snap.DataTo(&q); err != nil {
			return err
		}
		q.ID = questionID
		return tx.Update(ref, change(&q))
	})
	if errors.Is(err, ErrNotFound) {
		return Question{}, ErrNotFound
	}
	if err != nil {
		return Question{}, fmt.Errorf("update question: %w", err)
	}
	return q, nil
}

func (s *FirestoreStore) GetCached(ctx context.Context, eventID, sessionID, key string) (Cached, bool, error) {
	snap, err := s.private(eventID, sessionID).Collection(colCache).Doc(key).Get(ctx)
	if isNotFound(err) {
		return Cached{}, false, nil
	}
	if err != nil {
		return Cached{}, false, fmt.Errorf("get cache: %w", err)
	}
	var c Cached
	if err := snap.DataTo(&c); err != nil {
		return Cached{}, false, fmt.Errorf("decode cache: %w", err)
	}
	return c, true, nil
}

func (s *FirestoreStore) PutCached(ctx context.Context, eventID, sessionID, key string, v Cached) error {
	if _, err := s.private(eventID, sessionID).Collection(colCache).Doc(key).Set(ctx, v); err != nil {
		return fmt.Errorf("put cache: %w", err)
	}
	return nil
}

func (s *FirestoreStore) GetTranslations(ctx context.Context, eventID, sessionID, language string) (map[int]string, error) {
	snap, err := s.private(eventID, sessionID).Collection(colTranslations).Doc(language).Get(ctx)
	if isNotFound(err) {
		return map[int]string{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get translations: %w", err)
	}
	var doc struct {
		Lines map[string]string `firestore:"lines"`
	}
	if err := snap.DataTo(&doc); err != nil {
		return nil, fmt.Errorf("decode translations: %w", err)
	}
	out := make(map[int]string, len(doc.Lines))
	for k, v := range doc.Lines {
		if i, err := strconv.Atoi(k); err == nil {
			out[i] = v
		}
	}
	return out, nil
}

func (s *FirestoreStore) PutTranslations(ctx context.Context, eventID, sessionID, language string, lines map[int]string) error {
	m := make(map[string]any, len(lines))
	for i, t := range lines {
		m[strconv.Itoa(i)] = t
	}
	ref := s.private(eventID, sessionID).Collection(colTranslations).Doc(language)
	if _, err := ref.Set(ctx, map[string]any{"lines": m}, firestore.MergeAll); err != nil {
		return fmt.Errorf("put translations: %w", err)
	}
	return nil
}
