package events

import (
	"sort"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
)

// The agenda mirrors backend/events (events/{eventId}/published/agenda), so
// sessions entered here show up in the Flutter app, Echo and Q&A, and
// sessions imported there show up here.

type Speaker struct {
	ID    string `firestore:"id"`
	Name  string `firestore:"name"`
	Title string `firestore:"title"`
}

type AgendaSession struct {
	ID          string    `firestore:"id"`
	Title       string    `firestore:"title"`
	Stage       string    `firestore:"stage"`
	Day         string    `firestore:"day"`   // YYYY-MM-DD
	Start       string    `firestore:"start"` // HH:mm
	End         string    `firestore:"end"`   // HH:mm
	Track       string    `firestore:"track"`
	Description string    `firestore:"description"`
	IsBreak     bool      `firestore:"isBreak"`
	Speakers    []Speaker `firestore:"speakers"`
}

type Agenda struct {
	Stages      []string        `firestore:"stages"`
	Speakers    []Speaker       `firestore:"speakers"`
	Sessions    []AgendaSession `firestore:"sessions"`
	PublishedAt time.Time       `firestore:"publishedAt"`
}

const (
	dayLayout   = "2006-01-02"
	clockLayout = "15:04"
	MaxTrack    = 40
	MaxStage    = 80
)

// SessionList converts the agenda to sessions with instants in loc, sorted by
// start. Items with unparsable times are skipped.
func (a Agenda) SessionList(loc *time.Location) []Session {
	var out []Session
	for _, s := range a.Sessions {
		start, err1 := time.ParseInLocation(dayLayout+" "+clockLayout, s.Day+" "+s.Start, loc)
		end, err2 := time.ParseInLocation(dayLayout+" "+clockLayout, s.Day+" "+s.End, loc)
		if err1 != nil || err2 != nil {
			continue
		}
		if !end.After(start) {
			end = start
		}
		var names []string
		for _, sp := range s.Speakers {
			names = append(names, sp.Name)
		}
		tags, _ := ParseTags(s.Track)
		out = append(out, Session{ID: s.ID, Title: s.Title, Stage: s.Stage, Speaker: strings.Join(names, ", "),
			Description: s.Description, StartsAt: start.UTC(), EndsAt: end.UTC(), Tags: tags, IsBreak: s.IsBreak})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].StartsAt.Before(out[j].StartsAt) })
	return out
}

// Add appends a session. A new stage is added to the stage list and the
// speaker is matched by name (or added) so speaker IDs stay stable.
func (a *Agenda) Add(s Session, loc *time.Location) AgendaSession {
	item := AgendaSession{
		ID:          "s-" + id.Token(5),
		Title:       s.Title,
		Stage:       s.Stage,
		Day:         s.StartsAt.In(loc).Format(dayLayout),
		Start:       s.StartsAt.In(loc).Format(clockLayout),
		End:         s.EndsAt.In(loc).Format(clockLayout),
		Track:       strings.Join(s.Tags, ", "),
		Description: s.Description,
		Speakers:    []Speaker{},
	}
	if s.Stage != "" && !containsFold(a.Stages, s.Stage) {
		a.Stages = append(a.Stages, s.Stage)
	}
	if name := strings.TrimSpace(s.Speaker); name != "" {
		var sp *Speaker
		for i := range a.Speakers {
			if strings.EqualFold(a.Speakers[i].Name, name) {
				sp = &a.Speakers[i]
			}
		}
		if sp == nil {
			a.Speakers = append(a.Speakers, Speaker{ID: "sp-" + id.Token(5), Name: name})
			sp = &a.Speakers[len(a.Speakers)-1]
		}
		item.Speakers = append(item.Speakers, *sp)
	}
	a.Sessions = append(a.Sessions, item)
	return item
}

// Remove deletes a session by ID and reports whether it existed.
func (a *Agenda) Remove(sessionID string) bool {
	for i, s := range a.Sessions {
		if s.ID == sessionID {
			a.Sessions = append(a.Sessions[:i], a.Sessions[i+1:]...)
			return true
		}
	}
	return false
}

// Normalize replaces nil slices so Firestore stores empty arrays (other
// services decode them as JSON []).
func (a *Agenda) Normalize() {
	if a.Stages == nil {
		a.Stages = []string{}
	}
	if a.Speakers == nil {
		a.Speakers = []Speaker{}
	}
	if a.Sessions == nil {
		a.Sessions = []AgendaSession{}
	}
	for i := range a.Sessions {
		if a.Sessions[i].Speakers == nil {
			a.Sessions[i].Speakers = []Speaker{}
		}
	}
}

func containsFold(list []string, v string) bool {
	for _, s := range list {
		if strings.EqualFold(s, v) {
			return true
		}
	}
	return false
}
