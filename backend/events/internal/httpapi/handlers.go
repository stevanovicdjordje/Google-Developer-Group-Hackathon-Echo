package httpapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
	"github.com/Ilij4n/eho/backend/events/internal/auth"
	"github.com/Ilij4n/eho/backend/events/internal/extract"
	"github.com/Ilij4n/eho/backend/events/internal/store"
)

// Upload limits (contract createDraft).
const (
	maxFiles     = 10
	maxFileBytes = 10 << 20
	maxAllBytes  = 20 << 20
	maxJSONBytes = 2 << 20
)

// organizer is authed + not anonymous.
func (s *server) organizer(h func(http.ResponseWriter, *http.Request, auth.Principal)) http.Handler {
	return s.authed(func(w http.ResponseWriter, r *http.Request, p auth.Principal) {
		if p.Anonymous {
			writeError(w, http.StatusForbidden, "organizer_account_required", "sign in with an organizer account", nil)
			return
		}
		h(w, r, p)
	})
}

func (s *server) respondErr(w http.ResponseWriter, r *http.Request, err error) {
	var ve agenda.ValidationError
	switch {
	case errors.As(err, &ve):
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid", []agenda.FieldError(ve))
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "resource not found", nil)
	default:
		s.log.ErrorContext(r.Context(), "request failed", "route", r.Pattern, "err", err)
		writeError(w, http.StatusInternalServerError, "internal", "internal server error", nil)
	}
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxJSONBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "malformed JSON or unknown field", nil)
		return false
	}
	return true
}

// ---- attendee ----

type publicEventJSON struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	StartDate string `json:"startDate"`
	EndDate   string `json:"endDate"`
	Address   string `json:"address"`
	HasMap    bool   `json:"hasMap"`
	HasAgenda bool   `json:"hasAgenda"`
}

type myEventJSON struct {
	publicEventJSON
	JoinedAt time.Time `json:"joinedAt"`
	IsPast   bool      `json:"isPast"`
}

// publicEvent loads an event that attendees may see: its map or agenda is published.
func (s *server) publicEvent(r *http.Request, id string) (*publicEventJSON, error) {
	e, err := s.store.GetEvent(r.Context(), id)
	if err != nil {
		return nil, err
	}
	hasMap := e.PublishedVersion > 0
	_, err = s.store.GetAgenda(r.Context(), id)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return nil, err
	}
	hasAgenda := err == nil
	if !hasMap && !hasAgenda {
		return nil, store.ErrNotFound
	}
	return &publicEventJSON{ID: e.ID, Name: e.Name, StartDate: e.StartDate, EndDate: e.EndDate,
		Address: e.Address, HasMap: hasMap, HasAgenda: hasAgenda}, nil
}

func (s *server) getPublicEvent(w http.ResponseWriter, r *http.Request, _ auth.Principal) {
	pe, err := s.publicEvent(r, r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, pe)
}

func (s *server) joinEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	id := r.PathValue("eventId")
	if _, err := s.publicEvent(r, id); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.Join(r.Context(), p.UID, id, s.now()); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) leaveEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if err := s.store.Leave(r.Context(), p.UID, r.PathValue("eventId")); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) listMyEvents(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	ms, err := s.store.ListMemberships(r.Context(), p.UID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	today := s.now().In(s.location).Format(time.DateOnly)
	out := []myEventJSON{}
	for _, m := range ms {
		pe, err := s.publicEvent(r, m.EventID)
		if errors.Is(err, store.ErrNotFound) {
			continue // deleted or unpublished since
		}
		if err != nil {
			s.respondErr(w, r, err)
			return
		}
		out = append(out, myEventJSON{publicEventJSON: *pe, JoinedAt: m.JoinedAt.UTC(), IsPast: pe.EndDate < today})
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": out})
}

func (s *server) getAgenda(w http.ResponseWriter, r *http.Request, _ auth.Principal) {
	a, err := s.store.GetAgenda(r.Context(), r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	a.PublishedAt = a.PublishedAt.UTC()
	writeJSON(w, http.StatusOK, a)
}

// ---- organizer ----

type draftJSON struct {
	ID string `json:"id"`
	agenda.Fields
	Issues           []agenda.Issue     `json:"issues"`
	Model            string             `json:"model"`
	SourceFiles      []store.SourceFile `json:"sourceFiles"`
	PublishedEventID string             `json:"publishedEventId,omitempty"`
	CreatedAt        time.Time          `json:"createdAt"`
	UpdatedAt        time.Time          `json:"updatedAt"`
}

func toJSON(d *store.Draft) draftJSON {
	return draftJSON{ID: d.ID, Fields: d.Fields, Issues: d.Issues, Model: d.Model, SourceFiles: d.SourceFiles,
		PublishedEventID: d.PublishedEventID, CreatedAt: d.CreatedAt.UTC(), UpdatedAt: d.UpdatedAt.UTC()}
}

// issues adds the review warnings, including "no event name".
func issues(f *agenda.Fields) []agenda.Issue {
	out := agenda.Issues(f)
	if f.Name == "" {
		out = append([]agenda.Issue{{Severity: "warning", Field: "name", Message: "No event name found."}}, out...)
	}
	return out
}

func (s *server) createDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if ok, retry := s.limit.allow(p.UID); !ok {
		w.Header().Set("Retry-After", strconv.Itoa(retry))
		writeError(w, http.StatusTooManyRequests, "rate_limited", "too many uploads, try again shortly", nil)
		return
	}
	files, sources, ok := s.readUpload(w, r)
	if !ok {
		return
	}
	res, err := s.extract.Extract(r.Context(), files)
	switch {
	case errors.Is(err, extract.ErrNothing):
		writeError(w, http.StatusUnprocessableEntity, "nothing_extracted", "no sessions found in the files", nil)
		return
	case errors.Is(err, extract.ErrAIUnavailable):
		writeError(w, http.StatusServiceUnavailable, "ai_unavailable",
			"the AI could not read these files right now; a spreadsheet with title/stage/start/end columns works without it", nil)
		return
	case err != nil:
		s.respondErr(w, r, err)
		return
	}
	now := s.now()
	d := &store.Draft{
		ID: store.NewID(), OwnerUID: p.UID, Fields: res.Fields, Issues: issues(&res.Fields),
		Model: res.Model, SourceFiles: sources, CreatedAt: now, UpdatedAt: now,
	}
	if err := s.store.CreateDraft(r.Context(), d); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toJSON(d))
}

// readUpload reads and sniffs the multipart files, enforcing the limits.
func (s *server) readUpload(w http.ResponseWriter, r *http.Request) ([]extract.File, []store.SourceFile, bool) {
	r.Body = http.MaxBytesReader(w, r.Body, maxAllBytes+1<<20)
	mr, err := r.MultipartReader()
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_multipart", "send the files as multipart/form-data, field \"files\"", nil)
		return nil, nil, false
	}
	var files []extract.File
	var sources []store.SourceFile
	total := 0
	for {
		part, err := mr.NextPart()
		if errors.Is(err, io.EOF) {
			break
		}
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			writeError(w, http.StatusRequestEntityTooLarge, "too_large", "files are over 20 MiB together", nil)
			return nil, nil, false
		}
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_multipart", "malformed multipart body", nil)
			return nil, nil, false
		}
		if part.FormName() != "files" || part.FileName() == "" {
			part.Close()
			continue
		}
		if len(files) == maxFiles {
			writeError(w, http.StatusRequestEntityTooLarge, "too_large", fmt.Sprintf("at most %d files", maxFiles), nil)
			return nil, nil, false
		}
		name := agenda.Clean(part.FileName(), 120)
		data, err := readPart(part, maxFileBytes)
		part.Close()
		if errors.As(err, &tooBig) || errors.Is(err, errPartTooLarge) {
			writeError(w, http.StatusRequestEntityTooLarge, "too_large", fmt.Sprintf("%s is over 10 MiB", name), nil)
			return nil, nil, false
		}
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_multipart", "malformed multipart body", nil)
			return nil, nil, false
		}
		if total += len(data); total > maxAllBytes {
			writeError(w, http.StatusRequestEntityTooLarge, "too_large", "files are over 20 MiB together", nil)
			return nil, nil, false
		}
		f, err := extract.Sniff(name, data)
		if err != nil {
			writeError(w, http.StatusUnsupportedMediaType, "unsupported_file",
				"accepted: PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX",
				[]agenda.FieldError{{Field: name, Message: "not a supported file type"}})
			return nil, nil, false
		}
		files = append(files, f)
		sources = append(sources, store.SourceFile{Name: name, SizeBytes: len(data), Type: f.Kind})
	}
	if len(files) == 0 {
		writeError(w, http.StatusBadRequest, "no_files", "attach at least one file in the \"files\" field", nil)
		return nil, nil, false
	}
	return files, sources, true
}

var errPartTooLarge = errors.New("part too large")

func readPart(part *multipart.Part, limit int) ([]byte, error) {
	var buf bytes.Buffer
	n, err := io.Copy(&buf, io.LimitReader(part, int64(limit)+1))
	if err != nil {
		return nil, err
	}
	if n > int64(limit) {
		return nil, errPartTooLarge
	}
	return buf.Bytes(), nil
}

// ownDraft loads the draft and checks that p owns it.
func (s *server) ownDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) (*store.Draft, bool) {
	d, err := s.store.GetDraft(r.Context(), r.PathValue("draftId"))
	if err != nil {
		s.respondErr(w, r, err)
		return nil, false
	}
	if d.OwnerUID != p.UID {
		writeError(w, http.StatusForbidden, "forbidden", "only the draft's owner can do this", nil)
		return nil, false
	}
	return d, true
}

func (s *server) getDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if d, ok := s.ownDraft(w, r, p); ok {
		writeJSON(w, http.StatusOK, toJSON(d))
	}
}

func (s *server) updateDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	d, ok := s.ownDraft(w, r, p)
	if !ok {
		return
	}
	var in agenda.Fields
	if !decode(w, r, &in) {
		return
	}
	trimFields(&in)
	if err := agenda.Validate(&in); err != nil {
		s.respondErr(w, r, err)
		return
	}
	agenda.LinkSpeakers(&in)
	agenda.SortSessions(in.Sessions)
	d.Fields, d.Issues, d.UpdatedAt = in, issues(&in), s.now()
	if err := s.store.UpdateDraft(r.Context(), d); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toJSON(d))
}

// trimFields trims text and turns null arrays into empty ones.
func trimFields(f *agenda.Fields) {
	f.Name, f.Address = strings.TrimSpace(f.Name), strings.TrimSpace(f.Address)
	if f.Stages == nil {
		f.Stages = []string{}
	}
	if f.Speakers == nil {
		f.Speakers = []agenda.Speaker{}
	}
	if f.Sessions == nil {
		f.Sessions = []agenda.Session{}
	}
	for i := range f.Stages {
		f.Stages[i] = strings.TrimSpace(f.Stages[i])
	}
	for i := range f.Speakers {
		f.Speakers[i].Name, f.Speakers[i].Title = strings.TrimSpace(f.Speakers[i].Name), strings.TrimSpace(f.Speakers[i].Title)
	}
	for i := range f.Sessions {
		s := &f.Sessions[i]
		s.Title, s.Stage, s.Track = strings.TrimSpace(s.Title), strings.TrimSpace(s.Stage), strings.TrimSpace(s.Track)
		s.Description = strings.TrimSpace(s.Description)
		if s.Day == "" && agenda.ValidDate(f.StartDate) {
			s.Day = f.StartDate // single-day events: the review may leave days out
		}
		if s.Speakers == nil {
			s.Speakers = []agenda.Speaker{}
		}
	}
}

type publishResult struct {
	EventID     string         `json:"eventId"`
	JoinPath    string         `json:"joinPath"`
	Sessions    int            `json:"sessions"`
	Warnings    []agenda.Issue `json:"warnings"`
	PublishedAt time.Time      `json:"publishedAt"`
}

func (s *server) publishDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	d, ok := s.ownDraft(w, r, p)
	if !ok {
		return
	}
	var in struct {
		EventID string `json:"eventId"`
	}
	if r.ContentLength != 0 && !decode(w, r, &in) {
		return
	}
	f := d.Fields
	if f.Name == "" || !agenda.ValidDate(f.StartDate) || !agenda.ValidDate(f.EndDate) {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "the draft needs a name and dates before publishing",
			[]agenda.FieldError{{Field: "name", Message: "name, startDate and endDate are required to publish"}})
		return
	}
	now := s.now()
	pub := store.Publication{DraftID: d.ID, Event: store.Event{
		Name: f.Name, StartDate: f.StartDate, EndDate: f.EndDate, Address: f.Address,
	}}
	var previous []agenda.Session
	if in.EventID != "" {
		e, err := s.store.GetEvent(r.Context(), in.EventID)
		if err != nil {
			s.respondErr(w, r, err)
			return
		}
		if e.OwnerUID != p.UID {
			writeError(w, http.StatusForbidden, "forbidden", "only the event's owner can publish into it", nil)
			return
		}
		pub.Event.ID = e.ID
		if a, err := s.store.GetAgenda(r.Context(), e.ID); err == nil {
			previous = a.Sessions
		} else if !errors.Is(err, store.ErrNotFound) {
			s.respondErr(w, r, err)
			return
		}
	} else {
		pub.Create = true
		pub.Event.ID, pub.Event.OwnerUID = store.NewID(), p.UID
	}

	sessions := make([]agenda.Session, len(f.Sessions))
	copy(sessions, f.Sessions)
	agenda.KeepIDs(sessions, previous, func() string { return "s-" + store.NewID()[:8] })
	pub.Agenda = agenda.Agenda{Stages: f.Stages, Speakers: f.Speakers, Sessions: sessions, PublishedAt: now}

	warnings := []agenda.Issue{}
	if !pub.Create {
		rooms, err := s.store.RoomNames(r.Context(), pub.Event.ID)
		if err != nil {
			s.respondErr(w, r, err)
			return
		}
		warnings = stageWarnings(f.Stages, sessions, rooms)
	}
	if err := s.store.PublishAgenda(r.Context(), pub); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, publishResult{EventID: pub.Event.ID, JoinPath: "/e/" + pub.Event.ID,
		Sessions: len(sessions), Warnings: warnings, PublishedAt: now})
}

// stageWarnings lists stages that aren't a room on the published map (only
// when the map has rooms), so "Show on map" would not find them.
func stageWarnings(stages []string, sessions []agenda.Session, rooms []string) []agenda.Issue {
	out := []agenda.Issue{}
	if len(rooms) == 0 {
		return out
	}
	known := map[string]bool{}
	for _, r := range rooms {
		known[strings.ToLower(strings.TrimSpace(r))] = true
	}
	used := map[string]bool{}
	for _, s := range sessions {
		used[strings.ToLower(s.Stage)] = true
	}
	for i, st := range stages {
		if !known[strings.ToLower(st)] && used[strings.ToLower(st)] {
			out = append(out, agenda.Issue{Severity: "warning", Field: fmt.Sprintf("stages[%d]", i),
				Message: fmt.Sprintf("%q is not a room on the venue map, so \"Show on map\" won't find it.", st)})
		}
	}
	return out
}
