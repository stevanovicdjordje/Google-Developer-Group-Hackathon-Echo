package agenda

import (
	"fmt"
	"strings"
	"testing"
)

func TestNormalizeTime(t *testing.T) {
	for in, want := range map[string]string{"9:00": "09:00", "09.30": "09:30", "1015": "10:15", "9": "09:00", "9h": "09:00", "25:00": "", "": "", "noon": ""} {
		if got := NormalizeTime(in); got != want {
			t.Errorf("%q → %q, want %q", in, got, want)
		}
	}
}

func TestSanitizeCapsAndLinks(t *testing.T) {
	f := Fields{
		Name: "  DevFest\n2026 ", StartDate: "bad",
		Speakers: []Speaker{{Name: "Mara Ilić", Title: "ML Engineer"}},
		Sessions: []Session{
			{Title: strings.Repeat("x", 500), Day: "2026-10-12", Start: "14:00", End: "15:00"},
			{Title: "Keynote", Stage: "Glavna sala", Day: "2026-10-11", Start: "10:00", End: "10:45",
				Speakers: []Speaker{{Name: "mara ilić"}, {Name: "New Person", Title: "CTO"}}},
		},
	}
	Sanitize(&f)
	if f.Name != "DevFest 2026" || f.StartDate != "2026-10-11" || f.EndDate != "2026-10-12" {
		t.Fatalf("%q %s %s", f.Name, f.StartDate, f.EndDate)
	}
	if f.Sessions[0].Title != "Keynote" || len([]rune(f.Sessions[1].Title)) != MaxTitle {
		t.Fatal("sort or cap")
	}
	if len(f.Speakers) != 2 || f.Sessions[0].Speakers[0].ID != "sp1" || f.Sessions[0].Speakers[1].Title != "CTO" {
		t.Fatalf("speakers %+v / %+v", f.Speakers, f.Sessions[0].Speakers)
	}
	if len(f.Stages) != 1 || f.Stages[0] != "Glavna sala" {
		t.Fatal(f.Stages)
	}
	if err := Validate(&f); err != nil {
		t.Fatalf("sanitized fields don't validate: %v", err)
	}
}

func TestIssuesOverlap(t *testing.T) {
	f := Fields{StartDate: "2026-10-11", EndDate: "2026-10-11", Address: "x", Sessions: []Session{
		{ID: "a", Title: "A", Stage: "S", Day: "2026-10-11", Start: "10:00", End: "11:00", Speakers: []Speaker{{Name: "p"}}},
		{ID: "b", Title: "B", Stage: "s", Day: "2026-10-11", Start: "10:30", End: "10:20", Speakers: []Speaker{{Name: "p"}}},
		{ID: "c", Title: "C", Stage: "S", Day: "2026-10-11", Start: "10:59", End: "11:30", Speakers: []Speaker{{Name: "p"}}},
	}}
	got := fmt.Sprint(Issues(&f))
	if !strings.Contains(got, "Ends before it starts") || !strings.Contains(got, `Overlaps "A"`) {
		t.Fatal(got)
	}
}

func TestKeepIDs(t *testing.T) {
	prev := []Session{{ID: "s1", Title: "Keynote"}, {ID: "s2", Title: "Gone"}}
	n := 0
	next := func() string { n++; return []string{"s2", "s9", "s10"}[n-1] }
	cur := []Session{{Title: "keynote "}, {Title: "New"}, {Title: "Keynote"}}
	KeepIDs(cur, prev, next)
	if cur[0].ID != "s1" || cur[1].ID != "s9" || cur[2].ID != "s10" {
		t.Fatalf("%+v", cur)
	}
}
