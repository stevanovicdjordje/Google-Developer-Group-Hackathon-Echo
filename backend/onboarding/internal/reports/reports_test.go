package reports

import (
	"bytes"
	"context"
	"encoding/csv"
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
		Sessions:  []events.Session{{ID: "s1", Title: "Keynote"}, {ID: "s2", Title: "Panel"}, {ID: "s3", Title: "Radionica"}},
		ZoneNames: map[string]string{},
		Now:       now,
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

func TestWriteCSV(t *testing.T) {
	in := fixture()
	in.Reviews[0].Comment = "=HYPERLINK(\"http://evil\")"
	var buf bytes.Buffer
	if err := WriteCSV(&buf, in.Reviews, in.Sessions, time.UTC); err != nil {
		t.Fatal(err)
	}
	rows, err := csv.NewReader(&buf).ReadAll()
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 4 || len(rows[0]) != 7+3 {
		t.Fatalf("shape: %d rows, %d cols", len(rows), len(rows[0]))
	}
	if !strings.HasPrefix(rows[1][6], "'=") {
		t.Errorf("formula not neutralized: %q", rows[1][6])
	}
	if rows[2][2] != "" || rows[2][3] != "" || rows[2][4] != "true" {
		t.Errorf("anonymous row leaks author: %v", rows[2])
	}
	if got := fmt.Sprint(rows[1][7:]); got != "[5 2 ]" {
		t.Errorf("session columns: %s", got)
	}
}
