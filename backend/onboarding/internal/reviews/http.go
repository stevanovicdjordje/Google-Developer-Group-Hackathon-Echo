package reviews

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
)

// AcceptanceChecker reports whether a participant accepted the invitation.
type AcceptanceChecker interface {
	HasAccepted(eventID, userID string) (bool, error)
}

type Handlers struct {
	Repo        Repository
	Events      events.Repository
	Invitations AcceptanceChecker
	View        *httpx.Renderer
	Now         func() time.Time
}

func (h *Handlers) Register(mux *http.ServeMux, participantOnly func(http.Handler) http.Handler) {
	part := func(f http.HandlerFunc) http.Handler { return participantOnly(httpx.RequireOnboarded(f)) }
	mux.Handle("GET /me/events/{id}/review", part(h.form))
	mux.Handle("POST /me/events/{id}/review", part(h.submit))
}

type formData struct {
	Event    events.Event
	Sessions []events.Session
	Existing bool
	Problem  string
}

// load returns the event and its sessions if the participant may review it.
// ok=false means the response is written.
func (h *Handlers) load(w http.ResponseWriter, r *http.Request) (events.Event, []events.Session, bool) {
	p := httpx.PrincipalFrom(r.Context())
	ev, err := h.Events.Get(r.PathValue("id"))
	if err != nil {
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return ev, nil, false
	}
	accepted, err := h.Invitations.HasAccepted(ev.ID, p.UserID)
	if err != nil {
		h.View.Error(w, r, http.StatusInternalServerError, "error.title")
		return ev, nil, false
	}
	switch err := CanReview(ev, accepted, h.Now()); {
	case errors.Is(err, ErrNotAllowed):
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return ev, nil, false
	case errors.Is(err, ErrNotFinished):
		h.View.Page(w, r, http.StatusConflict, "reviews/form", httpx.View{Title: "review.title",
			Data: formData{Event: ev, Problem: "review.not_finished"}})
		return ev, nil, false
	}
	sessions, err := h.Events.ListSessions(ev.ID)
	if err != nil {
		h.View.Error(w, r, http.StatusInternalServerError, "error.title")
		return ev, nil, false
	}
	return ev, sessions, true
}

func (h *Handlers) form(w http.ResponseWriter, r *http.Request) {
	ev, sessions, ok := h.load(w, r)
	if !ok {
		return
	}
	p := httpx.PrincipalFrom(r.Context())
	form := map[string][]string{}
	existing := false
	if rv, err := h.Repo.Get(ev.ID, p.UserID); err == nil {
		existing = true
		form["rating"] = []string{strconv.Itoa(rv.Rating)}
		form["comment"] = []string{rv.Comment}
		if rv.Anonymous {
			form["anonymous"] = []string{"on"}
		}
		for sid, n := range rv.SessionRatings {
			form["s_"+sid] = []string{strconv.Itoa(n)}
		}
	} else if !errors.Is(err, ErrNotFound) {
		h.View.Error(w, r, http.StatusInternalServerError, "error.title")
		return
	}
	h.View.Page(w, r, http.StatusOK, "reviews/form", httpx.View{Title: "review.title", Form: form,
		Data: formData{Event: ev, Sessions: sessions, Existing: existing}})
}

func (h *Handlers) submit(w http.ResponseWriter, r *http.Request) {
	ev, sessions, ok := h.load(w, r)
	if !ok {
		return
	}
	p := httpx.PrincipalFrom(r.Context())
	in := Input{Rating: r.PostFormValue("rating"), Comment: r.PostFormValue("comment"),
		Anonymous: r.PostFormValue("anonymous") == "on", SessionRatings: map[string]string{}}
	for _, s := range sessions {
		in.SessionRatings[s.ID] = r.PostFormValue("s_" + s.ID)
	}
	rv, errs := Parse(in, sessions)
	if errs != nil {
		h.View.Page(w, r, http.StatusUnprocessableEntity, "reviews/form", httpx.View{Title: "review.title",
			Form: r.PostForm, Errors: errs, Data: formData{Event: ev, Sessions: sessions}})
		return
	}
	now := h.Now().UTC()
	rv.ID, rv.EventID, rv.UserID, rv.CreatedAt, rv.UpdatedAt = id.New(), ev.ID, p.UserID, now, now
	if err := h.Repo.Save(rv); err != nil {
		h.View.Error(w, r, http.StatusInternalServerError, "error.title")
		return
	}
	http.Redirect(w, r, "/me/events/"+ev.ID+"?ok=review", http.StatusSeeOther)
}
