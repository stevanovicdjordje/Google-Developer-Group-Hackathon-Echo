package invitations

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/mail"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

type Handlers struct {
	events.Access
	Repo    Repository
	Mail    mail.Sender
	BaseURL string
	Loc     *time.Location
	MapsKey string
	Now     func() time.Time
}

func (h *Handlers) Register(mux *http.ServeMux, organizerOnly, participantOnly func(http.Handler) http.Handler) {
	mux.Handle("GET /org/events/{id}/invitations", organizerOnly(http.HandlerFunc(h.orgList)))
	mux.Handle("POST /org/events/{id}/invitations", organizerOnly(http.HandlerFunc(h.orgAdd)))

	mux.HandleFunc("GET /i/{token}", h.show)
	mux.HandleFunc("POST /i/{token}/accept", h.accept)
	mux.HandleFunc("POST /i/{token}/decline", h.decline)

	part := func(f http.HandlerFunc) http.Handler { return participantOnly(httpx.RequireOnboarded(f)) }
	mux.Handle("GET /me/events", part(h.myEvents))
	mux.Handle("GET /me/events/{id}", part(h.myEvent))
}

func (h *Handlers) link(token string) string {
	return strings.TrimRight(h.BaseURL, "/") + "/i/" + token
}

// ---- organizer: wizard step 4 ----

type orgRow struct {
	Invitation
	Effective Status
	Link      string
}

type addResult struct {
	Added      int
	Duplicates int
	Invalid    []string
}

type orgData struct {
	Event    events.Event
	Step     string
	Now      time.Time
	Rows     []orgRow
	Filter   string
	Statuses []Status
	Counts   map[Status]int
	Total    int
	Result   *addResult
}

func (h *Handlers) renderOrg(w http.ResponseWriter, r *http.Request, status int, ev events.Event, res *addResult, form map[string][]string) {
	all, err := h.Repo.ListByEvent(ev.ID)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	now := h.Now()
	filter, _ := ParseStatus(r.URL.Query().Get("status"))
	d := orgData{Event: ev, Step: "invitations", Now: now, Filter: string(filter), Statuses: Statuses,
		Counts: map[Status]int{}, Total: len(all), Result: res}
	for _, inv := range all {
		eff := inv.Effective(ev, now)
		d.Counts[eff]++
		if filter == "" || eff == filter {
			d.Rows = append(d.Rows, orgRow{Invitation: inv, Effective: eff, Link: h.link(inv.Token)})
		}
	}
	h.View.Page(w, r, status, "invitations/organizer", httpx.View{Title: "wizard.invitations", Form: form, Data: d})
}

func (h *Handlers) orgList(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	h.renderOrg(w, r, http.StatusOK, ev, nil, nil)
}

func (h *Handlers) orgAdd(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	now := h.Now()
	if !ev.Editable(now) {
		http.Redirect(w, r, "/org/events/"+ev.ID+"/report", http.StatusSeeOther)
		return
	}
	valid, invalid := ParseEmails(r.PostFormValue("emails"))
	if len(valid)+len(invalid) == 0 {
		h.renderOrg(w, r, http.StatusUnprocessableEntity, ev, &addResult{}, r.PostForm)
		return
	}
	if len(valid) > MaxBatch {
		valid = valid[:MaxBatch]
	}
	res := &addResult{Invalid: invalid}
	for _, email := range valid {
		inv := Invitation{ID: id.New(), EventID: ev.ID, Email: email, Token: id.Token(24),
			Status: StatusSent, ExpiresAt: now.Add(TTL).UTC(), CreatedAt: now.UTC()}
		switch err := h.Repo.Create(inv); {
		case errors.Is(err, ErrDuplicate):
			res.Duplicates++
			continue
		case err != nil:
			h.Fail(w, r, err)
			return
		}
		res.Added++
		if err := h.Mail.SendInvitation(r.Context(), mail.Invitation{To: email, EventTitle: ev.Title, Link: h.link(inv.Token)}); err != nil {
			// The invitation exists and its link is shown in the UI; sending can be retried by copying it.
			h.Fail(w, r, err)
			return
		}
	}
	var form map[string][]string
	if len(invalid) > 0 {
		form = map[string][]string{"emails": {strings.Join(invalid, "\n")}}
	}
	h.renderOrg(w, r, http.StatusOK, ev, res, form)
}

// ---- public invitation link ----

type publicData struct {
	Invitation Invitation
	Event      events.Event
	Effective  Status
	Problem    string // i18n key when the visitor cannot respond
	MapEmbed   string
}

func problemKey(err error) string {
	switch {
	case errors.Is(err, ErrNotOpen):
		return "invite.not_open"
	case errors.Is(err, ErrExpired):
		return "invite.expired"
	case errors.Is(err, ErrTaken):
		return "invite.taken"
	}
	return ""
}

func (h *Handlers) load(w http.ResponseWriter, r *http.Request) (Invitation, events.Event, bool) {
	inv, err := h.Repo.GetByToken(r.PathValue("token"))
	if errors.Is(err, ErrNotFound) {
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return Invitation{}, events.Event{}, false
	}
	if err != nil {
		h.Fail(w, r, err)
		return Invitation{}, events.Event{}, false
	}
	ev, err := h.Events.Get(inv.EventID)
	if err != nil {
		h.Fail(w, r, err)
		return Invitation{}, events.Event{}, false
	}
	return inv, ev, true
}

func (h *Handlers) show(w http.ResponseWriter, r *http.Request) {
	inv, ev, ok := h.load(w, r)
	if !ok {
		return
	}
	now := h.Now()
	userID := ""
	if p := httpx.PrincipalFrom(r.Context()); p != nil && p.Role == string(users.RoleParticipant) {
		userID = p.UserID
	}
	d := publicData{Invitation: inv, Event: ev, Effective: inv.Effective(ev, now),
		Problem: problemKey(CheckRespond(inv, ev, userID, now))}
	if d.Problem != "invite.not_open" {
		d.MapEmbed = events.MapEmbedURL(h.MapsKey, ev)
	}
	h.View.Page(w, r, http.StatusOK, "invitations/public", httpx.View{Title: "invite.title", Data: d})
}

func (h *Handlers) accept(w http.ResponseWriter, r *http.Request) {
	inv, ev, ok := h.load(w, r)
	if !ok {
		return
	}
	p := httpx.PrincipalFrom(r.Context())
	if p == nil || p.Role != string(users.RoleParticipant) {
		// Accepting needs a participant account; the page offers register/login.
		http.Redirect(w, r, "/i/"+inv.Token, http.StatusSeeOther)
		return
	}
	now := h.Now()
	if err := CheckRespond(inv, ev, p.UserID, now); err != nil {
		http.Redirect(w, r, "/i/"+inv.Token, http.StatusSeeOther)
		return
	}
	if err := h.Repo.Respond(inv.ID, p.UserID, StatusAccepted, now.UTC()); err != nil {
		h.Fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/me/events/"+ev.ID+"?ok=accepted", http.StatusSeeOther)
}

func (h *Handlers) decline(w http.ResponseWriter, r *http.Request) {
	inv, ev, ok := h.load(w, r)
	if !ok {
		return
	}
	userID := ""
	if p := httpx.PrincipalFrom(r.Context()); p != nil && p.Role == string(users.RoleParticipant) {
		userID = p.UserID
	}
	now := h.Now()
	if inv.UserID != "" && userID == "" {
		// A bound invitation can only be changed by its owner.
		http.Redirect(w, r, "/i/"+inv.Token, http.StatusSeeOther)
		return
	}
	if err := CheckRespond(inv, ev, userID, now); err == nil {
		if err := h.Repo.Respond(inv.ID, userID, StatusDeclined, now.UTC()); err != nil {
			h.Fail(w, r, err)
			return
		}
	}
	http.Redirect(w, r, "/i/"+inv.Token+"?ok=declined", http.StatusSeeOther)
}

// ---- auth.SignupHook ----

// SignupHook binds the invitation a participant registered from.
type SignupHook struct {
	Repo   Repository
	Events events.Repository
	Now    func() time.Time
}

func (s SignupHook) InviteEmail(token string) (string, bool) {
	inv, err := s.Repo.GetByToken(token)
	if err != nil {
		return "", false
	}
	return inv.Email, true
}

func (s SignupHook) AcceptAfterSignup(_ context.Context, token, userID string) error {
	inv, err := s.Repo.GetByToken(token)
	if err != nil {
		return err
	}
	ev, err := s.Events.Get(inv.EventID)
	if err != nil {
		return err
	}
	now := s.Now()
	if err := CheckRespond(inv, ev, userID, now); err != nil {
		return err
	}
	return s.Repo.Respond(inv.ID, userID, StatusAccepted, now.UTC())
}

// CanViewPlan: the owning organizer, or a participant who accepted an
// invitation to a published event.
func CanViewPlan(repo Repository, usersRepo users.Repository) func(*httpx.Principal, events.Event) bool {
	return func(p *httpx.Principal, ev events.Event) bool {
		if events.IsOrganizerOf(usersRepo, p, ev) {
			return true
		}
		if p.Role != string(users.RoleParticipant) || ev.PublishedAt == nil {
			return false
		}
		ok, err := repo.HasAccepted(ev.ID, p.UserID)
		return err == nil && ok
	}
}
