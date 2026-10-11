package events

import (
	"sort"
	"strings"
	"time"
)

// Overlaps returns the IDs of sessions that overlap in time with another
// session on the same stage (hall). Sessions without a stage and breaks never
// conflict. Back-to-back sessions (one ends exactly when the next starts) are fine.
func Overlaps(sessions []Session) map[string]bool {
	out := map[string]bool{}
	byStage := map[string][]Session{}
	for _, s := range sessions {
		if s.Stage != "" && !s.IsBreak {
			k := strings.ToLower(s.Stage)
			byStage[k] = append(byStage[k], s)
		}
	}
	for _, list := range byStage {
		sort.Slice(list, func(i, j int) bool { return list[i].StartsAt.Before(list[j].StartsAt) })
		// Sweep: compare each session with the latest-ending one seen so far.
		var maxEnd time.Time
		var maxID string
		for i, s := range list {
			if i > 0 && s.StartsAt.Before(maxEnd) {
				out[s.ID] = true
				out[maxID] = true
			}
			if s.EndsAt.After(maxEnd) {
				maxEnd, maxID = s.EndsAt, s.ID
			}
		}
	}
	return out
}

// Column is one hall in the schedule grid; Name "" is "no hall".
type Column struct {
	Name string
}

// Row is one start time on a day; Cells has one entry per column.
type Row struct {
	Start time.Time
	Cells [][]ScheduledSession
}

type ScheduledSession struct {
	Session
	Conflict bool
}

type Day struct {
	Date    time.Time
	Columns []Column
	Rows    []Row
}

// BuildSchedule lays sessions out as a time table per day (in loc) with one
// column per stage, in the order of stages (then any others alphabetically).
// Stages with no sessions that day are omitted; a "no hall" column is added
// only when needed.
func BuildSchedule(sessions []Session, stages []string, loc *time.Location) []Day {
	conflicts := Overlaps(sessions)
	sorted := append([]Session(nil), sessions...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].StartsAt.Before(sorted[j].StartsAt) })

	type dayKey struct{ y, m, d int }
	var order []dayKey
	byDay := map[dayKey][]Session{}
	for _, s := range sorted {
		t := s.StartsAt.In(loc)
		k := dayKey{t.Year(), int(t.Month()), t.Day()}
		if _, ok := byDay[k]; !ok {
			order = append(order, k)
		}
		byDay[k] = append(byDay[k], s)
	}

	var days []Day
	for _, k := range order {
		list := byDay[k]
		used := map[string]string{} // lower -> display name
		needNone := false
		for _, s := range list {
			if s.Stage == "" {
				needNone = true
			} else if _, ok := used[strings.ToLower(s.Stage)]; !ok {
				used[strings.ToLower(s.Stage)] = s.Stage
			}
		}
		var cols []Column
		colIndex := map[string]int{}
		add := func(name string) {
			key := strings.ToLower(name)
			if _, done := colIndex[key]; done {
				return
			}
			if _, ok := used[key]; ok {
				colIndex[key] = len(cols)
				cols = append(cols, Column{Name: used[key]})
			}
		}
		for _, st := range stages {
			add(st)
		}
		var rest []string
		for key, name := range used {
			if _, ok := colIndex[key]; !ok {
				rest = append(rest, name)
			}
		}
		sort.Strings(rest)
		for _, st := range rest {
			add(st)
		}
		noneIdx := -1
		if needNone {
			noneIdx = len(cols)
			cols = append(cols, Column{})
		}
		var rows []Row
		for _, s := range list {
			if len(rows) == 0 || !rows[len(rows)-1].Start.Equal(s.StartsAt) {
				rows = append(rows, Row{Start: s.StartsAt, Cells: make([][]ScheduledSession, len(cols))})
			}
			idx := noneIdx
			if s.Stage != "" {
				idx = colIndex[strings.ToLower(s.Stage)]
			}
			r := &rows[len(rows)-1]
			r.Cells[idx] = append(r.Cells[idx], ScheduledSession{Session: s, Conflict: conflicts[s.ID]})
		}
		days = append(days, Day{
			Date:    time.Date(k.y, time.Month(k.m), k.d, 0, 0, 0, 0, loc),
			Columns: cols,
			Rows:    rows,
		})
	}
	return days
}
