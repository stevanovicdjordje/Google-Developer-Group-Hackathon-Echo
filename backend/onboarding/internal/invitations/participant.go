package invitations

import (
	"errors"
	"net/http"
	"sort"
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
	u, err := h.Users.GetByID(p.UserID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	invs, err := h.Repo.ListForParticipant(u.ID, u.Email)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	now := h.Now()
	d := myEventsData{Now: now}
	for _, inv := range invs {
		ev, err := h.Events.Get(inv.EventID)
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
	HasMap   bool
	Plan     events.PlanView
	Zone     *events.Zone
	ZoneSess []events.Session
	Schedule any
}

func (h *Handlers) myEvent(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	ev, err := h.Events.Get(r.PathValue("id"))
	if err != nil && !errors.Is(err, events.ErrNotFound) {
		h.Fail(w, r, err)
		return
	}
	accepted := false
	if err == nil && ev.PublishedAt != nil {
		if accepted, err = h.Repo.HasAccepted(ev.ID, p.UserID); err != nil {
			h.Fail(w, r, err)
			return
		}
	}
	if !accepted {
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return
	}
	sched, err := events.LoadSchedule(h.Events, ev, h.Loc)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	zones, err := h.Events.ListZones(ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	d := myEventData{Event: ev, Status: ev.Status(h.Now()), MapEmbed: events.MapEmbedURL(h.MapsKey, ev), Schedule: sched}
	selected := r.URL.Query().Get("zone")
	if m, err := h.Events.GetVenueMap(ev.ID); err == nil {
		d.HasMap = true
		d.Plan = events.NewPlanView(m, zones, "/me/events/"+ev.ID+"?zone=", selected)
	}
	for i := range zones {
		if zones[i].ID == selected {
			d.Zone = &zones[i]
		}
	}
	if d.Zone != nil {
		for _, s := range sched.Sessions {
			if s.ZoneID == d.Zone.ID {
				d.ZoneSess = append(d.ZoneSess, s)
			}
		}
	}
	h.View.Page(w, r, http.StatusOK, "participant/event", httpx.View{Title: "participant.event_title", Data: d})
}
