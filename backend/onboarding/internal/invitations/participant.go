package invitations

import (
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
)

type myEventsData struct {
	Current []Row // upcoming and ongoing
	Past    []Row
	Pending []Row
	Now     time.Time
}

func (h *Handlers) myEvents(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	invs, err := h.Repo.ListForParticipant(r.Context(), p.UserID, p.Email)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	now := h.Now()
	d := myEventsData{Now: now}
	for _, inv := range invs {
		ev, err := h.Events.Get(r.Context(), inv.EventID)
		if errors.Is(err, events.ErrNotFound) {
			continue // the event was deleted in the map editor
		}
		if err != nil {
			h.Fail(w, r, err)
			return
		}
		st := ev.Status(now)
		if st == events.StatusDraft {
			continue
		}
		row := Row{Invitation: inv, Event: ev}
		switch inv.Effective(ev, now) {
		case StatusAccepted:
			if st == events.StatusFinished {
				d.Past = append(d.Past, row)
			} else {
				d.Current = append(d.Current, row)
			}
		case StatusSent:
			d.Pending = append(d.Pending, row)
		}
	}
	sort.Slice(d.Current, func(i, j int) bool { return d.Current[i].Event.StartsAt.Before(*d.Current[j].Event.StartsAt) })
	sort.Slice(d.Past, func(i, j int) bool { return d.Past[i].Event.EndsAt.After(*d.Past[j].Event.EndsAt) })
	h.View.Page(w, r, http.StatusOK, "participant/events", httpx.View{Title: "panel.participant.title", Data: d})
}

type myEventData struct {
	Event    events.Event
	Status   events.Status
	MapEmbed string
	AppLink  string
	HasMap   bool
	Plan     events.PlanView
	Zone     *events.Feature
	ZoneSess []events.Session
	Schedule events.ScheduleData
}

func (h *Handlers) myEvent(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	ev, err := h.Events.Get(r.Context(), r.PathValue("id"))
	if err != nil && !errors.Is(err, events.ErrNotFound) {
		h.Fail(w, r, err)
		return
	}
	accepted := false
	if err == nil && ev.Published() {
		if accepted, err = h.Repo.HasAccepted(r.Context(), ev.ID, p.UserID); err != nil {
			h.Fail(w, r, err)
			return
		}
	}
	if !accepted {
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return
	}
	sched, err := events.LoadSchedule(r.Context(), h.Events, ev, h.Loc)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	m, err := h.Events.GetPublishedMap(r.Context(), ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	d := myEventData{Event: ev, Status: ev.Status(h.Now()), MapEmbed: events.MapEmbedURL(h.MapsKey, ev),
		AppLink: strings.TrimRight(h.AppURL, "/") + "/e/" + ev.ID, Schedule: sched}
	selected := r.URL.Query().Get("zone")
	if !m.Empty() {
		d.HasMap = true
		d.Plan = events.NewPlanView(ev.ID, m, "/me/events/"+ev.ID+"?zone=", selected)
	}
	if f, ok := m.Feature(selected); ok {
		d.Zone = &f
		for _, s := range sched.Sessions {
			if strings.EqualFold(s.Stage, f.Name) {
				d.ZoneSess = append(d.ZoneSess, s)
			}
		}
	}
	h.View.Page(w, r, http.StatusOK, "participant/event", httpx.View{Title: "participant.event_title", Data: d})
}
