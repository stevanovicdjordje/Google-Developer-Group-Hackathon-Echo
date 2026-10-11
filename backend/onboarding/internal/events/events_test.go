package events

import (
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 10, 10, 0, 0, 0, time.UTC)

func at(h int) time.Time         { return t0.Add(time.Duration(h) * time.Hour) }
func ptr(t time.Time) *time.Time { return &t }

func TestEventStatus(t *testing.T) {
	published := ptr(at(-48))
	ev := Event{StartsAt: ptr(at(0)), EndsAt: ptr(at(8)), PublishedAt: published}
	cases := []struct {
		name string
		ev   Event
		now  time.Time
		want Status
	}{
		{"unpublished is draft even when dates passed", Event{StartsAt: ptr(at(0)), EndsAt: ptr(at(8))}, at(20), StatusDraft},
		{"published without dates is draft", Event{PublishedAt: published}, at(0), StatusDraft},
		{"before start", ev, at(-1), StatusPublished},
		{"exactly at start", ev, at(0), StatusOngoing},
		{"during", ev, at(4), StatusOngoing},
		{"exactly at end", ev, at(8), StatusFinished},
		{"after end", ev, at(30), StatusFinished},
	}
	for _, c := range cases {
		if got := c.ev.Status(c.now); got != c.want {
			t.Errorf("%s: got %s, want %s", c.name, got, c.want)
		}
	}
	if ev.Editable(at(9)) || !ev.Editable(at(4)) {
		t.Error("editable must be true until the event finishes")
	}
}

func sess(id, zone string, from, to int) Session {
	return Session{ID: id, ZoneID: zone, Title: id, StartsAt: at(from), EndsAt: at(to)}
}

func TestOverlaps(t *testing.T) {
	got := Overlaps([]Session{
		sess("a", "hall1", 0, 2),
		sess("b", "hall1", 1, 3),  // overlaps a
		sess("c", "hall1", 3, 4),  // back-to-back with b: fine
		sess("d", "hall2", 0, 2),  // other hall: fine
		sess("e", "", 0, 5),       // no hall: never conflicts
		sess("f", "hall2", 5, 10), // long session...
		sess("g", "hall2", 7, 8),  // ...fully containing g
		sess("h", "hall2", 9, 11), // overlaps f's tail, not g
	})
	want := map[string]bool{"a": true, "b": true, "f": true, "g": true, "h": true}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for id := range want {
		if !got[id] {
			t.Errorf("expected %s to conflict", id)
		}
	}
}

func TestBuildSchedule(t *testing.T) {
	loc := time.UTC
	zones := []Zone{{ID: "h1", Name: "Sala A", Kind: ZoneHall}, {ID: "h2", Name: "Sala B", Kind: ZoneHall}}
	days := BuildSchedule([]Session{
		sess("a", "h1", 0, 1),
		sess("b", "h2", 0, 1),
		sess("c", "", 2, 3),
		sess("d", "h1", 24, 25), // next day, only hall A
	}, zones, loc)
	if len(days) != 2 {
		t.Fatalf("days = %d, want 2", len(days))
	}
	d1 := days[0]
	if len(d1.Columns) != 3 || d1.Columns[2].Zone != nil {
		t.Fatalf("day 1 columns: %+v", d1.Columns)
	}
	if len(d1.Rows) != 2 || len(d1.Rows[0].Cells[0]) != 1 || len(d1.Rows[0].Cells[1]) != 1 || len(d1.Rows[1].Cells[2]) != 1 {
		t.Fatalf("day 1 rows: %+v", d1.Rows)
	}
	if len(days[1].Columns) != 1 || days[1].Columns[0].Zone.ID != "h1" {
		t.Fatalf("day 2 columns: %+v", days[1].Columns)
	}
}

func TestFilterAndGroup(t *testing.T) {
	pub := ptr(at(-100))
	items := []Summary{
		{Event: Event{ID: "d", Title: "Nacrt događaja", UpdatedAt: at(-1)}},
		{Event: Event{ID: "u", Title: "Konferencija Čačak", StartsAt: ptr(at(10)), EndsAt: ptr(at(12)), PublishedAt: pub}},
		{Event: Event{ID: "o", Title: "Meetup", StartsAt: ptr(at(-1)), EndsAt: ptr(at(2)), PublishedAt: pub}},
		{Event: Event{ID: "f", Title: "Stara konferencija", StartsAt: ptr(at(-50)), EndsAt: ptr(at(-40)), PublishedAt: pub}},
	}
	now := at(0)
	if got := Filter(items, "cacak", "", now); len(got) != 1 || got[0].ID != "u" {
		t.Fatalf("diacritics-insensitive search failed: %+v", got)
	}
	if got := Filter(items, "KONFERENCIJA", StatusFinished, now); len(got) != 1 || got[0].ID != "f" {
		t.Fatalf("search + status filter failed: %+v", got)
	}
	groups := GroupByStatus(items, now)
	order := []Status{StatusDraft, StatusPublished, StatusOngoing, StatusFinished}
	if len(groups) != 4 {
		t.Fatalf("groups = %d", len(groups))
	}
	for i, g := range groups {
		if g.Status != order[i] {
			t.Errorf("group %d = %s, want %s", i, g.Status, order[i])
		}
	}
}

func TestApplyBasics(t *testing.T) {
	loc := time.UTC
	var e Event
	if errs := ApplyBasics(&e, BasicsInput{Title: "Go dan"}, loc); errs != nil {
		t.Fatalf("a draft needs only a title: %v", errs)
	}
	errs := ApplyBasics(&e, BasicsInput{Title: "Go dan", StartsAt: "2026-10-10T10:00", EndsAt: "2026-10-10T09:00"}, loc)
	if errs["ends_at"] != "err.end_before_start" {
		t.Fatalf("got %v", errs)
	}
	errs = ApplyBasics(&e, BasicsInput{Title: "Go dan", StartsAt: "2026-10-10T10:00"}, loc)
	if errs["ends_at"] != "err.required" {
		t.Fatalf("got %v", errs)
	}
	errs = ApplyBasics(&e, BasicsInput{Title: "Go dan", Lat: "95", Lng: "20"}, loc)
	if errs["lat"] != "err.lat" {
		t.Fatalf("got %v", errs)
	}
	if errs := ApplyBasics(&e, BasicsInput{Title: "Go dan", Lat: "44,81", Lng: "20.46"}, loc); errs != nil || *e.Lat != 44.81 {
		t.Fatalf("comma decimal: %v", errs)
	}
	published := Event{PublishedAt: ptr(at(0))}
	if errs := ApplyBasics(&published, BasicsInput{Title: "Go dan"}, loc); errs["starts_at"] == "" || errs["address"] == "" {
		t.Fatalf("published event must keep dates and address: %v", errs)
	}
	if p := PublishProblems(Event{Title: "x"}, at(0)); len(p) != 2 {
		t.Fatalf("problems = %v", p)
	}
}

func TestParseZone(t *testing.T) {
	if _, errs := ParseZone(ZoneInput{Name: "Sala A", Kind: "hall", X: "10", Y: "10", W: "30", H: "20"}); errs != nil {
		t.Fatal(errs)
	}
	bad := []ZoneInput{
		{Name: "", Kind: "hall", X: "0", Y: "0", W: "1", H: "1"},
		{Name: "x", Kind: "castle", X: "0", Y: "0", W: "1", H: "1"},
		{Name: "x", Kind: "hall", X: "80", Y: "0", W: "30", H: "10"}, // sticks out
		{Name: "x", Kind: "hall", X: "0", Y: "0", W: "0", H: "10"},
		{Name: "x", Kind: "hall", X: "abc", Y: "0", W: "5", H: "10"},
	}
	for i, in := range bad {
		if _, errs := ParseZone(in); errs == nil {
			t.Errorf("case %d: expected error", i)
		}
	}
}

func TestParseSession(t *testing.T) {
	loc := time.UTC
	ev := Event{ID: "e", StartsAt: ptr(at(0)), EndsAt: ptr(at(8))}
	halls := []Zone{{ID: "h1", Kind: ZoneHall}, {ID: "b1", Kind: "booth"}}
	ok := SessionInput{Title: "Uvod", ZoneID: "h1", StartsAt: "2026-10-10T10:00", EndsAt: "2026-10-10T11:00", Tags: "AI, ai, Cloud"}
	s, errs := ParseSession(ok, ev, halls, loc)
	if errs != nil {
		t.Fatal(errs)
	}
	if len(s.Tags) != 2 || s.Tags[0] != "ai" {
		t.Fatalf("tags = %v", s.Tags)
	}
	booth := ok
	booth.ZoneID = "b1"
	if _, errs := ParseSession(booth, ev, halls, loc); errs["zone_id"] == "" {
		t.Fatal("sessions may only be placed in halls")
	}
	outside := ok
	outside.EndsAt = "2026-10-10T19:00"
	if _, errs := ParseSession(outside, ev, halls, loc); errs["starts_at"] != "err.session_outside" {
		t.Fatalf("got %v", errs)
	}
}
