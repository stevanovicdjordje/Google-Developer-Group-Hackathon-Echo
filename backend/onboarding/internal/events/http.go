package events

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

const MaxPlanBytes = 10 << 20

// Handlers serve the organizer event list and the creation wizard.
type Handlers struct {
	Access
	Loc       *time.Location
	UploadDir string
	MapsKey   string
	Now       func() time.Time
	// CanViewPlan decides who may load a floor-plan image (owner organizer
	// or a participant with an accepted invitation). Set by the app.
	CanViewPlan func(p *httpx.Principal, ev Event) bool
}

func (h *Handlers) Register(mux *http.ServeMux, organizerOnly func(http.Handler) http.Handler) {
	org := func(pattern string, f http.HandlerFunc) { mux.Handle(pattern, organizerOnly(f)) }
	org("GET /org/events", h.list)
	org("GET /org/events/new", h.newForm)
	org("POST /org/events/new", h.create)
	org("GET /org/events/{id}", h.open)
	org("GET /org/events/{id}/edit", h.editForm)
	org("POST /org/events/{id}/edit", h.update)
	org("GET /org/events/{id}/venue", h.venue)
	org("POST /org/events/{id}/venue/plan", h.uploadPlan)
	org("POST /org/events/{id}/zones", h.addZone)
	org("POST /org/events/{id}/zones/{zid}/delete", h.deleteZone)
	org("GET /org/events/{id}/schedule", h.schedule)
	org("POST /org/events/{id}/sessions", h.addSession)
	org("POST /org/events/{id}/sessions/{sid}/delete", h.deleteSession)
	org("GET /org/events/{id}/publish", h.publishForm)
	org("POST /org/events/{id}/publish", h.publish)
	mux.HandleFunc("GET /events/{id}/plan", h.planImage)
}

// ---- list ----

type listData struct {
	Query    string
	Status   string
	Statuses []Status
	Groups   []Group
	Total    int
	Now      time.Time
}

func (h *Handlers) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	org, err := h.Users.GetOrganizationByOwner(p.UserID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	all, err := h.Events.ListByOrganization(org.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	now := h.Now()
	q := r.URL.Query().Get("q")
	st, _ := ParseStatus(r.URL.Query().Get("status"))
	h.View.Page(w, r, http.StatusOK, "events/list", httpx.View{
		Title: "panel.organizer.title",
		Data: listData{Query: q, Status: string(st), Statuses: Statuses,
			Groups: GroupByStatus(Filter(all, q, st, now), now), Total: len(all), Now: now},
	})
}

// ---- wizard: step 1, basics ----

type wizardData struct {
	Event    Event
	Step     string
	Now      time.Time
	MapEmbed string
	Extra    any
}

func (h *Handlers) basicsForm(e Event) url.Values {
	f := url.Values{}
	f.Set("title", e.Title)
	f.Set("description", e.Description)
	f.Set("address", e.Address)
	if e.StartsAt != nil {
		f.Set("starts_at", e.StartsAt.In(h.Loc).Format(dtLayout))
	}
	if e.EndsAt != nil {
		f.Set("ends_at", e.EndsAt.In(h.Loc).Format(dtLayout))
	}
	if e.Lat != nil && e.Lng != nil {
		f.Set("lat", fmt.Sprintf("%.6f", *e.Lat))
		f.Set("lng", fmt.Sprintf("%.6f", *e.Lng))
	}
	return f
}

func basicsInput(r *http.Request) BasicsInput {
	return BasicsInput{
		Title: r.PostFormValue("title"), Description: r.PostFormValue("description"),
		StartsAt: r.PostFormValue("starts_at"), EndsAt: r.PostFormValue("ends_at"),
		Address: r.PostFormValue("address"), Lat: r.PostFormValue("lat"), Lng: r.PostFormValue("lng"),
	}
}

func (h *Handlers) newForm(w http.ResponseWriter, r *http.Request) {
	h.View.Page(w, r, http.StatusOK, "events/basics", httpx.View{
		Title: "wizard.new_title", Data: wizardData{Step: "basics", Now: h.Now()}})
}

func (h *Handlers) create(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	org, err := h.Users.GetOrganizationByOwner(p.UserID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	now := h.Now().UTC()
	ev := Event{ID: id.New(), OrganizationID: org.ID, CreatedAt: now, UpdatedAt: now}
	if errs := ApplyBasics(&ev, basicsInput(r), h.Loc); errs != nil {
		h.View.Page(w, r, http.StatusUnprocessableEntity, "events/basics", httpx.View{
			Title: "wizard.new_title", Form: r.PostForm, Errors: errs, Data: wizardData{Step: "basics", Now: now}})
		return
	}
	if err := h.Events.Create(ev); err != nil {
		h.Fail(w, r, err)
		return
	}
	h.afterSave(w, r, ev, "venue")
}

// afterSave sends the organizer to the next wizard step, or back to the list
// when they chose "save as draft".
func (h *Handlers) afterSave(w http.ResponseWriter, r *http.Request, ev Event, next string) {
	if r.PostFormValue("action") == "draft" {
		http.Redirect(w, r, "/org/events?ok=saved", http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/"+next, http.StatusSeeOther)
}

func (h *Handlers) open(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	if !ev.Editable(h.Now()) {
		http.Redirect(w, r, "/org/events/"+ev.ID+"/report", http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/edit", http.StatusSeeOther)
}

// editable loads the owned event and refuses changes to finished events.
func (h *Handlers) editable(w http.ResponseWriter, r *http.Request) (Event, bool) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return Event{}, false
	}
	if !ev.Editable(h.Now()) {
		http.Redirect(w, r, "/org/events/"+ev.ID+"/report", http.StatusSeeOther)
		return Event{}, false
	}
	return ev, true
}

func (h *Handlers) editForm(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	h.View.Page(w, r, http.StatusOK, "events/basics", httpx.View{
		Title: "wizard.edit_title", Form: h.basicsForm(ev),
		Data: wizardData{Event: ev, Step: "basics", Now: h.Now(), MapEmbed: MapEmbedURL(h.MapsKey, ev)}})
}

func (h *Handlers) update(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	if errs := ApplyBasics(&ev, basicsInput(r), h.Loc); errs != nil {
		h.View.Page(w, r, http.StatusUnprocessableEntity, "events/basics", httpx.View{
			Title: "wizard.edit_title", Form: r.PostForm, Errors: errs,
			Data: wizardData{Event: ev, Step: "basics", Now: h.Now()}})
		return
	}
	ev.UpdatedAt = h.Now().UTC()
	if err := h.Events.Update(ev); err != nil {
		h.Fail(w, r, err)
		return
	}
	h.afterSave(w, r, ev, "venue")
}

// ---- wizard: step 2, venue map and zones ----

type venueData struct {
	HasMap bool
	Plan   PlanView
	Zones  []Zone
	Kinds  []ZoneKind
}

func (h *Handlers) renderVenue(w http.ResponseWriter, r *http.Request, status int, ev Event, form url.Values, errs Errors) {
	zones, err := h.Events.ListZones(ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	vd := venueData{Zones: zones, Kinds: ZoneKinds}
	if m, err := h.Events.GetVenueMap(ev.ID); err == nil {
		vd.HasMap, vd.Plan = true, NewPlanView(m, zones, "", "")
	} else if !errors.Is(err, ErrNotFound) {
		h.Fail(w, r, err)
		return
	}
	h.View.Page(w, r, status, "events/venue", httpx.View{
		Title: "wizard.venue", Form: form, Errors: errs,
		Data: wizardData{Event: ev, Step: "venue", Now: h.Now(), Extra: vd}})
}

func (h *Handlers) venue(w http.ResponseWriter, r *http.Request) {
	if ev, ok := h.editable(w, r); ok {
		h.renderVenue(w, r, http.StatusOK, ev, nil, nil)
	}
}

func (h *Handlers) uploadPlan(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	bad := func(key string) {
		h.renderVenue(w, r, http.StatusUnprocessableEntity, ev, nil, Errors{"plan": key})
	}
	file, hdr, err := r.FormFile("plan")
	if err != nil {
		bad("err.plan_missing")
		return
	}
	defer file.Close()
	if hdr.Size > MaxPlanBytes {
		bad("err.plan_size")
		return
	}
	data, err := io.ReadAll(io.LimitReader(file, MaxPlanBytes+1))
	if err != nil || len(data) > MaxPlanBytes {
		bad("err.plan_size")
		return
	}
	// Trust the bytes, not the client's file name or Content-Type.
	ctype := http.DetectContentType(data)
	ext := map[string]string{"image/png": ".png", "image/jpeg": ".jpg"}[ctype]
	if ext == "" {
		bad("err.plan_type")
		return
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil || cfg.Width < 50 || cfg.Height < 50 || cfg.Width > 10000 || cfg.Height > 10000 {
		bad("err.plan_type")
		return
	}
	dir := filepath.Join(h.UploadDir, "venue")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		h.Fail(w, r, err)
		return
	}
	name := ev.ID + "-" + id.Token(6) + ext
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		h.Fail(w, r, err)
		return
	}
	old, oldErr := h.Events.GetVenueMap(ev.ID)
	if err := h.Events.SaveVenueMap(VenueMap{EventID: ev.ID, FileName: name, ContentType: ctype,
		Width: cfg.Width, Height: cfg.Height, UploadedAt: h.Now().UTC()}); err != nil {
		h.Fail(w, r, err)
		return
	}
	if oldErr == nil && old.FileName != name {
		_ = os.Remove(filepath.Join(dir, filepath.Base(old.FileName)))
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/venue?ok=saved", http.StatusSeeOther)
}

func (h *Handlers) addZone(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	z, errs := ParseZone(ZoneInput{Name: r.PostFormValue("name"), Kind: r.PostFormValue("kind"),
		X: r.PostFormValue("x"), Y: r.PostFormValue("y"), W: r.PostFormValue("w"), H: r.PostFormValue("h")})
	if errs != nil {
		h.renderVenue(w, r, http.StatusUnprocessableEntity, ev, r.PostForm, errs)
		return
	}
	z.ID, z.EventID, z.Created = id.New(), ev.ID, h.Now().UTC()
	if err := h.Events.CreateZone(z); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/venue?ok=saved", http.StatusSeeOther)
}

func (h *Handlers) deleteZone(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	if err := h.Events.DeleteZone(ev.ID, r.PathValue("zid")); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/venue?ok=deleted", http.StatusSeeOther)
}

// planImage serves the floor plan to whoever CanViewPlan allows. Files are
// never exposed as public static assets.
func (h *Handlers) planImage(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	if p == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	ev, err := h.Events.Get(r.PathValue("id"))
	if err != nil || h.CanViewPlan == nil || !h.CanViewPlan(p, ev) {
		http.NotFound(w, r)
		return
	}
	m, err := h.Events.GetVenueMap(ev.ID)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	f, err := os.Open(filepath.Join(h.UploadDir, "venue", filepath.Base(m.FileName)))
	if err != nil {
		log.Printf("plan image %s: %v", ev.ID, err)
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	w.Header().Set("Content-Type", m.ContentType)
	w.Header().Set("Cache-Control", "private, max-age=300")
	http.ServeContent(w, r, "", m.UploadedAt, f)
}

// ---- wizard: step 3, schedule ----

type scheduleData struct {
	Days      []Day
	Sessions  []Session
	Halls     []Zone
	Conflicts map[string]bool
	ZoneNames map[string]string
}

func halls(zones []Zone) []Zone {
	var out []Zone
	for _, z := range zones {
		if z.Kind == ZoneHall {
			out = append(out, z)
		}
	}
	return out
}

// LoadSchedule returns the schedule view data for an event.
func LoadSchedule(repo Repository, ev Event, loc *time.Location) (scheduleData, error) {
	zones, err := repo.ListZones(ev.ID)
	if err != nil {
		return scheduleData{}, err
	}
	sessions, err := repo.ListSessions(ev.ID)
	if err != nil {
		return scheduleData{}, err
	}
	names := map[string]string{}
	for _, z := range zones {
		names[z.ID] = z.Name
	}
	return scheduleData{Days: BuildSchedule(sessions, halls(zones), loc), Sessions: sessions,
		Halls: halls(zones), Conflicts: Overlaps(sessions), ZoneNames: names}, nil
}

func (h *Handlers) renderSchedule(w http.ResponseWriter, r *http.Request, status int, ev Event, form url.Values, errs Errors) {
	sd, err := LoadSchedule(h.Events, ev, h.Loc)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	if form == nil && ev.StartsAt != nil {
		// Pre-fill with the event start to save typing.
		form = url.Values{"starts_at": {ev.StartsAt.In(h.Loc).Format(dtLayout)}}
	}
	h.View.Page(w, r, status, "events/schedule", httpx.View{
		Title: "wizard.schedule", Form: form, Errors: errs,
		Data: wizardData{Event: ev, Step: "schedule", Now: h.Now(), Extra: sd}})
}

func (h *Handlers) schedule(w http.ResponseWriter, r *http.Request) {
	if ev, ok := h.editable(w, r); ok {
		h.renderSchedule(w, r, http.StatusOK, ev, nil, nil)
	}
}

func (h *Handlers) addSession(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	zones, err := h.Events.ListZones(ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	s, errs := ParseSession(SessionInput{
		Title: r.PostFormValue("title"), Description: r.PostFormValue("description"),
		Speaker: r.PostFormValue("speaker"), ZoneID: r.PostFormValue("zone_id"),
		StartsAt: r.PostFormValue("starts_at"), EndsAt: r.PostFormValue("ends_at"), Tags: r.PostFormValue("tags"),
	}, ev, halls(zones), h.Loc)
	if errs != nil {
		h.renderSchedule(w, r, http.StatusUnprocessableEntity, ev, r.PostForm, errs)
		return
	}
	s.ID = id.New()
	if err := h.Events.CreateSession(s); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/schedule?ok=saved", http.StatusSeeOther)
}

func (h *Handlers) deleteSession(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	if err := h.Events.DeleteSession(ev.ID, r.PathValue("sid")); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/schedule?ok=deleted", http.StatusSeeOther)
}

// ---- wizard: step 5, review and publish ----

type publishData struct {
	Problems  []string
	Stats     Stats
	Zones     int
	Sessions  int
	Conflicts int
	HasMap    bool
	Published bool
}

func (h *Handlers) publishData(ev Event) (publishData, error) {
	pd := publishData{Problems: PublishProblems(ev, h.Now()), Published: ev.PublishedAt != nil}
	var err error
	if pd.Stats, err = h.Events.StatsFor(ev.ID); err != nil {
		return pd, err
	}
	zones, err := h.Events.ListZones(ev.ID)
	if err != nil {
		return pd, err
	}
	sessions, err := h.Events.ListSessions(ev.ID)
	if err != nil {
		return pd, err
	}
	_, mapErr := h.Events.GetVenueMap(ev.ID)
	pd.Zones, pd.Sessions, pd.Conflicts, pd.HasMap = len(zones), len(sessions), len(Overlaps(sessions)), mapErr == nil
	return pd, nil
}

func (h *Handlers) publishForm(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	pd, err := h.publishData(ev)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	h.View.Page(w, r, http.StatusOK, "events/publish", httpx.View{
		Title: "wizard.publish",
		Data:  wizardData{Event: ev, Step: "publish", Now: h.Now(), MapEmbed: MapEmbedURL(h.MapsKey, ev), Extra: pd}})
}

func (h *Handlers) publish(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	if ev.PublishedAt != nil {
		http.Redirect(w, r, "/org/events?ok=published", http.StatusSeeOther)
		return
	}
	if problems := PublishProblems(ev, h.Now()); len(problems) > 0 {
		h.publishForm(w, r)
		return
	}
	now := h.Now().UTC()
	ev.PublishedAt, ev.UpdatedAt = &now, now
	if err := h.Events.Update(ev); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events?ok=published", http.StatusSeeOther)
}

// IsOrganizerOf reports whether p owns ev (used by plan access checks).
func IsOrganizerOf(repo users.Repository, p *httpx.Principal, ev Event) bool {
	if p == nil || p.Role != string(users.RoleOrganizer) {
		return false
	}
	org, err := repo.GetOrganizationByOwner(p.UserID)
	return err == nil && org.ID == ev.OrganizationID
}
