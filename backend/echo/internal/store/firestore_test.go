package store

import (
	"context"
	"errors"
	"os"
	"testing"

	"cloud.google.com/go/firestore"
)

// Runs only against the Firestore emulator (FIRESTORE_EMULATOR_HOST).
func newEmulatorStore(t *testing.T) (*FirestoreStore, *firestore.Client) {
	t.Helper()
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		t.Skip("FIRESTORE_EMULATOR_HOST not set")
	}
	c, err := firestore.NewClient(context.Background(), "demo-eho-test")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return NewFirestoreStore(c), c
}

func TestFirestoreStore(t *testing.T) {
	s, c := newEmulatorStore(t)
	ctx := context.Background()
	ev := NewID("ev_")
	if _, err := c.Collection("events").Doc(ev).Set(ctx, map[string]any{"ownerUid": "org", "publishedVersion": 2, "name": "x"}); err != nil {
		t.Fatal(err)
	}
	if e, err := s.GetEvent(ctx, ev); err != nil || !e.Published() || e.OwnerUID != "org" {
		t.Fatalf("event %+v %v", e, err)
	}
	if _, err := s.GetEvent(ctx, "missing"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing event: %v", err)
	}
	if _, err := s.GetTranscript(ctx, ev, "s1"); !errors.Is(err, ErrNoTranscript) {
		t.Fatalf("no transcript: %v", err)
	}

	for round := range 2 {
		if err := s.ResetTranscript(ctx, ev, "s1", SessionMeta{Language: "en", Title: "T", Speaker: "Mara"}); err != nil {
			t.Fatal(err)
		}
		for i := range 12 {
			if err := s.AppendLine(ctx, ev, "s1", Line{Index: i, AtSeconds: i * 3, Text: "line"}, i == 11); err != nil {
				t.Fatal(err)
			}
		}
		tr, err := s.GetTranscript(ctx, ev, "s1")
		if err != nil || len(tr.Lines) != 12 || tr.Status != StatusEnded || tr.Lines[10].Index != 10 || tr.Speaker != "Mara" {
			t.Fatalf("round %d: %+v %v", round, tr, err)
		}
	}
	snap, err := c.Doc("events/" + ev + "/published/echo/sessions/s1").Get(ctx)
	if err != nil || snap.Data()["lineCount"] != int64(12) {
		t.Fatalf("session doc %v %v", snap.Data(), err)
	}

	q := Question{Text: "Why?", AuthorUID: "a1", VoterUIDs: []string{"a1"}}
	if err := s.CreateQuestion(ctx, ev, "s1", &q); err != nil {
		t.Fatal(err)
	}
	if got, err := s.SetVote(ctx, ev, "s1", q.ID, "a2", true); err != nil || got.Votes() != 2 {
		t.Fatalf("vote %+v %v", got, err)
	}
	if got, _ := s.SetVote(ctx, ev, "s1", q.ID, "a2", true); got.Votes() != 2 {
		t.Fatal("vote is not idempotent")
	}
	if got, _ := s.SetVote(ctx, ev, "s1", q.ID, "a1", false); got.Votes() != 1 || got.VotedBy("a1") {
		t.Fatalf("unvote %+v", got)
	}
	if _, err := s.SetVote(ctx, ev, "s1", "nope", "a1", true); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unknown question: %v", err)
	}
	if qs, err := s.ListQuestions(ctx, ev, "s1"); err != nil || len(qs) != 1 || qs[0].ID != q.ID {
		t.Fatalf("list %+v %v", qs, err)
	}

	if _, ok, _ := s.GetCached(ctx, ev, "s1", "k"); ok {
		t.Fatal("unexpected cache hit")
	}
	_ = s.PutCached(ctx, ev, "s1", "k", Cached{Text: "t", Model: "m", Lines: 3})
	if c, ok, err := s.GetCached(ctx, ev, "s1", "k"); !ok || err != nil || c.Lines != 3 {
		t.Fatalf("cache %+v %v %v", c, ok, err)
	}

	_ = s.PutTranslations(ctx, ev, "s1", "m_sr", map[int]string{0: "a", 1: "b"})
	_ = s.PutTranslations(ctx, ev, "s1", "m_sr", map[int]string{2: "c"})
	if tr, err := s.GetTranslations(ctx, ev, "s1", "m_sr"); err != nil || len(tr) != 3 || tr[2] != "c" {
		t.Fatalf("translations %v %v", tr, err)
	}
}
