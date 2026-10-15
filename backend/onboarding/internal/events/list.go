package events

import (
	"sort"
	"strings"
	"time"
)

// Group is one section of the organizer's event list.
type Group struct {
	Status Status
	Items  []Summary
}

var foldReplacer = strings.NewReplacer("č", "c", "ć", "c", "š", "s", "ž", "z", "đ", "dj")

// fold lowercases and strips Serbian diacritics so "cacak" matches "Čačak".
func fold(s string) string { return foldReplacer.Replace(strings.ToLower(s)) }

// Filter keeps events whose title contains query (case and diacritics
// insensitive) and, when status is non-empty, that have that status.
func Filter(items []Summary, query string, status Status, now time.Time) []Summary {
	q := fold(strings.TrimSpace(query))
	var out []Summary
	for _, it := range items {
		if q != "" && !strings.Contains(fold(it.Title), q) {
			continue
		}
		if status != "" && it.Status(now) != status {
			continue
		}
		out = append(out, it)
	}
	return out
}

// GroupByStatus splits events into drafts, upcoming, ongoing and past, in that
// order. Drafts are newest-edited first, upcoming/ongoing soonest first, past
// most recent first. Empty groups are omitted.
func GroupByStatus(items []Summary, now time.Time) []Group {
	byStatus := map[Status][]Summary{}
	for _, it := range items {
		s := it.Status(now)
		byStatus[s] = append(byStatus[s], it)
	}
	var out []Group
	for _, s := range Statuses {
		list := byStatus[s]
		if len(list) == 0 {
			continue
		}
		sort.SliceStable(list, func(i, j int) bool {
			a, b := list[i], list[j]
			switch s {
			case StatusDraft:
				return a.UpdatedAt.After(b.UpdatedAt)
			case StatusFinished:
				return a.EndsAt.After(*b.EndsAt)
			default:
				return a.StartsAt.Before(*b.StartsAt)
			}
		})
		out = append(out, Group{Status: s, Items: list})
	}
	return out
}
