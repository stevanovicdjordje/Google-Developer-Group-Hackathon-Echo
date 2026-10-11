package extract

import (
	"regexp"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

// OfflineModel is the model name reported for the table reader.
const OfflineModel = "offline"

// column roles recognised in a header row (English and Serbian).
var headerWords = map[string][]string{
	"title":       {"title", "session", "talk", "naslov", "predavanje", "tema", "name of talk"},
	"stage":       {"stage", "room", "hall", "sala", "bina", "location", "lokacija", "prostorija"},
	"start":       {"start", "from", "begins", "početak", "pocetak", "od"},
	"end":         {"end", "to", "until", "kraj", "do"},
	"time":        {"time", "vreme", "slot", "termin"},
	"day":         {"day", "date", "datum", "dan"},
	"speakers":    {"speaker", "speakers", "predavač", "predavac", "predavači", "govornik", "presenter", "host"},
	"speakerRole": {"company", "role", "kompanija", "firma", "pozicija", "affiliation"},
	"track":       {"track", "topic", "kategorija", "oblast"},
	"description": {"description", "abstract", "opis", "sažetak", "sazetak", "about"},
}

var breakWords = []string{"lunch", "coffee", "registration", "break", "pauza", "ručak", "rucak", "kafa", "registracija", "doručak", "dorucak"}

// FromTables reads sessions from tables that have a recognisable header row
// (at least a title and a time column). It returns ok=false if none does.
func FromTables(tables []Table, year int) (agenda.Fields, bool) {
	var f agenda.Fields
	found := false
	for _, t := range tables {
		hdr, cols := findHeader(t.Rows)
		if hdr < 0 {
			continue
		}
		for _, row := range t.Rows[hdr+1:] {
			get := func(role string) string {
				if i, ok := cols[role]; ok && i < len(row) {
					return row[i]
				}
				return ""
			}
			s := agenda.Session{
				Title: get("title"), Stage: get("stage"), Track: get("track"), Description: get("description"),
				Start: get("start"), End: get("end"), Day: parseDay(get("day"), year),
			}
			if tm := get("time"); tm != "" && (s.Start == "" || s.End == "") {
				a, b := splitRange(tm)
				s.Start, s.End = first(s.Start, a), first(s.End, b)
			}
			if a, b := splitRange(s.Start); b != "" && s.End == "" {
				s.Start, s.End = a, b
			}
			if s.Title == "" {
				continue
			}
			for _, name := range splitNames(get("speakers")) {
				n, role := splitRole(name)
				if role == "" && len(splitNames(get("speakers"))) == 1 {
					role = get("speakerRole")
				}
				s.Speakers = append(s.Speakers, agenda.Speaker{Name: n, Title: role})
			}
			s.IsBreak = len(s.Speakers) == 0 && isBreak(s.Title)
			f.Sessions = append(f.Sessions, s)
			found = true
		}
	}
	return f, found
}

func first(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func findHeader(rows [][]string) (int, map[string]int) {
	for i, row := range rows {
		if i > 15 {
			break
		}
		cols := map[string]int{}
		for j, cell := range row {
			c := strings.ToLower(strings.Trim(cell, " :*#"))
			for role, words := range headerWords {
				if _, taken := cols[role]; taken {
					continue
				}
				for _, w := range words {
					if c == w || strings.HasPrefix(c, w+" ") || strings.HasSuffix(c, " "+w) {
						cols[role] = j
						break
					}
				}
			}
		}
		_, title := cols["title"]
		_, start := cols["start"]
		_, tm := cols["time"]
		if title && (start || tm) {
			return i, cols
		}
	}
	return -1, nil
}

var rangeRe = regexp.MustCompile(`(\d{1,2}[:.h]?\d{0,2})\s*(?:-|–|—|to|do)\s*(\d{1,2}[:.h]?\d{0,2})`)

// splitRange splits "10:00–10:45" into its two times; one time stays in a.
func splitRange(s string) (a, b string) {
	if m := rangeRe.FindStringSubmatch(s); m != nil {
		return m[1], m[2]
	}
	return s, ""
}

var nameSplit = regexp.MustCompile(`\s*(?:,|;|&|/|\band\b|\bi\b|\+)\s*`)

// splitNames splits "Sara Đorđević & Petar Vuković" into names. A role in
// parentheses stays with its name.
func splitNames(s string) []string {
	var out []string
	depth, last := 0, 0
	for i, r := range s {
		switch r {
		case '(':
			depth++
		case ')':
			depth--
		}
		if depth == 0 && (r == ';' || r == '&' || r == '+' || r == '/') {
			out = append(out, s[last:i])
			last = i + 1
		}
	}
	out = append(out, s[last:])
	var names []string
	for _, part := range out {
		if strings.Contains(part, "(") {
			if p := strings.TrimSpace(part); p != "" {
				names = append(names, p)
			}
			continue
		}
		for _, n := range nameSplit.Split(part, -1) {
			if n = strings.TrimSpace(n); n != "" {
				names = append(names, n)
			}
		}
	}
	return names
}

// splitRole splits "Mara Ilić (ML Engineer, Lumen Labs)" or
// "Mara Ilić — ML Engineer" into name and role.
func splitRole(s string) (name, role string) {
	if i := strings.Index(s, "("); i > 0 && strings.HasSuffix(s, ")") {
		return strings.TrimSpace(s[:i]), strings.TrimSpace(s[i+1 : len(s)-1])
	}
	for _, sep := range []string{" — ", " – ", " - "} {
		if a, b, ok := strings.Cut(s, sep); ok {
			return strings.TrimSpace(a), strings.TrimSpace(b)
		}
	}
	return strings.TrimSpace(s), ""
}

func isBreak(title string) bool {
	t := strings.ToLower(title)
	for _, w := range breakWords {
		if strings.Contains(t, w) {
			return true
		}
	}
	return false
}

// parseDay reads "2026-10-11", "11.10.2026.", "11/10/2026" or "11.10." (with
// year); "" if it can't.
func parseDay(s string, year int) string {
	s = strings.TrimSuffix(strings.TrimSpace(s), ".")
	if s == "" {
		return ""
	}
	for _, layout := range []string{time.DateOnly, "2.1.2006", "02.01.2006", "2/1/2006", "02/01/2006", "2. 1. 2006"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.Format(time.DateOnly)
		}
	}
	for _, layout := range []string{"2.1", "02.01", "2/1"} {
		if t, err := time.Parse(layout, s); err == nil {
			return time.Date(year, t.Month(), t.Day(), 0, 0, 0, 0, time.UTC).Format(time.DateOnly)
		}
	}
	return ""
}
