package users

import (
	"errors"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
)

// OnboardingHandlers serve the 5-step participant onboarding.
type OnboardingHandlers struct {
	repo Repository
	view *httpx.Renderer
	now  func() time.Time
}

func NewOnboardingHandlers(repo Repository, view *httpx.Renderer) *OnboardingHandlers {
	return &OnboardingHandlers{repo: repo, view: view, now: time.Now}
}

// Register mounts routes; the caller wraps mux with role middleware.
func (h *OnboardingHandlers) Register(mux *http.ServeMux, participantOnly func(http.Handler) http.Handler) {
	wrap := func(f http.HandlerFunc) http.Handler { return participantOnly(f) }
	mux.Handle("GET /onboarding", wrap(h.index))
	mux.Handle("GET /onboarding/{n}", wrap(h.show))
	mux.Handle("POST /onboarding/{n}", wrap(h.submit))
	mux.Handle("GET /me/profile", participantOnly(httpx.RequireOnboarded(http.HandlerFunc(h.profileForm))))
	mux.Handle("POST /me/profile", participantOnly(httpx.RequireOnboarded(http.HandlerFunc(h.profileSubmit))))
}

type stepData struct {
	Step      int
	Total     int
	Languages []string
	Topics    []string
	Goals     []Goal
	Profile   Profile
}

func (h *OnboardingHandlers) profile(w http.ResponseWriter, r *http.Request) (Profile, bool) {
	p := httpx.PrincipalFrom(r.Context())
	prof, err := h.repo.GetProfile(r.Context(), p.UserID)
	if err != nil {
		log.Printf("onboarding: load profile: %v", err)
		h.view.Error(w, r, http.StatusInternalServerError, "error.title")
		return Profile{}, false
	}
	return prof, true
}

func (h *OnboardingHandlers) index(w http.ResponseWriter, r *http.Request) {
	prof, ok := h.profile(w, r)
	if !ok {
		return
	}
	if prof.Completed() {
		http.Redirect(w, r, "/me/events", http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, "/onboarding/"+strconv.Itoa(prof.OnboardingStep), http.StatusSeeOther)
}

// step parses {n} and enforces that a step is reachable. ok=false means the
// response was already written.
func (h *OnboardingHandlers) step(w http.ResponseWriter, r *http.Request) (int, Profile, bool) {
	prof, ok := h.profile(w, r)
	if !ok {
		return 0, prof, false
	}
	if prof.Completed() {
		http.Redirect(w, r, "/me/events", http.StatusSeeOther)
		return 0, prof, false
	}
	n, err := strconv.Atoi(r.PathValue("n"))
	if err != nil || n < 1 || n > OnboardingSteps {
		h.view.Error(w, r, http.StatusNotFound, "error.title")
		return 0, prof, false
	}
	if n > prof.OnboardingStep {
		http.Redirect(w, r, "/onboarding/"+strconv.Itoa(prof.OnboardingStep), http.StatusSeeOther)
		return 0, prof, false
	}
	return n, prof, true
}

func (h *OnboardingHandlers) render(w http.ResponseWriter, r *http.Request, status, n int, prof Profile, form url.Values, errs map[string]string) {
	if form == nil {
		form = url.Values{}
		switch n {
		case 1:
			form.Set("language", prof.CaptionLanguage)
		case 2:
			form["interests"] = prof.Interests
		case 3:
			form.Set("goal", string(prof.Goal))
		case 4:
			if prof.Visible {
				form.Set("visible", "on")
			}
		}
	}
	h.view.Page(w, r, status, "onboarding/step", httpx.View{
		Title: "onboarding.title", Form: form, Errors: errs,
		Data: stepData{Step: n, Total: OnboardingSteps, Languages: Languages,
			Topics: Topics, Goals: Goals, Profile: prof},
	})
}

func (h *OnboardingHandlers) show(w http.ResponseWriter, r *http.Request) {
	n, prof, ok := h.step(w, r)
	if !ok {
		return
	}
	h.render(w, r, http.StatusOK, n, prof, nil, nil)
}

func (h *OnboardingHandlers) submit(w http.ResponseWriter, r *http.Request) {
	n, prof, ok := h.step(w, r)
	if !ok {
		return
	}
	bad := func(field, key string) {
		h.render(w, r, http.StatusUnprocessableEntity, n, prof, r.PostForm, map[string]string{field: key})
	}
	consented := false
	switch n {
	case 1:
		lang := r.PostFormValue("language")
		if !ValidLanguage(lang) {
			bad("language", "err.language")
			return
		}
		prof.CaptionLanguage = lang
	case 2:
		all, custom, err := ParseInterests(r.PostForm["interests"], r.PostFormValue("custom"))
		if err != nil {
			bad("interests", err.Error())
			return
		}
		prof.Interests, prof.CustomInterests = all, custom
	case 3:
		g := Goal(r.PostFormValue("goal"))
		if !g.Valid() {
			bad("goal", "err.goal")
			return
		}
		prof.Goal = g
	case 4:
		// Opt-in: only an explicit "on" makes the profile visible.
		prof.Visible = r.PostFormValue("visible") == "on"
	case 5:
		if r.PostFormValue("gdpr") != "on" {
			bad("gdpr", "err.gdpr")
			return
		}
		consented = true
	}
	if consented {
		if err := h.repo.GrantConsent(r.Context(), prof.UserID, ConsentGDPR, GDPRConsentVersion, h.now().UTC()); err != nil {
			h.internal(w, r, err)
			return
		}
		t := h.now().UTC()
		prof.CompletedAt = &t
		prof.OnboardingStep = OnboardingSteps + 1
	} else if n >= prof.OnboardingStep {
		prof.OnboardingStep = n + 1
	}
	if err := h.repo.SaveProfile(r.Context(), prof); err != nil {
		h.internal(w, r, err)
		return
	}
	next := "/onboarding/" + strconv.Itoa(n+1)
	if consented {
		next = "/me/events"
	}
	http.Redirect(w, r, next, http.StatusSeeOther)
}

func (h *OnboardingHandlers) internal(w http.ResponseWriter, r *http.Request, err error) {
	if !errors.Is(err, ErrNotFound) {
		log.Printf("onboarding: %v", err)
	}
	h.view.Error(w, r, http.StatusInternalServerError, "error.title")
}

// ---- profile settings (same data as onboarding, one form) ----

func profileValues(prof Profile) url.Values {
	f := url.Values{}
	f.Set("language", prof.CaptionLanguage)
	f.Set("goal", string(prof.Goal))
	var offered, custom []string
	isCustom := map[string]bool{}
	for _, c := range prof.CustomInterests {
		isCustom[c] = true
		custom = append(custom, c)
	}
	for _, i := range prof.Interests {
		if !isCustom[i] {
			offered = append(offered, i)
		}
	}
	f["interests"] = offered
	f.Set("custom", strings.Join(custom, ", "))
	if prof.Visible {
		f.Set("visible", "on")
	}
	return f
}

func (h *OnboardingHandlers) renderProfile(w http.ResponseWriter, r *http.Request, status int, prof Profile, form url.Values, errs map[string]string) {
	h.view.Page(w, r, status, "users/profile", httpx.View{
		Title: "profile.title", Form: form, Errors: errs,
		Data: stepData{Languages: Languages, Topics: Topics, Goals: Goals, Profile: prof},
	})
}

func (h *OnboardingHandlers) profileForm(w http.ResponseWriter, r *http.Request) {
	prof, ok := h.profile(w, r)
	if !ok {
		return
	}
	h.renderProfile(w, r, http.StatusOK, prof, profileValues(prof), nil)
}

func (h *OnboardingHandlers) profileSubmit(w http.ResponseWriter, r *http.Request) {
	prof, ok := h.profile(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	lang := r.PostFormValue("language")
	if !ValidLanguage(lang) {
		errs["language"] = "err.language"
	}
	all, custom, err := ParseInterests(r.PostForm["interests"], r.PostFormValue("custom"))
	if err != nil {
		errs["interests"] = err.Error()
	}
	goal := Goal(r.PostFormValue("goal"))
	if !goal.Valid() {
		errs["goal"] = "err.goal"
	}
	if len(errs) > 0 {
		h.renderProfile(w, r, http.StatusUnprocessableEntity, prof, r.PostForm, errs)
		return
	}
	prof.CaptionLanguage, prof.Interests, prof.CustomInterests, prof.Goal = lang, all, custom, goal
	prof.Visible = r.PostFormValue("visible") == "on"
	if err := h.repo.SaveProfile(r.Context(), prof); err != nil {
		h.internal(w, r, err)
		return
	}
	http.Redirect(w, r, "/me/profile?ok=profile", http.StatusSeeOther)
}
