package reports

import (
	"bytes"
	"context"
	"fmt"
	"math"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/i18n"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

var now = time.Date(2026, 10, 10, 12, 0, 0, 0, time.UTC)

func ptr(t time.Time) *time.Time { return &t }

func fixture() Input {
	ev := events.Event{ID: "e", Title: "Go dan", StartsAt: ptr(now.Add(-10 * time.Hour)),
		EndsAt: ptr(now.Add(-2 * time.Hour)), PublishedAt: ptr(now.Add(-100 * time.Hour))}
	inv := func(st invitations.Status) invitations.Invitation {
		return invitations.Invitation{Status: st, ExpiresAt: now.Add(time.Hour)}
	}
	rv := func(id string, rating int, comment string, anon bool, sess map[string]int) reviews.WithAuthor {
		return reviews.WithAuthor{Review: reviews.Review{ID: id, Rating: rating, Comment: comment, Anonymous: anon,
			SessionRatings: sess, UpdatedAt: now}, AuthorName: "Autor " + id, AuthorEmail: id + "@primer.rs"}
	}
	return Input{
		Event: ev,
		// 4 accepted, 1 declined, 1 sent (expired because the event ended)
		Invitations: []invitations.Invitation{inv("accepted"), inv("accepted"), inv("accepted"), inv("accepted"), inv("declined"), inv("sent")},
		Reviews: []reviews.WithAuthor{
			rv("r1", 5, "Odlična organizacija i odlični govornici", false, map[string]int{"s1": 5, "s2": 2}),
			rv("r2", 4, "Organizacija odlična, hrana slaba", true, map[string]int{"s1": 4}),
			rv("r3", 2, "", false, map[string]int{"s2": 1}),
		},
		Sessions: []events.Session{{ID: "s1", Title: "Keynote"}, {ID: "s2", Title: "Panel"}, {ID: "s3", Title: "Radionica"},
			{ID: "b", Title: "Pauza", IsBreak: true}},
		Now: now,
	}
}

func near(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

func TestCompute(t *testing.T) {
	r := Compute(fixture())
	if r.Invited != 6 || r.Accepted != 4 || r.Declined != 1 || r.Expired != 1 || r.Pending != 0 {
		t.Fatalf("turnout: %+v", r)
	}
	if !near(r.AcceptanceRate, 4.0/6) || !near(r.ResponseRate, 3.0/4) || !near(r.AvgRating, 11.0/3) {
		t.Fatalf("rates: %v %v %v", r.AcceptanceRate, r.ResponseRate, r.AvgRating)
	}
	if r.Distribution[0].Stars != 5 || r.Distribution[0].Count != 1 || r.Distribution[3].Count != 1 {
		t.Fatalf("distribution: %+v", r.Distribution)
	}
	if r.Sessions[0].Session.ID != "s1" || !near(r.Sessions[0].Avg, 4.5) || r.Sessions[1].Session.ID != "s2" ||
		r.Sessions[2].Count != 0 {
		t.Fatalf("session ranking: %+v", r.Sessions)
	}
	if len(r.Comments) != 2 {
		t.Fatalf("comments: %+v", r.Comments)
	}
	for _, c := range r.Comments {
		if strings.Contains(c.Text, "hrana") && c.Author != "" {
			t.Fatal("anonymous review must not expose its author")
		}
	}
}

func TestComputeEmpty(t *testing.T) {
	r := Compute(Input{Event: fixture().Event, Now: now})
	if r.AvgRating != 0 || r.ResponseRate != 0 || r.AcceptanceRate != 0 || len(r.Distribution) != 5 {
		t.Fatalf("empty report: %+v", r)
	}
}

func TestStatSummarizer(t *testing.T) {
	s := StatSummarizer{T: i18n.New("sr").T}
	sum, err := s.Summarize(context.Background(), Compute(fixture()))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(sum.Headline, "Dobar utisak") {
		t.Errorf("headline: %q", sum.Headline)
	}
	all := strings.Join(append(append(sum.Liked, sum.Disliked...), sum.Recommendations...), " | ")
	for _, want := range []string{"Keynote", "Panel", "organizacija", "odlična"} {
		if !strings.Contains(all, want) {
			t.Errorf("summary missing %q: %s", want, all)
		}
	}
	empty, _ := s.Summarize(context.Background(), Compute(Input{Event: fixture().Event, Now: now}))
	if empty.Headline == "" || len(empty.Recommendations) == 0 {
		t.Errorf("empty summary: %+v", empty)
	}
}

func TestWritePDF(t *testing.T) {
	in := fixture()
	// Serbian letters and enough comments to need a second page.
	for i := 0; i < 40; i++ {
		in.Reviews = append(in.Reviews, reviews.WithAuthor{Review: reviews.Review{ID: fmt.Sprint("x", i), Rating: 1 + i%5,
			Comment: "Čačak, Đorđe, šećer i žurka – odlična organizacija „Echo“.", UpdatedAt: now}, AuthorName: "Đurđa Šović"})
	}
	b := i18n.New("sr")
	rep := Compute(in)
	sum, _ := StatSummarizer{T: b.T, Rating: b.Rating}.Summarize(context.Background(), rep)
	var buf bytes.Buffer
	err := WritePDF(&buf, rep, sum, PDFText{T: b.T, Rating: b.Rating,
		Date: func(t time.Time) string { return t.Format("02.01.2006. 15:04") },
		Day:  func(t time.Time) string { return t.Format("02.01.2006.") }})
	if err != nil {
		t.Fatal(err)
	}
	out := buf.Bytes()
	if !bytes.HasPrefix(out, []byte("%PDF-")) || !bytes.Contains(out[len(out)-32:], []byte("%%EOF")) {
		t.Fatalf("not a complete PDF (%d bytes)", len(out))
	}
	if n := bytes.Count(out, []byte("/Type /Page\n")) + bytes.Count(out, []byte("/Type /Page ")); n < 2 {
		t.Errorf("expected at least 2 pages, got %d", n)
	}
}

func TestWriteTalkPDF(t *testing.T) {
	b := i18n.New("sr")
	tx := PDFText{T: b.T, Rating: b.Rating,
		Date:  func(t time.Time) string { return t.Format("02.01.2006. 15:04") },
		Day:   func(t time.Time) string { return t.Format("02.01.2006.") },
		Clock: func(t time.Time) string { return t.Format("15:04") }}
	in := fixture()
	count, avg, dist := TalkRatings(in.Reviews, "s1")
	if count != 2 || avg != 4.5 || dist[0].Count != 1 {
		t.Fatalf("talk ratings: %d %v %+v", count, avg, dist)
	}
	qs := TopQuestions([]TalkQuestion{{"a", 1}, {"b", 7}, {"c", 3}}, 2)
	if len(qs) != 2 || qs[0].Text != "b" || qs[1].Text != "c" {
		t.Fatalf("top questions: %+v", qs)
	}
	tr := TalkReport{Event: in.Event, Session: events.Session{ID: "s1", Title: "Šta je novo u Go-u", Speaker: "Đorđe Ćirić",
		Stage: "Glavna sala", StartsAt: now.Add(-3 * time.Hour), EndsAt: now.Add(-2 * time.Hour)},
		Summary: &TalkSummary{Model: "gemma", Takeaway: "Lokalni modeli menjaju cenu.", KeyPoints: []string{"Prva tačka", "Druga tačka"},
			Tradeoffs: []Tradeoff{{Topic: "Baterija", Issue: "Troši bateriju", Fix: "Kvantizacija", AtSeconds: 125}}},
		Ratings: count, AvgRating: avg, Distribution: dist, Questions: qs}
	for _, sum := range []*TalkSummary{tr.Summary, nil} {
		tr.Summary = sum
		var buf bytes.Buffer
		if err := WriteTalkPDF(&buf, tr, tx); err != nil {
			t.Fatal(err)
		}
		if !bytes.HasPrefix(buf.Bytes(), []byte("%PDF-")) {
			t.Fatal("not a PDF")
		}
	}
}
