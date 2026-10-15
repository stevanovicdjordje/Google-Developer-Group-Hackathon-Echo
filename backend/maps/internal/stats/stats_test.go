package stats

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"
)

func TestNormalizeQuery(t *testing.T) {
	long := ""
	for range 70 {
		long += "š"
	}
	cases := map[string]string{
		"  Čačak   DEV ": "čačak dev",
		"a":              "",
		"  ":             "",
		"wc":             "wc",
		long:             long[:2*MaxQueryRunes], // š is 2 bytes
	}
	for in, want := range cases {
		if got := NormalizeQuery(in); got != want {
			t.Errorf("NormalizeQuery(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestDayAddMergeCap(t *testing.T) {
	d := NewDay("2026-10-11")
	d.Add(Event{Kind: Search, Query: "kafa", ResultCount: 0})
	d.Add(Event{Kind: Search, Query: "kafa", ResultCount: 2})
	d.Add(Event{Kind: FeatureView, FeatureID: "s1"})
	d.Add(Event{Kind: Route, FeatureID: "s1"})
	d.Add(Event{Kind: QRScan, FeatureID: "qr"})
	if d.Searches != 2 || d.SearchesNoResults != 1 || d.SearchTerms["kafa"] != 2 || d.NoResultTerms["kafa"] != 1 ||
		d.FeatureViewsBy["s1"] != 1 || d.RouteTargets["s1"] != 1 || d.QRScansBy["qr"] != 1 {
		t.Fatalf("day = %+v", d)
	}

	stored := &Day{Date: d.Date} // decoded doc: nil maps
	stored.Merge(d)
	stored.Merge(d)
	if stored.Searches != 4 || stored.SearchTerms["kafa"] != 4 || stored.QRScans != 2 {
		t.Fatalf("merged = %+v", stored)
	}

	full := NewDay(d.Date)
	for i := range MaxTermsPerDay + 10 {
		full.Add(Event{Kind: Search, Query: fmt.Sprint("q", i), ResultCount: 1})
	}
	full.Add(Event{Kind: Search, Query: "q0", ResultCount: 1})
	if len(full.SearchTerms) != MaxTermsPerDay || full.Searches != MaxTermsPerDay+11 || full.SearchTerms["q0"] != 2 {
		t.Fatalf("cap: %d terms, %d searches", len(full.SearchTerms), full.Searches)
	}
}

type fakeSink struct {
	fail bool
	days map[string]*Day
}

func (s *fakeSink) AddStats(_ context.Context, id string, d *Day) error {
	if s.fail {
		return errors.New("down")
	}
	k := id + "/" + d.Date
	if s.days[k] == nil {
		s.days[k] = NewDay(d.Date)
	}
	s.days[k].Merge(d)
	return nil
}

func TestAggregator(t *testing.T) {
	sink := &fakeSink{days: map[string]*Day{}}
	a := NewAggregator(sink, nil)
	now := time.Date(2026, 10, 11, 23, 59, 0, 0, time.UTC)
	a.now = func() time.Time { return now }

	a.Add("e1", []Event{{Kind: FeatureView, FeatureID: "s1"}})
	a.Add("e2", []Event{{Kind: Route, FeatureID: "s9"}})
	now = now.Add(2 * time.Minute) // next day
	a.Add("e1", []Event{{Kind: FeatureView, FeatureID: "s1"}})

	if err := a.FlushEvent(context.Background(), "e1"); err != nil {
		t.Fatal(err)
	}
	if len(sink.days) != 2 || sink.days["e1/2026-10-11"].FeatureViews != 1 || sink.days["e1/2026-10-12"].FeatureViews != 1 {
		t.Fatalf("after FlushEvent: %v", sink.days)
	}

	// A failed flush keeps the counts for the next one.
	sink.fail = true
	a.Add("e2", []Event{{Kind: Route, FeatureID: "s9"}})
	if err := a.Flush(context.Background()); err == nil {
		t.Fatal("want error")
	}
	sink.fail = false
	if err := a.Flush(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := sink.days["e2/2026-10-11"].Routes + sink.days["e2/2026-10-12"].Routes; got != 2 {
		t.Fatalf("e2 routes = %d, want 2", got)
	}
	if err := a.Flush(context.Background()); err != nil || len(a.pending) != 0 {
		t.Fatalf("pending = %v, err = %v", a.pending, err)
	}
}

func TestLimiter(t *testing.T) {
	l := NewLimiter(10, 60) // 1 token per second
	now := time.Unix(0, 0)
	l.now = func() time.Time { return now }

	if ok, _ := l.Allow("u", 10); !ok {
		t.Fatal("burst refused")
	}
	ok, wait := l.Allow("u", 3)
	if ok || wait != 3*time.Second {
		t.Fatalf("over burst: ok=%v wait=%v", ok, wait)
	}
	if ok, _ := l.Allow("other", 5); !ok {
		t.Fatal("other user refused")
	}
	now = now.Add(3 * time.Second)
	if ok, _ := l.Allow("u", 3); !ok {
		t.Fatal("refill refused")
	}
}
