package events

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
)

// Handlers serve the organizer event list and the creation wizard.
type Handlers struct {
	Access
	Images  Images
	Stats   StatsSource
	Loc     *time.Location
	MapsKey string
	// AppURL is the Flutter app: the organizer map editor lives there.
	AppURL string
	Now    func() time.Time
	// CanViewPlan decides who may load floor-plan images (owner organizer or
	// a participant with an accepted invitation). Set by the app.
	CanViewPlan func(ctx context.Context, p *httpx.Principal, ev Event) bool
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
	org("GET /org/events/{id}/schedule", h.schedule)
	org("POST /org/events/{id}/sessions", h.addSession)
	org("POST /org/events/{id}/sessions/{sid}/delete", h.deleteSession)
	org("GET /org/events/{id}/publish", h.publishForm)
	org("POST /org/events/{id}/publish", h.publish)
	mux.HandleFunc("GET /events/{id}/floors/{floor}/image", h.floorImage)
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
	evs, err := h.Events.ListByOwner(r.Context(), p.UserID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	all := make([]Summary, 0, len(evs))
	for _, ev := range evs {
		st, err := h.Stats.EventStats(r.Context(), ev.ID)
		if err != nil {
			h.Fail(w, r, err)
			return
		}
		all = append(all, Summary{Event: ev, Stats: st})
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
	now := h.Now().UTC()
	ev := Event{ID: NewID(), OwnerUID: p.UserID, CreatedAt: now, UpdatedAt: now}
	if errs := ApplyBasics(&ev, basicsInput(r), h.Loc); errs != nil {
		h.View.Page(w, r, http.StatusUnprocessableEntity, "events/basics", httpx.View{
			Title: "wizard.new_title", Form: r.PostForm, Errors: errs, Data: wizardData{Step: "basics", Now: now}})
		return
	}
	if err := h.Events.Create(r.Context(), ev); err != nil {
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
	if err := h.Events.Update(r.Context(), ev); err != nil {
		h.Fail(w, r, err)
		return
	}
	h.afterSave(w, r, ev, "venue")
}

// ---- wizard: step 2, venue map (edited in the Flutter app) ----

type venueData struct {
	HasMap    bool
	Plan      PlanView
	Rooms     []string
	EditorURL string
}

func (h *Handlers) venue(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	m, err := h.Events.GetPublishedMap(r.Context(), ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	vd := venueData{HasMap: !m.Empty(), Rooms: m.RoomNames(), EditorURL: strings.TrimRight(h.AppURL, "/") + "/o"}
	if vd.HasMap {
		vd.Plan = NewPlanView(ev.ID, m, "", "")
	}
	h.View.Page(w, r, http.StatusOK, "events/venue", httpx.View{
		Title: "wizard.venue", Data: wizardData{Event: ev, Step: "venue", Now: h.Now(), Extra: vd}})
}

// floorImage proxies a floor-plan image from Storage to whoever CanViewPlan
// allows. Images are never public.
func (h *Handlers) floorImage(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	if p == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	ev, err := h.Events.Get(r.Context(), r.PathValue("id"))
	if err != nil || h.CanViewPlan == nil || !h.CanViewPlan(r.Context(), p, ev) {
		http.NotFound(w, r)
		return
	}
	m, err := h.Events.GetPublishedMap(r.Context(), ev.ID)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	floor, ok := m.Floor(r.PathValue("floor"))
	if !ok || floor.ImagePath == "" {
		http.NotFound(w, r)
		return
	}
	rd, ctype, err := h.Images.FloorImage(r.Context(), floor.ImagePath)
	if err != nil {
		if !errors.Is(err, ErrNotFound) {
			log.Printf("floor image %s/%s: %v", ev.ID, floor.ID, err)
		}
		http.NotFound(w, r)
		return
	}
	defer rd.Close()
	if !strings.HasPrefix(ctype, "image/") {
		ctype = "image/png"
	}
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Cache-Control", "private, max-age=300")
	_, _ = io.Copy(w, rd)
}

// ---- wizard: step 3, schedule (the shared agenda) ----

type ScheduleData struct {
	Days      []Day
	Sessions  []Session
	Stages    []string // offered halls: agenda stages + map rooms
	Conflicts map[string]bool
}

// LoadSchedule reads the agenda and the map's room names.
func LoadSchedule(ctx context.Context, repo Repository, ev Event, loc *time.Location) (ScheduleData, error) {
	a, err := repo.GetAgenda(ctx, ev.ID)
	if err != nil {
		return ScheduleData{}, err
	}
	m, err := repo.GetPublishedMap(ctx, ev.ID)
	if err != nil {
		return ScheduleData{}, err
	}
	stages := append([]string(nil), a.Stages...)
	for _, room := range m.RoomNames() {
		if !containsFold(stages, room) {
			stages = append(stages, room)
		}
	}
	sessions := a.SessionList(loc)
	return ScheduleData{Days: BuildSchedule(sessions, stages, loc), Sessions: sessions,
		Stages: stages, Conflicts: Overlaps(sessions)}, nil
}

func (h *Handlers) renderSchedule(w http.ResponseWriter, r *http.Request, status int, ev Event, form url.Values, errs Errors) {
	sd, err := LoadSchedule(r.Context(), h.Events, ev, h.Loc)
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
	s, errs := ParseSession(SessionInput{
		Title: r.PostFormValue("title"), Description: r.PostFormValue("description"),
		Speaker: r.PostFormValue("speaker"), Stage: r.PostFormValue("stage"), StageNew: r.PostFormValue("stage_new"),
		StartsAt: r.PostFormValue("starts_at"), EndsAt: r.PostFormValue("ends_at"), Tags: r.PostFormValue("tags"),
	}, ev, h.Loc)
	if errs != nil {
		h.renderSchedule(w, r, http.StatusUnprocessableEntity, ev, r.PostForm, errs)
		return
	}
	a, err := h.Events.GetAgenda(r.Context(), ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	a.Add(s, h.Loc)
	a.PublishedAt = h.Now().UTC()
	if err := h.Events.SaveAgenda(r.Context(), ev.ID, a); err != nil {
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
	a, err := h.Events.GetAgenda(r.Context(), ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	if a.Remove(r.PathValue("sid")) {
		a.PublishedAt = h.Now().UTC()
		if err := h.Events.SaveAgenda(r.Context(), ev.ID, a); err != nil {
			h.Fail(w, r, err)
			return
		}
	}
	http.Redirect(w, r, "/org/events/"+ev.ID+"/schedule?ok=deleted", http.StatusSeeOther)
}

// ---- wizard: step 5, review and publish ----

type publishData struct {
	Problems  []string
	Stats     Stats
	Rooms     int
	Sessions  int
	Conflicts int
	HasMap    bool
	Published bool
}

func (h *Handlers) publishData(ctx context.Context, ev Event) (publishData, error) {
	pd := publishData{Problems: PublishProblems(ev, h.Now()), Published: ev.PublishedAt != nil}
	var err error
	if pd.Stats, err = h.Stats.EventStats(ctx, ev.ID); err != nil {
		return pd, err
	}
	sd, err := LoadSchedule(ctx, h.Events, ev, h.Loc)
	if err != nil {
		return pd, err
	}
	m, err := h.Events.GetPublishedMap(ctx, ev.ID)
	if err != nil {
		return pd, err
	}
	pd.Rooms, pd.Sessions, pd.Conflicts, pd.HasMap = len(m.RoomNames()), len(sd.Sessions), len(sd.Conflicts), !m.Empty()
	return pd, nil
}

func (h *Handlers) publishForm(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.editable(w, r)
	if !ok {
		return
	}
	pd, err := h.publishData(r.Context(), ev)
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
	if err := h.Events.Update(r.Context(), ev); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events?ok=published", http.StatusSeeOther)
}
