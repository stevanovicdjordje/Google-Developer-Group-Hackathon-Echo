package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/find/internal/auth"
	"github.com/Ilij4n/eho/backend/find/internal/match"
	"github.com/Ilij4n/eho/backend/find/internal/store"
)

const maxBodyBytes = 16 << 10

// Contact states as seen by the caller (ContactState).
const (
	stateNone      = "none"
	stateRequested = "requested"
	stateIncoming  = "incoming"
	stateAccepted  = "accepted"
)

// Response bodies (contracts/find/openapi.yaml).

type profileJSON struct {
	Name             string    `json:"name"`
	Headline         string    `json:"headline"`
	Interests        []string  `json:"interests"`
	LookingFor       string    `json:"lookingFor"`
	VisibleInFind    bool      `json:"visibleInFind"`
	AllowContact     bool      `json:"allowContact"`
	ShareMeetingSpot bool      `json:"shareMeetingSpot"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

type personJSON struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Headline   string   `json:"headline"`
	Interests  []string `json:"interests"`
	LookingFor string   `json:"lookingFor"`
}

type personDetailJSON struct {
	personJSON
	AllowContact bool   `json:"allowContact"`
	ContactState string `json:"contactState"`
}

type matchJSON struct {
	Person personJSON `json:"person"`
	Why    string     `json:"why"`
}

type matchesJSON struct {
	Matches []matchJSON `json:"matches"`
	Model   string      `json:"model"`
}

type meetingSpotJSON struct {
	Place     string    `json:"place"`
	Time      string    `json:"time,omitempty"`
	SetByMe   bool      `json:"setByMe"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type contactJSON struct {
	Person      personJSON       `json:"person"`
	State       string           `json:"state"`
	MeetingSpot *meetingSpotJSON `json:"meetingSpot,omitempty"`
	CreatedAt   time.Time        `json:"createdAt"`
}

type fieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func toProfileJSON(p store.Profile) profileJSON {
	return profileJSON{
		Name: p.Name, Headline: p.Headline, Interests: nonNil(p.Interests), LookingFor: p.LookingFor,
		VisibleInFind: p.VisibleInFind, AllowContact: p.AllowContact, ShareMeetingSpot: p.ShareMeetingSpot,
		UpdatedAt: p.UpdatedAt.UTC(),
	}
}

func toPerson(p store.Profile) personJSON {
	return personJSON{ID: p.PersonID, Name: p.Name, Headline: p.Headline, Interests: nonNil(p.Interests), LookingFor: p.LookingFor}
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

// contactState is the state of c from uid's side.
func contactState(c *store.Contact, uid string) string {
	switch {
	case c == nil:
		return stateNone
	case c.State == store.StateAccepted:
		return stateAccepted
	case c.From == uid:
		return stateRequested
	default:
		return stateIncoming
	}
}

func toContact(c store.Contact, me, other store.Profile) contactJSON {
	out := contactJSON{Person: toPerson(other), State: contactState(&c, me.UID), CreatedAt: c.CreatedAt.UTC()}
	if c.MeetingSpot != nil && c.State == store.StateAccepted && me.ShareMeetingSpot && other.ShareMeetingSpot {
		out.MeetingSpot = &meetingSpotJSON{Place: c.MeetingSpot.Place, Time: c.MeetingSpot.Time, SetByMe: c.MeetingSpot.SetBy == me.UID, UpdatedAt: c.MeetingSpot.UpdatedAt.UTC()}
	}
	return out
}

// Request helpers.

func decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", fmt.Sprintf("request body exceeds %d bytes", maxBodyBytes), nil)
		return false
	}
	if err := json.NewDecoder(bytes.NewReader(body)).Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "request body is not valid JSON for this operation", err.Error())
		return false
	}
	return true
}

func invalid(w http.ResponseWriter, errs ...fieldError) {
	writeError(w, http.StatusUnprocessableEntity, "validation_failed", "request is invalid", errs)
}

func notFound(w http.ResponseWriter) {
	writeError(w, http.StatusNotFound, "not_found", "not found", nil)
}

func (s *server) internal(w http.ResponseWriter, r *http.Request, err error) {
	s.log.ErrorContext(r.Context(), "internal error", "route", r.Pattern, "err", err)
	writeError(w, http.StatusInternalServerError, "internal", "internal server error", nil)
}

func runes(s string) int { return utf8.RuneCountInString(s) }

// limitParam reads ?limit (1..20, default 8). Out-of-range values are clamped.
func limitParam(r *http.Request) int {
	n, err := strconv.Atoi(r.URL.Query().Get("limit"))
	if err != nil {
		return 8
	}
	return min(max(n, 1), 20)
}

// checkEvent answers 404 unless the event exists and is published.
func (s *server) checkEvent(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := r.PathValue("eventId")
	e, err := s.store.GetEvent(r.Context(), id)
	if errors.Is(err, store.ErrNotFound) || (err == nil && !e.Published()) {
		notFound(w)
		return "", false
	}
	if err != nil {
		s.internal(w, r, err)
		return "", false
	}
	return id, true
}

// caller checks the event and that the caller is present there, and returns
// the caller's profile.
func (s *server) caller(w http.ResponseWriter, r *http.Request, p auth.Principal) (string, store.Profile, bool) {
	eventID, ok := s.checkEvent(w, r)
	if !ok {
		return "", store.Profile{}, false
	}
	present, err := s.store.IsPresent(r.Context(), eventID, p.UID)
	if err != nil {
		s.internal(w, r, err)
		return "", store.Profile{}, false
	}
	if !present {
		writeError(w, http.StatusConflict, "not_present", "you are not present at this event: call joinFind first", nil)
		return "", store.Profile{}, false
	}
	me, err := s.store.GetProfile(r.Context(), p.UID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "profile_required", "save a profile first", nil)
		return "", store.Profile{}, false
	}
	if err != nil {
		s.internal(w, r, err)
		return "", store.Profile{}, false
	}
	return eventID, me, true
}

// visiblePerson resolves a personId visible at the event, or answers 404.
func (s *server) visiblePerson(w http.ResponseWriter, r *http.Request, eventID, personID string) (store.Profile, bool) {
	a, err := s.store.PersonByID(r.Context(), eventID, personID)
	if errors.Is(err, store.ErrNotFound) || (err == nil && !a.VisibleInFind) {
		notFound(w)
		return store.Profile{}, false
	}
	if err != nil {
		s.internal(w, r, err)
		return store.Profile{}, false
	}
	return a.Profile, true
}

// Profile.

func (s *server) getMyProfile(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	prof, err := s.store.GetProfile(r.Context(), p.UID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "no profile yet", nil)
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toProfileJSON(prof))
}

type profileInput struct {
	Name             *string   `json:"name"`
	Headline         *string   `json:"headline"`
	Interests        *[]string `json:"interests"`
	LookingFor       *string   `json:"lookingFor"`
	VisibleInFind    *bool     `json:"visibleInFind"`
	AllowContact     *bool     `json:"allowContact"`
	ShareMeetingSpot *bool     `json:"shareMeetingSpot"`
}

// validate trims and checks the input against ProfileInput; interests are
// deduplicated case-insensitively.
func (in profileInput) validate() (store.ProfileFields, []fieldError) {
	var f store.ProfileFields
	var errs []fieldError
	str := func(field string, v *string, minLen, maxLen int) string {
		if v == nil {
			errs = append(errs, fieldError{field, "is required"})
			return ""
		}
		t := strings.TrimSpace(*v)
		if n := runes(t); n < minLen || n > maxLen {
			msg := fmt.Sprintf("must be at most %d characters", maxLen)
			if minLen > 0 {
				msg = fmt.Sprintf("must be %d to %d characters", minLen, maxLen)
			}
			errs = append(errs, fieldError{field, msg})
		}
		return t
	}
	boolean := func(field string, v *bool) bool {
		if v == nil {
			errs = append(errs, fieldError{field, "is required"})
			return false
		}
		return *v
	}
	f.Name = str("name", in.Name, 1, 60)
	f.Headline = str("headline", in.Headline, 0, 100)
	if in.Interests == nil {
		errs = append(errs, fieldError{"interests", "is required"})
	} else {
		seen := map[string]bool{}
		f.Interests = []string{}
		for i, v := range *in.Interests {
			t := strings.TrimSpace(v)
			if n := runes(t); n < 1 || n > 30 {
				errs = append(errs, fieldError{fmt.Sprintf("interests[%d]", i), "must be 1 to 30 characters"})
				continue
			}
			if k := strings.ToLower(t); !seen[k] {
				seen[k] = true
				f.Interests = append(f.Interests, t)
			}
		}
		if len(f.Interests) > 10 {
			errs = append(errs, fieldError{"interests", "must have at most 10 items"})
		}
	}
	f.LookingFor = str("lookingFor", in.LookingFor, 0, 200)
	f.VisibleInFind = boolean("visibleInFind", in.VisibleInFind)
	f.AllowContact = boolean("allowContact", in.AllowContact)
	f.ShareMeetingSpot = boolean("shareMeetingSpot", in.ShareMeetingSpot)
	return f, errs
}

func (s *server) putMyProfile(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	var in profileInput
	if !decode(w, r, &in) {
		return
	}
	f, errs := in.validate()
	if len(errs) > 0 {
		invalid(w, errs...)
		return
	}
	prof, err := s.store.SaveProfile(r.Context(), p.UID, f, s.now())
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toProfileJSON(prof))
}

func (s *server) deleteMyProfile(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if err := s.store.DeleteProfile(r.Context(), p.UID); err != nil {
		s.internal(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Presence.

func (s *server) joinFind(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, ok := s.checkEvent(w, r)
	if !ok {
		return
	}
	err := s.store.Join(r.Context(), eventID, p.UID, s.now())
	if errors.Is(err, store.ErrNoProfile) {
		writeError(w, http.StatusConflict, "profile_required", "save a profile first", nil)
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) leaveFind(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if err := s.store.Leave(r.Context(), r.PathValue("eventId"), p.UID); err != nil {
		s.internal(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// People.

func (s *server) rateLimited(w http.ResponseWriter, p auth.Principal) bool {
	if ok, retry := s.aiLimit.allow(p.UID); !ok {
		w.Header().Set("Retry-After", strconv.Itoa(retry))
		writeError(w, http.StatusTooManyRequests, "rate_limited", "too many AI requests, try again later", nil)
		return true
	}
	return false
}

// candidates are the visible people at the event except the caller.
func (s *server) candidates(ctx context.Context, eventID, uid string) ([]match.Candidate, map[string]store.Profile, error) {
	people, err := s.store.People(ctx, eventID)
	if err != nil {
		return nil, nil, err
	}
	slices.SortFunc(people, func(a, b store.Attendee) int { return strings.Compare(a.PersonID, b.PersonID) })
	byKey := map[string]store.Profile{}
	var cands []match.Candidate
	for _, a := range people {
		if a.UID == uid || !a.VisibleInFind || a.PersonID == "" {
			continue
		}
		byKey[a.PersonID] = a.Profile
		cands = append(cands, match.Candidate{Key: a.PersonID, Name: a.Name, Profile: match.Profile{
			Headline: a.Headline, Interests: a.Interests, LookingFor: a.LookingFor,
		}})
	}
	return cands, byKey, nil
}

func toMatches(res match.Result, byKey map[string]store.Profile, limit int) matchesJSON {
	out := matchesJSON{Matches: []matchJSON{}, Model: res.Model}
	seen := map[string]bool{}
	for _, pk := range res.Picks {
		prof, ok := byKey[pk.Key]
		if !ok || seen[pk.Key] || len(out.Matches) >= limit {
			continue
		}
		seen[pk.Key] = true
		out.Matches = append(out.Matches, matchJSON{Person: toPerson(prof), Why: match.CleanWhy(pk.Why)})
	}
	return out
}

func (s *server) recommendations(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if s.rateLimited(w, p) {
		return
	}
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	limit := limitParam(r)
	cands, byKey, err := s.candidates(r.Context(), eventID, p.UID)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	res, err := s.matcher.Recommend(r.Context(), match.Profile{Headline: me.Headline, Interests: me.Interests, LookingFor: me.LookingFor}, cands, limit)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toMatches(res, byKey, limit))
}

func (s *server) search(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if s.rateLimited(w, p) {
		return
	}
	var in struct {
		Prompt *string `json:"prompt"`
	}
	if !decode(w, r, &in) {
		return
	}
	if in.Prompt == nil {
		invalid(w, fieldError{"prompt", "is required"})
		return
	}
	prompt := strings.TrimSpace(*in.Prompt)
	if n := runes(prompt); n < 2 || n > 300 {
		invalid(w, fieldError{"prompt", "must be 2 to 300 characters"})
		return
	}
	eventID, _, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	limit := limitParam(r)
	cands, byKey, err := s.candidates(r.Context(), eventID, p.UID)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	res, err := s.matcher.Search(r.Context(), prompt, cands, limit)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toMatches(res, byKey, limit))
}

func (s *server) getPerson(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, _, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	other, ok := s.visiblePerson(w, r, eventID, r.PathValue("personId"))
	if !ok {
		return
	}
	var cp *store.Contact
	if other.UID != p.UID {
		c, err := s.store.GetContact(r.Context(), eventID, p.UID, other.UID)
		switch {
		case err == nil:
			cp = &c
		case !errors.Is(err, store.ErrNotFound):
			s.internal(w, r, err)
			return
		}
	}
	writeJSON(w, http.StatusOK, personDetailJSON{personJSON: toPerson(other), AllowContact: other.AllowContact, ContactState: contactState(cp, p.UID)})
}

// Contacts.

var (
	errContactNotAllowed = errors.New("contact not allowed")
	errNoRequest         = errors.New("no request from this person")
	errSpotNotAllowed    = errors.New("meeting spot not allowed")
)

func (s *server) listContacts(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	cs, err := s.store.Contacts(r.Context(), eventID, p.UID)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	slices.SortStableFunc(cs, func(a, b store.Contact) int { return b.CreatedAt.Compare(a.CreatedAt) })
	out := []contactJSON{}
	for _, c := range cs {
		other, err := s.store.GetProfile(r.Context(), c.Other(p.UID))
		if errors.Is(err, store.ErrNotFound) {
			continue
		}
		if err != nil {
			s.internal(w, r, err)
			return
		}
		// Accepted contacts agreed to share; pending requests follow visibility.
		if c.State != store.StateAccepted && !other.VisibleInFind {
			continue
		}
		out = append(out, toContact(c, me, other))
	}
	writeJSON(w, http.StatusOK, map[string]any{"contacts": out})
}

func (s *server) requestContact(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	var in struct {
		PersonID *string `json:"personId"`
	}
	if !decode(w, r, &in) {
		return
	}
	if in.PersonID == nil || strings.TrimSpace(*in.PersonID) == "" {
		invalid(w, fieldError{"personId", "is required"})
		return
	}
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	other, ok := s.visiblePerson(w, r, eventID, strings.TrimSpace(*in.PersonID))
	if !ok {
		return
	}
	if other.UID == p.UID {
		invalid(w, fieldError{"personId", "you can't send a contact request to yourself"})
		return
	}
	now := s.now()
	c, err := s.store.UpdateContact(r.Context(), eventID, p.UID, other.UID, func(cur *store.Contact) (*store.Contact, error) {
		switch {
		case cur == nil:
			if !other.AllowContact {
				return nil, errContactNotAllowed
			}
			c := &store.Contact{From: p.UID, State: store.StateRequested, CreatedAt: now}
			if other.Demo {
				c.State = store.StateAccepted
			}
			return c, nil
		case cur.State == store.StateAccepted:
			return nil, nil
		case cur.From == other.UID || other.Demo:
			// They already asked the caller (or a demo attendee): accept.
			cur.State = store.StateAccepted
			return cur, nil
		default:
			return nil, nil
		}
	})
	if errors.Is(err, errContactNotAllowed) {
		writeError(w, http.StatusForbidden, "contact_not_allowed", "this person doesn't accept contact requests", nil)
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toContact(c, me, other))
}

func (s *server) acceptContact(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	other, ok := s.visiblePerson(w, r, eventID, r.PathValue("personId"))
	if !ok {
		return
	}
	if other.UID == p.UID {
		writeError(w, http.StatusNotFound, "not_found", "no request from this person", nil)
		return
	}
	c, err := s.store.UpdateContact(r.Context(), eventID, p.UID, other.UID, func(cur *store.Contact) (*store.Contact, error) {
		switch {
		case cur == nil:
			return nil, errNoRequest
		case cur.State == store.StateAccepted:
			return nil, nil
		case cur.From == other.UID:
			cur.State = store.StateAccepted
			return cur, nil
		default:
			return nil, errNoRequest
		}
	})
	if errors.Is(err, errNoRequest) || errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "no request from this person", nil)
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toContact(c, me, other))
}

// timeOfDay is a meeting time, "HH:mm" in 24 h.
var timeOfDay = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)

func (s *server) putMeetingSpot(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	var in struct {
		Place *string `json:"place"`
		Time  string  `json:"time"`
	}
	if !decode(w, r, &in) {
		return
	}
	if in.Place == nil {
		invalid(w, fieldError{"place", "is required"})
		return
	}
	place := strings.TrimSpace(*in.Place)
	if n := runes(place); n < 1 || n > 80 {
		invalid(w, fieldError{"place", "must be 1 to 80 characters"})
		return
	}
	at := strings.TrimSpace(in.Time)
	if at != "" && !timeOfDay.MatchString(at) {
		invalid(w, fieldError{"time", `must be "HH:mm" (24 h)`})
		return
	}
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	other, ok := s.visiblePerson(w, r, eventID, r.PathValue("personId"))
	if !ok {
		return
	}
	notAllowed := func() {
		writeError(w, http.StatusForbidden, "meeting_spot_not_allowed",
			"a meeting spot needs an accepted contact and both people sharing meeting spots", nil)
	}
	if other.UID == p.UID || !me.ShareMeetingSpot || !other.ShareMeetingSpot {
		notAllowed()
		return
	}
	c, err := s.store.GetContact(r.Context(), eventID, p.UID, other.UID)
	if errors.Is(err, store.ErrNotFound) || (err == nil && c.State != store.StateAccepted) {
		notAllowed()
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	name, err := s.store.FeatureName(r.Context(), eventID, place)
	if errors.Is(err, store.ErrNotFound) {
		invalid(w, fieldError{"place", "must be the name of a room, stand or point on the event's venue map"})
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	now := s.now()
	c, err = s.store.UpdateContact(r.Context(), eventID, p.UID, other.UID, func(cur *store.Contact) (*store.Contact, error) {
		if cur == nil || cur.State != store.StateAccepted {
			return nil, errSpotNotAllowed
		}
		cur.MeetingSpot = &store.MeetingSpot{Place: name, Time: at, SetBy: p.UID, UpdatedAt: now}
		return cur, nil
	})
	if errors.Is(err, errSpotNotAllowed) {
		notAllowed()
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toContact(c, me, other))
}

func (s *server) deleteMeetingSpot(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, me, ok := s.caller(w, r, p)
	if !ok {
		return
	}
	other, ok := s.visiblePerson(w, r, eventID, r.PathValue("personId"))
	if !ok {
		return
	}
	if other.UID == p.UID {
		notFound(w)
		return
	}
	c, err := s.store.UpdateContact(r.Context(), eventID, p.UID, other.UID, func(cur *store.Contact) (*store.Contact, error) {
		if cur == nil {
			return nil, store.ErrNotFound
		}
		if cur.MeetingSpot == nil {
			return nil, nil
		}
		cur.MeetingSpot = nil
		return cur, nil
	})
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "no contact with this person", nil)
		return
	}
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toContact(c, me, other))
}
