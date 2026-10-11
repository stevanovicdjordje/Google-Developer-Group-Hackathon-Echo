package events

import (
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

// Errors maps a form field to an i18n key.
type Errors map[string]string

func (e Errors) add(field, key string) {
	if _, ok := e[field]; !ok {
		e[field] = key
	}
}

const dtLayout = "2006-01-02T15:04"

// ParseLocal parses an <input type="datetime-local"> value in loc.
func ParseLocal(s string, loc *time.Location) (time.Time, bool) {
	t, err := time.ParseInLocation(dtLayout, strings.TrimSpace(s), loc)
	if err != nil {
		return time.Time{}, false
	}
	return t.UTC(), true
}

func parseFloat(s string) (float64, bool) {
	f, err := strconv.ParseFloat(strings.Replace(strings.TrimSpace(s), ",", ".", 1), 64)
	return f, err == nil
}

func runeLen(s string) int { return utf8.RuneCountInString(s) }

// BasicsInput is the raw "basic info" wizard form.
type BasicsInput struct {
	Title, Description, StartsAt, EndsAt, Address, Lat, Lng string
}

// ApplyBasics validates the form and, when valid, copies it onto e.
// A draft may be saved without dates or address; a published event may not
// lose them.
func ApplyBasics(e *Event, in BasicsInput, loc *time.Location) Errors {
	errs := Errors{}
	title := strings.TrimSpace(in.Title)
	desc := strings.TrimSpace(in.Description)
	addr := strings.TrimSpace(in.Address)
	if n := runeLen(title); n < 3 || n > 150 {
		errs.add("title", "err.event_title")
	}
	if runeLen(desc) > 5000 {
		errs.add("description", "err.too_long")
	}
	if runeLen(addr) > 300 {
		errs.add("address", "err.too_long")
	}

	var starts, ends *time.Time
	hasStart, hasEnd := strings.TrimSpace(in.StartsAt) != "", strings.TrimSpace(in.EndsAt) != ""
	if hasStart {
		if t, ok := ParseLocal(in.StartsAt, loc); ok {
			starts = &t
		} else {
			errs.add("starts_at", "err.datetime")
		}
	}
	if hasEnd {
		if t, ok := ParseLocal(in.EndsAt, loc); ok {
			ends = &t
		} else {
			errs.add("ends_at", "err.datetime")
		}
	}
	if hasStart != hasEnd {
		if !hasStart {
			errs.add("starts_at", "err.required")
		} else {
			errs.add("ends_at", "err.required")
		}
	}
	if starts != nil && ends != nil && !ends.After(*starts) {
		errs.add("ends_at", "err.end_before_start")
	}

	var lat, lng *float64
	hasLat, hasLng := strings.TrimSpace(in.Lat) != "", strings.TrimSpace(in.Lng) != ""
	if hasLat || hasLng {
		la, ok1 := parseFloat(in.Lat)
		ln, ok2 := parseFloat(in.Lng)
		switch {
		case !ok1 || la < -90 || la > 90:
			errs.add("lat", "err.lat")
		case !ok2 || ln < -180 || ln > 180:
			errs.add("lng", "err.lng")
		default:
			lat, lng = &la, &ln
		}
	}

	if e.PublishedAt != nil {
		if starts == nil || ends == nil {
			errs.add("starts_at", "err.publish_dates")
		}
		if addr == "" {
			errs.add("address", "err.publish_address")
		}
	}
	if len(errs) > 0 {
		return errs
	}
	e.Title, e.Description, e.Address = title, desc, addr
	e.StartsAt, e.EndsAt, e.Lat, e.Lng = starts, ends, lat, lng
	return nil
}

// PublishProblems lists i18n keys that block publishing (empty = ready).
func PublishProblems(e Event, now time.Time) []string {
	var out []string
	if e.StartsAt == nil || e.EndsAt == nil {
		out = append(out, "err.publish_dates")
	} else if !e.EndsAt.After(now) {
		out = append(out, "err.publish_past")
	}
	if strings.TrimSpace(e.Address) == "" {
		out = append(out, "err.publish_address")
	}
	return out
}

type ZoneInput struct {
	Name, Kind, X, Y, W, H string
}

// ParseZone validates a zone; coordinates are percentages of the plan image
// and the rectangle must stay inside it.
func ParseZone(in ZoneInput) (Zone, Errors) {
	errs := Errors{}
	z := Zone{Name: strings.TrimSpace(in.Name), Kind: ZoneKind(in.Kind)}
	if n := runeLen(z.Name); n < 1 || n > 80 {
		errs.add("name", "err.zone_name")
	}
	if !z.Kind.Valid() {
		errs.add("kind", "err.zone_kind")
	}
	vals := []*float64{&z.X, &z.Y, &z.W, &z.H}
	for i, raw := range []string{in.X, in.Y, in.W, in.H} {
		f, ok := parseFloat(raw)
		if !ok || f < 0 || f > 100 {
			errs.add("geometry", "err.zone_geometry")
			continue
		}
		*vals[i] = f
	}
	if _, bad := errs["geometry"]; !bad {
		if z.W <= 0 || z.H <= 0 || z.X >= 100 || z.Y >= 100 || z.X+z.W > 100 || z.Y+z.H > 100 {
			errs.add("geometry", "err.zone_geometry")
		}
	}
	if len(errs) > 0 {
		return Zone{}, errs
	}
	return z, nil
}

type SessionInput struct {
	Title, Description, Speaker, ZoneID, StartsAt, EndsAt, Tags string
}

// ParseTags splits a comma-separated tag list (lowercased, deduplicated).
func ParseTags(raw string) ([]string, bool) {
	seen := map[string]bool{}
	var out []string
	for _, p := range strings.Split(raw, ",") {
		t := strings.ToLower(strings.Join(strings.Fields(p), " "))
		if t == "" || seen[t] {
			continue
		}
		if runeLen(t) > 30 {
			return nil, false
		}
		seen[t] = true
		out = append(out, t)
	}
	return out, len(out) <= 8
}

// ParseSession validates a session. The hall must be one of halls (zones of
// kind "hall" of the same event); the time must fall inside the event.
func ParseSession(in SessionInput, ev Event, halls []Zone, loc *time.Location) (Session, Errors) {
	errs := Errors{}
	s := Session{
		EventID:     ev.ID,
		Title:       strings.TrimSpace(in.Title),
		Description: strings.TrimSpace(in.Description),
		Speaker:     strings.TrimSpace(in.Speaker),
	}
	if n := runeLen(s.Title); n < 1 || n > 150 {
		errs.add("title", "err.session_title")
	}
	if runeLen(s.Speaker) > 120 || runeLen(s.Description) > 2000 {
		errs.add("description", "err.too_long")
	}
	if in.ZoneID != "" {
		found := false
		for _, h := range halls {
			if h.ID == in.ZoneID && h.Kind == ZoneHall {
				found = true
			}
		}
		if !found {
			errs.add("zone_id", "err.session_zone")
		}
		s.ZoneID = in.ZoneID
	}
	st, ok1 := ParseLocal(in.StartsAt, loc)
	en, ok2 := ParseLocal(in.EndsAt, loc)
	switch {
	case !ok1:
		errs.add("starts_at", "err.datetime")
	case !ok2:
		errs.add("ends_at", "err.datetime")
	case !en.After(st):
		errs.add("ends_at", "err.end_before_start")
	case ev.StartsAt != nil && ev.EndsAt != nil && (st.Before(*ev.StartsAt) || en.After(*ev.EndsAt)):
		errs.add("starts_at", "err.session_outside")
	}
	s.StartsAt, s.EndsAt = st, en
	tags, ok := ParseTags(in.Tags)
	if !ok {
		errs.add("tags", "err.tags")
	}
	s.Tags = tags
	if len(errs) > 0 {
		return Session{}, errs
	}
	return s, nil
}
