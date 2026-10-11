package events

import (
	"sort"
	"time"
)

// Overlaps returns the IDs of sessions that overlap in time with another
// session in the same hall. Sessions without a hall never conflict.
// Back-to-back sessions (one ends exactly when the next starts) are fine.
func Overlaps(sessions []Session) map[string]bool {
	out := map[string]bool{}
	byZone := map[string][]Session{}
	for _, s := range sessions {
		if s.ZoneID != "" {
			byZone[s.ZoneID] = append(byZone[s.ZoneID], s)
		}
	}
	for _, list := range byZone {
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

// Column is one hall in the schedule grid; Zone is nil for "no hall".
type Column struct {
	Zone *Zone
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
// column per hall. Halls with no sessions that day are omitted; a "no hall"
// column is added only when needed.
func BuildSchedule(sessions []Session, zones []Zone, loc *time.Location) []Day {
	conflicts := Overlaps(sessions)
	zoneByID := map[string]*Zone{}
	for i := range zones {
		zoneByID[zones[i].ID] = &zones[i]
	}
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
		// Columns: halls in zone order, then "no hall" (also for unknown zone IDs).
		used := map[string]bool{}
		needNone := false
		for _, s := range list {
			if zoneByID[s.ZoneID] != nil {
				used[s.ZoneID] = true
			} else {
				needNone = true
			}
		}
		var cols []Column
		colIndex := map[string]int{}
		for i := range zones {
			if used[zones[i].ID] {
				colIndex[zones[i].ID] = len(cols)
				cols = append(cols, Column{Zone: &zones[i]})
			}
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
			idx, ok := colIndex[s.ZoneID]
			if !ok {
				idx = noneIdx
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
