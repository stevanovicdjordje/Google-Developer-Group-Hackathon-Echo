package reviews

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
)

func TestCanReview(t *testing.T) {
	now := time.Date(2026, 10, 10, 12, 0, 0, 0, time.UTC)
	p := func(h int) *time.Time { t := now.Add(time.Duration(h) * time.Hour); return &t }
	finished := events.Event{StartsAt: p(-10), EndsAt: p(-2), PublishedAt: p(-100)}
	ongoing := events.Event{StartsAt: p(-1), EndsAt: p(2), PublishedAt: p(-100)}
	if err := CanReview(finished, true, now); err != nil {
		t.Fatal(err)
	}
	if err := CanReview(finished, false, now); !errors.Is(err, ErrNotAllowed) {
		t.Fatalf("got %v", err)
	}
	if err := CanReview(ongoing, true, now); !errors.Is(err, ErrNotFinished) {
		t.Fatalf("got %v", err)
	}
}

func TestParse(t *testing.T) {
	sessions := []events.Session{{ID: "s1"}, {ID: "s2"}}
	r, errs := Parse(Input{Rating: "4", Comment: "  Super  ", SessionRatings: map[string]string{"s1": "5", "s2": "", "other": "1"}}, sessions)
	if errs != nil {
		t.Fatal(errs)
	}
	if r.Rating != 4 || r.Comment != "Super" || len(r.SessionRatings) != 1 || r.SessionRatings["s1"] != 5 {
		t.Fatalf("got %+v", r)
	}
	for _, bad := range []Input{
		{Rating: ""}, {Rating: "6"}, {Rating: "0"},
		{Rating: "3", SessionRatings: map[string]string{"s1": "9"}},
		{Rating: "3", Comment: strings.Repeat("a", MaxComment+1)},
	} {
		if _, errs := Parse(bad, sessions); errs == nil {
			t.Errorf("expected error for %+v", bad)
		}
	}
}
