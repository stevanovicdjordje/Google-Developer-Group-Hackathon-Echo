// Package agenda holds the event draft / agenda model, its validation and
// normalisation, and the review issues shown to the organizer.
// Shapes follow contracts/events/openapi.yaml.
package agenda

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// Field limits (contract maxLength / maxItems).
const (
	MaxName        = 120
	MaxAddress     = 200
	MaxStage       = 80
	MaxStages      = 30
	MaxSpeakers    = 200
	MaxSessions    = 300
	MaxTitle       = 160
	MaxTrack       = 40
	MaxDescription = 600
	MaxSpeakerName = 80
	MaxSpeakerRole = 120
	MaxPerSession  = 6
)

// Speaker is a person on stage.
type Speaker struct {
	ID    string `json:"id" firestore:"id"`
	Name  string `json:"name" firestore:"name"`
	Title string `json:"title" firestore:"title"`
}

// Session is one agenda slot. Speakers are inlined for clients.
type Session struct {
	ID          string    `json:"id" firestore:"id"`
	Title       string    `json:"title" firestore:"title"`
	Stage       string    `json:"stage" firestore:"stage"`
	Day         string    `json:"day" firestore:"day"`
	Start       string    `json:"start" firestore:"start"`
	End         string    `json:"end" firestore:"end"`
	Track       string    `json:"track" firestore:"track"`
	Description string    `json:"description" firestore:"description"`
	IsBreak     bool      `json:"isBreak" firestore:"isBreak"`
	Speakers    []Speaker `json:"speakers" firestore:"speakers"`
}

// Fields is what a draft and a published agenda have in common.
type Fields struct {
	Name      string    `json:"name" firestore:"name"`
	StartDate string    `json:"startDate" firestore:"startDate"`
	EndDate   string    `json:"endDate" firestore:"endDate"`
	Address   string    `json:"address" firestore:"address"`
	Stages    []string  `json:"stages" firestore:"stages"`
	Speakers  []Speaker `json:"speakers" firestore:"speakers"`
	Sessions  []Session `json:"sessions" firestore:"sessions"`
}

// Issue is something the organizer should check; it never blocks publishing.
type Issue struct {
	Severity  string `json:"severity" firestore:"severity"`
	SessionID string `json:"sessionId,omitempty" firestore:"sessionId"`
	Field     string `json:"field" firestore:"field"`
	Message   string `json:"message" firestore:"message"`
}

// FieldError is one validation problem (contract FieldError).
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// ValidationError lists every problem found in an input.
type ValidationError []FieldError

func (v ValidationError) Error() string { return fmt.Sprintf("%d invalid fields", len(v)) }

var (
	timeRe = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)
	idRe   = regexp.MustCompile(`^[A-Za-z0-9_-]{1,40}$`)
)

// ValidDate reports whether s is a real YYYY-MM-DD date.
func ValidDate(s string) bool {
	_, err := time.Parse(time.DateOnly, s)
	return err == nil
}

// ValidTime reports whether s is HH:mm (24 h).
func ValidTime(s string) bool { return timeRe.MatchString(s) }

// Validate checks organizer input strictly (updateDraft). Model output goes
// through Sanitize instead, which repairs what it can.
func Validate(f *Fields) error {
	var errs ValidationError
	add := func(field, msg string) { errs = append(errs, FieldError{field, msg}) }
	text := func(field, s string, required bool, max int) {
		switch {
		case required && strings.TrimSpace(s) == "":
			add(field, "is required")
		case utf8.RuneCountInString(s) > max:
			add(field, fmt.Sprintf("must be at most %d characters", max))
		}
	}
	text("name", f.Name, true, MaxName)
	text("address", f.Address, false, MaxAddress)
	if !ValidDate(f.StartDate) {
		add("startDate", "must be YYYY-MM-DD")
	}
	if !ValidDate(f.EndDate) {
		add("endDate", "must be YYYY-MM-DD")
	} else if ValidDate(f.StartDate) && f.EndDate < f.StartDate {
		add("endDate", "must not be before startDate")
	}
	if len(f.Stages) > MaxStages {
		add("stages", fmt.Sprintf("at most %d", MaxStages))
	}
	for i, s := range f.Stages {
		text(fmt.Sprintf("stages[%d]", i), s, true, MaxStage)
	}
	if len(f.Speakers) > MaxSpeakers {
		add("speakers", fmt.Sprintf("at most %d", MaxSpeakers))
	}
	for i, sp := range f.Speakers {
		p := fmt.Sprintf("speakers[%d]", i)
		if !idRe.MatchString(sp.ID) {
			add(p+".id", "must be 1-40 letters, digits, - or _")
		}
		text(p+".name", sp.Name, true, MaxSpeakerName)
		text(p+".title", sp.Title, false, MaxSpeakerRole)
	}
	if len(f.Sessions) > MaxSessions {
		add("sessions", fmt.Sprintf("at most %d", MaxSessions))
	}
	seen := map[string]bool{}
	for i, s := range f.Sessions {
		p := fmt.Sprintf("sessions[%d]", i)
		if !idRe.MatchString(s.ID) {
			add(p+".id", "must be 1-40 letters, digits, - or _")
		} else if seen[s.ID] {
			add(p+".id", "is a duplicate")
		}
		seen[s.ID] = true
		text(p+".title", s.Title, true, MaxTitle)
		text(p+".stage", s.Stage, false, MaxStage)
		text(p+".track", s.Track, false, MaxTrack)
		text(p+".description", s.Description, false, MaxDescription)
		if !ValidDate(s.Day) {
			add(p+".day", "must be YYYY-MM-DD")
		}
		if !ValidTime(s.Start) {
			add(p+".start", "must be HH:mm")
		}
		if !ValidTime(s.End) {
			add(p+".end", "must be HH:mm")
		}
		if len(s.Speakers) > MaxPerSession {
			add(p+".speakers", fmt.Sprintf("at most %d", MaxPerSession))
		}
		for j, sp := range s.Speakers {
			text(fmt.Sprintf("%s.speakers[%d].name", p, j), sp.Name, true, MaxSpeakerName)
		}
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

// Clean makes s a single trimmed line without control characters, cut to max runes.
func Clean(s string, max int) string {
	s = strings.Map(func(r rune) rune {
		switch {
		case r == '\n' || r == '\r' || r == '\t':
			return ' '
		case unicode.IsControl(r):
			return -1
		}
		return r
	}, s)
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > max {
		s = strings.TrimSpace(string(r[:max]))
	}
	return s
}

// NormalizeTime turns "9:00", "09.00", "9h", "0900" into "09:00"; "" if it can't.
func NormalizeTime(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	s = strings.TrimSuffix(strings.TrimSuffix(s, "h"), "h")
	s = strings.NewReplacer(".", ":", "h", ":").Replace(s)
	if !strings.Contains(s, ":") && len(s) == 4 {
		s = s[:2] + ":" + s[2:]
	}
	if !strings.Contains(s, ":") && len(s) > 0 && len(s) <= 2 {
		s += ":00"
	}
	var h, m int
	if _, err := fmt.Sscanf(s, "%d:%d", &h, &m); err != nil || h < 0 || h > 23 || m < 0 || m > 59 {
		return ""
	}
	return fmt.Sprintf("%02d:%02d", h, m)
}

// Sanitize repairs untrusted (model or spreadsheet) output into valid Fields:
// trims and caps text, normalises times, assigns speaker and session IDs,
// links session speakers to the speaker list by name, drops sessions without
// a title, and fills dates from the sessions when missing.
func Sanitize(f *Fields) {
	f.Name = Clean(f.Name, MaxName)
	f.Address = Clean(f.Address, MaxAddress)

	// Speakers: unique by name, IDs sp1, sp2… in order.
	byName := map[string]Speaker{}
	var speakers []Speaker
	addSpeaker := func(name, title string) Speaker {
		name, title = Clean(name, MaxSpeakerName), Clean(title, MaxSpeakerRole)
		key := strings.ToLower(name)
		if sp, ok := byName[key]; ok {
			if sp.Title == "" && title != "" {
				sp.Title = title
				byName[key] = sp
				for i := range speakers {
					if speakers[i].ID == sp.ID {
						speakers[i].Title = title
					}
				}
			}
			return byName[key]
		}
		sp := Speaker{ID: fmt.Sprintf("sp%d", len(speakers)+1), Name: name, Title: title}
		byName[key] = sp
		speakers = append(speakers, sp)
		return sp
	}
	for _, sp := range f.Speakers {
		if Clean(sp.Name, MaxSpeakerName) != "" && len(speakers) < MaxSpeakers {
			addSpeaker(sp.Name, sp.Title)
		}
	}

	stageSet := map[string]bool{}
	var stages []string
	addStage := func(s string) string {
		s = Clean(s, MaxStage)
		if s != "" && !stageSet[strings.ToLower(s)] && len(stages) < MaxStages {
			stageSet[strings.ToLower(s)] = true
			stages = append(stages, s)
		}
		return s
	}
	for _, s := range f.Stages {
		addStage(s)
	}

	var sessions []Session
	for _, s := range f.Sessions {
		title := Clean(s.Title, MaxTitle)
		if title == "" || len(sessions) >= MaxSessions {
			continue
		}
		out := Session{
			Title: title, Stage: addStage(s.Stage), Day: strings.TrimSpace(s.Day),
			Start: NormalizeTime(s.Start), End: NormalizeTime(s.End),
			Track: Clean(s.Track, MaxTrack), Description: Clean(s.Description, MaxDescription),
			IsBreak: s.IsBreak, Speakers: []Speaker{},
		}
		if !ValidDate(out.Day) {
			out.Day = ""
		}
		for _, sp := range s.Speakers {
			if Clean(sp.Name, MaxSpeakerName) == "" || len(out.Speakers) >= MaxPerSession || len(speakers) >= MaxSpeakers {
				continue
			}
			out.Speakers = append(out.Speakers, addSpeaker(sp.Name, sp.Title))
		}
		if out.IsBreak {
			out.Speakers = []Speaker{}
		}
		sessions = append(sessions, out)
	}

	// Dates: from the input if valid, else from the sessions' days.
	var days []string
	for _, s := range sessions {
		if s.Day != "" {
			days = append(days, s.Day)
		}
	}
	slices.Sort(days)
	if !ValidDate(f.StartDate) {
		f.StartDate = ""
		if len(days) > 0 {
			f.StartDate = days[0]
		}
	}
	if !ValidDate(f.EndDate) || (f.StartDate != "" && f.EndDate < f.StartDate) {
		f.EndDate = f.StartDate
		if len(days) > 0 && days[len(days)-1] > f.EndDate {
			f.EndDate = days[len(days)-1]
		}
	}
	for i := range sessions {
		if sessions[i].Day == "" {
			sessions[i].Day = f.StartDate
		}
	}
	SortSessions(sessions)
	for i := range sessions {
		sessions[i].ID = fmt.Sprintf("d%d", i+1)
	}
	if speakers == nil {
		speakers = []Speaker{}
	}
	if stages == nil {
		stages = []string{}
	}
	if sessions == nil {
		sessions = []Session{}
	}
	f.Speakers, f.Stages, f.Sessions = speakers, stages, sessions
}

// SortSessions orders by day, start, stage, title.
func SortSessions(s []Session) {
	slices.SortStableFunc(s, func(a, b Session) int {
		return strings.Compare(a.Day+a.Start+a.Stage+a.Title, b.Day+b.Start+b.Stage+b.Title)
	})
}

// LinkSpeakers replaces each session speaker by the matching entry of
// f.Speakers (by id, else by name), adding unknown ones to the list.
func LinkSpeakers(f *Fields) {
	byID := map[string]Speaker{}
	byName := map[string]Speaker{}
	for _, sp := range f.Speakers {
		byID[sp.ID] = sp
		byName[strings.ToLower(sp.Name)] = sp
	}
	for i := range f.Sessions {
		for j, sp := range f.Sessions[i].Speakers {
			if known, ok := byID[sp.ID]; ok && sp.ID != "" {
				f.Sessions[i].Speakers[j] = known
			} else if known, ok := byName[strings.ToLower(sp.Name)]; ok {
				f.Sessions[i].Speakers[j] = known
			} else {
				sp.ID = fmt.Sprintf("sp%d", len(f.Speakers)+1)
				for byID[sp.ID].ID != "" {
					sp.ID += "x"
				}
				f.Speakers = append(f.Speakers, sp)
				byID[sp.ID], byName[strings.ToLower(sp.Name)] = sp, sp
				f.Sessions[i].Speakers[j] = sp
			}
		}
		if f.Sessions[i].Speakers == nil {
			f.Sessions[i].Speakers = []Speaker{}
		}
	}
}

// Issues lists what the organizer should check in the review.
func Issues(f *Fields) []Issue {
	out := []Issue{}
	warn := func(sessionID, field, msg string) {
		out = append(out, Issue{Severity: "warning", SessionID: sessionID, Field: field, Message: msg})
	}
	if f.StartDate == "" {
		warn("", "startDate", "No event date found.")
	}
	if f.Address == "" {
		warn("", "address", "No venue address found.")
	}
	type slot struct {
		i          int
		start, end string
	}
	byStage := map[string][]slot{}
	for i, s := range f.Sessions {
		p := fmt.Sprintf("sessions[%d]", i)
		switch {
		case s.Start == "":
			warn(s.ID, p+".start", "No start time found for this session.")
		case s.End == "":
			warn(s.ID, p+".end", "No end time found for this session.")
		case s.End <= s.Start:
			warn(s.ID, p+".end", "Ends before it starts.")
		}
		if s.Stage == "" {
			warn(s.ID, p+".stage", "No stage found for this session.")
		}
		if !s.IsBreak && len(s.Speakers) == 0 {
			warn(s.ID, p+".speakers", "No speaker found for this session.")
		}
		if s.Day != "" && f.StartDate != "" && (s.Day < f.StartDate || s.Day > f.EndDate) {
			warn(s.ID, p+".day", "Outside the event dates.")
		}
		if s.Stage != "" && s.Start != "" && s.End > s.Start {
			k := s.Day + "|" + strings.ToLower(s.Stage)
			for _, o := range byStage[k] {
				if s.Start < o.end && o.start < s.End {
					warn(s.ID, p+".start", fmt.Sprintf("Overlaps %q on the same stage.", f.Sessions[o.i].Title))
					break
				}
			}
			byStage[k] = append(byStage[k], slot{i, s.Start, s.End})
		}
	}
	return out
}

// Agenda is the published agenda of an event.
type Agenda struct {
	EventID     string    `json:"eventId" firestore:"-"`
	Stages      []string  `json:"stages" firestore:"stages"`
	Speakers    []Speaker `json:"speakers" firestore:"speakers"`
	Sessions    []Session `json:"sessions" firestore:"sessions"`
	PublishedAt time.Time `json:"publishedAt" firestore:"publishedAt"`
}

// KeepIDs gives each session the ID of a previously published session with
// the same title (case-insensitive), so Echo and Q&A links survive a
// re-publish. The others get fresh IDs from newID that collide with nothing
// published before.
func KeepIDs(sessions []Session, previous []Session, newID func() string) {
	key := func(t string) string { return strings.ToLower(strings.TrimSpace(t)) }
	prev := map[string]string{}
	used := map[string]bool{}
	for _, p := range previous {
		if _, dup := prev[key(p.Title)]; !dup {
			prev[key(p.Title)] = p.ID
		}
		used[p.ID] = true
	}
	taken := map[string]bool{}
	for i := range sessions {
		sessions[i].ID = ""
		if id, ok := prev[key(sessions[i].Title)]; ok && !taken[id] {
			sessions[i].ID = id
			taken[id] = true
		}
	}
	for i := range sessions {
		for sessions[i].ID == "" {
			if id := newID(); !used[id] {
				sessions[i].ID = id
				used[id] = true
			}
		}
	}
}
