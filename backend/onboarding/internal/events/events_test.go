package events

import (
	"strings"
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 10, 10, 0, 0, 0, time.UTC)

func at(h int) time.Time         { return t0.Add(time.Duration(h) * time.Hour) }
func ptr(t time.Time) *time.Time { return &t }

func TestEventStatus(t *testing.T) {
	// An event whose map was published in the app counts as published.
	if (Event{StartsAt: ptr(at(0)), EndsAt: ptr(at(8)), MapVersion: 1}).Status(at(1)) != StatusOngoing {
		t.Error("map-published event must not be a draft")
	}
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

func sess(id, stage string, from, to int) Session {
	return Session{ID: id, Stage: stage, Title: id, StartsAt: at(from), EndsAt: at(to)}
}

func TestOverlaps(t *testing.T) {
	got := Overlaps([]Session{
		sess("a", "Hall1", 0, 2),
		sess("b", "hall1", 1, 3),  // overlaps a (stage names compare case-insensitively)
		sess("c", "hall1", 3, 4),  // back-to-back with b: fine
		sess("d", "hall2", 0, 2),  // other hall: fine
		sess("e", "", 0, 5),       // no hall: never conflicts
		sess("f", "hall2", 5, 10), // long session...
		sess("g", "hall2", 7, 8),  // ...fully containing g
		sess("h", "hall2", 9, 11), // overlaps f's tail, not g
		{ID: "x", Stage: "hall1", IsBreak: true, StartsAt: at(0), EndsAt: at(4)}, // breaks never conflict
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
	days := BuildSchedule([]Session{
		sess("a", "Sala A", 0, 1),
		sess("b", "Sala B", 0, 1),
		sess("c", "", 2, 3),
		sess("d", "Sala A", 24, 25), // next day, only hall A
		sess("e", "Bina", 2, 3),     // not in the stage list: added after
	}, []string{"Sala B", "Sala A"}, loc)
	if len(days) != 2 {
		t.Fatalf("days = %d, want 2", len(days))
	}
	d1 := days[0]
	names := []string{}
	for _, c := range d1.Columns {
		names = append(names, c.Name)
	}
	if got := strings.Join(names, "|"); got != "Sala B|Sala A|Bina|" {
		t.Fatalf("day 1 columns: %q", got)
	}
	if len(d1.Rows) != 2 || len(d1.Rows[0].Cells[0]) != 1 || len(d1.Rows[0].Cells[1]) != 1 || len(d1.Rows[1].Cells[3]) != 1 {
		t.Fatalf("day 1 rows: %+v", d1.Rows)
	}
	if len(days[1].Columns) != 1 || days[1].Columns[0].Name != "Sala A" {
		t.Fatalf("day 2 columns: %+v", days[1].Columns)
	}
}

func TestAgendaRoundTrip(t *testing.T) {
	loc, _ := time.LoadLocation("Europe/Belgrade")
	var a Agenda
	start := time.Date(2026, 10, 11, 10, 0, 0, 0, loc)
	a.Add(Session{Title: "Uvod", Stage: "Glavna sala", Speaker: "Ana Demić", Tags: []string{"ai", "go"},
		StartsAt: start, EndsAt: start.Add(45 * time.Minute)}, loc)
	a.Add(Session{Title: "Panel", Stage: "glavna sala", Speaker: "ana demić",
		StartsAt: start.Add(time.Hour), EndsAt: start.Add(2 * time.Hour)}, loc)
	if len(a.Stages) != 1 || len(a.Speakers) != 1 {
		t.Fatalf("stages %v speakers %v: names must be matched case-insensitively", a.Stages, a.Speakers)
	}
	it := a.Sessions[0]
	if it.Day != "2026-10-11" || it.Start != "10:00" || it.End != "10:45" || it.Track != "ai, go" {
		t.Fatalf("agenda item: %+v", it)
	}
	list := a.SessionList(loc)
	if len(list) != 2 || !list[0].StartsAt.Equal(start) || list[0].Speaker != "Ana Demić" || len(list[0].Tags) != 2 {
		t.Fatalf("session list: %+v", list)
	}
	if !a.Remove(it.ID) || a.Remove(it.ID) || len(a.Sessions) != 1 {
		t.Fatal("remove")
	}
}

func TestPlanView(t *testing.T) {
	m := Map{
		Floors: []Floor{{ID: "f2", Name: "Sprat", Order: 1, Width: 800, Height: 600}, {ID: "f1", Name: "Prizemlje", Width: 1200, Height: 800}},
		Features: []Feature{
			{ID: "r1", Type: "room", FloorID: "f1", Name: "Sala A", Geometry: Geometry{Kind: "rect", Coords: []Point{{100, 200}, {50, 100}}}},
			{ID: "s1", Type: "stand", FloorID: "f1", Name: "Štand", Geometry: Geometry{Kind: "polygon", Coords: []Point{{0, 0}, {10, 0}, {10, 10}}}},
			{ID: "p1", Type: "poi", FloorID: "f2", Name: "WC", Geometry: Geometry{Kind: "point", Coords: []Point{{5, 5}}}},
			{ID: "m1", Type: "marker", FloorID: "f1", Name: "QR", Geometry: Geometry{Kind: "point", Coords: []Point{{1, 1}}}},
		},
	}
	pv := NewPlanView("ev", m, "/x?zone=", "r1")
	if len(pv.Floors) != 2 || pv.Floors[0].Floor.ID != "f1" {
		t.Fatalf("floors not ordered: %+v", pv.Floors)
	}
	sh := pv.Floors[0].Shapes
	if len(sh) != 2 {
		t.Fatalf("markers must be hidden: %+v", sh)
	}
	if r := sh[0]; r.X != 50 || r.Y != 100 || r.W != 50 || r.H != 100 || r.CX != 75 || r.ShowLabel {
		t.Fatalf("rect normalized wrong: %+v", r)
	}
	if sh[1].Points != "0.0,0.0 10.0,0.0 10.0,10.0" || sh[1].ShowLabel {
		t.Fatalf("polygon points %q", sh[1].Points)
	}
	if pv.Floors[0].ImageURL != "/events/ev/floors/f1/image" {
		t.Fatalf("image url %q", pv.Floors[0].ImageURL)
	}
	if got := m.RoomNames(); len(got) != 1 || got[0] != "Sala A" {
		t.Fatalf("rooms %v", got)
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

func TestParseSession(t *testing.T) {
	loc := time.UTC
	ev := Event{ID: "e", StartsAt: ptr(at(0)), EndsAt: ptr(at(8))}
	ok := SessionInput{Title: "Uvod", Stage: "Sala A", StartsAt: "2026-10-10T10:00", EndsAt: "2026-10-10T11:00", Tags: "AI, ai, Cloud"}
	s, errs := ParseSession(ok, ev, loc)
	if errs != nil {
		t.Fatal(errs)
	}
	if len(s.Tags) != 2 || s.Tags[0] != "ai" || s.Stage != "Sala A" {
		t.Fatalf("got %+v", s)
	}
	newStage := ok
	newStage.StageNew = "  Nova   sala "
	if s, _ := ParseSession(newStage, ev, loc); s.Stage != "Nova sala" {
		t.Fatalf("a new hall name overrides the selection: %q", s.Stage)
	}
	outside := ok
	outside.EndsAt = "2026-10-10T19:00"
	if _, errs := ParseSession(outside, ev, loc); errs["starts_at"] != "err.session_outside" {
		t.Fatalf("got %v", errs)
	}
	overnight := ok
	overnight.StartsAt, overnight.EndsAt = "2026-10-10T23:00", "2026-10-11T01:00"
	if _, errs := ParseSession(overnight, Event{}, loc); errs["ends_at"] != "err.session_midnight" {
		t.Fatalf("got %v", errs)
	}
	longTags := ok
	longTags.Tags = "jedan dugacak tag, drugi dugacak tag, treci"
	if _, errs := ParseSession(longTags, ev, loc); errs["tags"] == "" {
		t.Fatal("track must fit in 40 characters")
	}
}
