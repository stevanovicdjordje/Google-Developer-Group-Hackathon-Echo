package auth

import (
	"context"
	"errors"
	"log"
	"net/http"
	"net/url"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

const sessionCookie = "eho_session"

// SignupHook lets the invitations domain bind an invitation to a participant
// who registered from an invitation link, without auth importing it.
type SignupHook interface {
	InviteEmail(ctx context.Context, token string) (string, bool)
	AcceptAfterSignup(ctx context.Context, token, userID string) error
}

type Handlers struct {
	svc    *Service
	users  users.Repository
	view   *httpx.Renderer
	secure bool
	Signup SignupHook
}

func NewHandlers(svc *Service, repo users.Repository, view *httpx.Renderer, secureCookies bool) *Handlers {
	return &Handlers{svc: svc, users: repo, view: view, secure: secureCookies}
}

func (h *Handlers) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /{$}", h.landing)
	mux.HandleFunc("GET /login", h.loginForm)
	mux.HandleFunc("POST /login", h.loginSubmit)
	mux.HandleFunc("POST /logout", h.logout)
	mux.HandleFunc("GET /register/organizer", h.organizerForm)
	mux.HandleFunc("POST /register/organizer", h.organizerSubmit)
	mux.HandleFunc("GET /register/participant", h.participantForm)
	mux.HandleFunc("POST /register/participant", h.participantSubmit)
}

// LoadPrincipal resolves the session cookie (if any) into the request context.
func (h *Handlers) LoadPrincipal(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if c, err := r.Cookie(sessionCookie); err == nil && c.Value != "" {
			claims, err := h.svc.Verify(r.Context(), c.Value)
			switch {
			case err == nil:
				p := &httpx.Principal{UserID: claims.UID, Name: claims.Name, Email: claims.Email,
					Role: string(claims.Role), Onboarded: true}
				if p.Name == "" {
					p.Name = claims.Email
				}
				if claims.Role == users.RoleParticipant {
					prof, err := h.users.GetProfile(r.Context(), claims.UID)
					p.Onboarded = err == nil && prof.Completed()
				}
				r = r.WithContext(httpx.WithPrincipal(r.Context(), p))
			case errors.Is(err, ErrInvalidSession):
				h.clearCookie(w)
			default:
				log.Printf("auth: session check: %v", err)
			}
		}
		next.ServeHTTP(w, r)
	})
}

// HomePath is where a signed-in principal lands.
func HomePath(p *httpx.Principal) string {
	switch {
	case p == nil:
		return "/login"
	case p.Role == string(users.RoleOrganizer):
		return "/org/events"
	case !p.Onboarded:
		return "/onboarding"
	default:
		return "/me/events"
	}
}

func (h *Handlers) landing(w http.ResponseWriter, r *http.Request) {
	if p := httpx.PrincipalFrom(r.Context()); p != nil {
		http.Redirect(w, r, HomePath(p), http.StatusSeeOther)
		return
	}
	h.view.Page(w, r, http.StatusOK, "landing", httpx.View{Title: "landing.title"})
}

func (h *Handlers) setSession(w http.ResponseWriter, r *http.Request, email, password string) error {
	value, exp, err := h.svc.StartSession(r.Context(), email, password)
	if err != nil {
		return err
	}
	http.SetCookie(w, &http.Cookie{
		Name: sessionCookie, Value: value, Path: "/", Expires: exp,
		HttpOnly: true, Secure: h.secure, SameSite: http.SameSiteLaxMode,
	})
	return nil
}

func (h *Handlers) clearCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name: sessionCookie, Value: "", Path: "/", Expires: time.Unix(0, 0), MaxAge: -1,
		HttpOnly: true, Secure: h.secure, SameSite: http.SameSiteLaxMode,
	})
}

func (h *Handlers) fail(w http.ResponseWriter, r *http.Request, err error) {
	log.Printf("auth: %v", err)
	h.view.Error(w, r, http.StatusInternalServerError, "error.title")
}

func (h *Handlers) loginForm(w http.ResponseWriter, r *http.Request) {
	if p := httpx.PrincipalFrom(r.Context()); p != nil {
		http.Redirect(w, r, HomePath(p), http.StatusSeeOther)
		return
	}
	h.view.Page(w, r, http.StatusOK, "auth/login",
		httpx.View{Title: "login.title", Form: url.Values{"next": {r.URL.Query().Get("next")}}})
}

func (h *Handlers) loginSubmit(w http.ResponseWriter, r *http.Request) {
	err := h.setSession(w, r, r.PostFormValue("email"), r.PostFormValue("password"))
	if errors.Is(err, ErrInvalidCredentials) || errors.Is(err, ErrTooManyAttempts) {
		key := "err.credentials"
		if errors.Is(err, ErrTooManyAttempts) {
			key = "err.too_many_attempts"
		}
		form := url.Values{"email": {r.PostFormValue("email")}, "next": {r.PostFormValue("next")}}
		h.view.Page(w, r, http.StatusUnauthorized, "auth/login", httpx.View{
			Title: "login.title", Form: form, Errors: map[string]string{"_form": key}})
		return
	}
	if err != nil {
		h.fail(w, r, err)
		return
	}
	http.Redirect(w, r, httpx.SafeNext(r.PostFormValue("next"), "/"), http.StatusSeeOther)
}

func (h *Handlers) logout(w http.ResponseWriter, r *http.Request) {
	// The session cookie is only dropped here; revoking refresh tokens would
	// also sign the user out of the Flutter app.
	h.clearCookie(w)
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func (h *Handlers) organizerForm(w http.ResponseWriter, r *http.Request) {
	h.view.Page(w, r, http.StatusOK, "auth/register_organizer", httpx.View{Title: "reg.organizer.title"})
}

func (h *Handlers) organizerSubmit(w http.ResponseWriter, r *http.Request) {
	in := OrganizerInput{
		FullName: r.PostFormValue("full_name"), Email: r.PostFormValue("email"),
		Password: r.PostFormValue("password"), PasswordConfirm: r.PostFormValue("password_confirm"),
		OrgName: r.PostFormValue("org_name"), Website: r.PostFormValue("website"),
	}
	_, err := h.svc.RegisterOrganizer(r.Context(), in)
	if h.formError(w, r, err, "auth/register_organizer", "reg.organizer.title") {
		return
	}
	if err := h.setSession(w, r, in.Email, in.Password); err != nil {
		h.fail(w, r, err)
		return
	}
	http.Redirect(w, r, "/org/events", http.StatusSeeOther)
}

func (h *Handlers) participantForm(w http.ResponseWriter, r *http.Request) {
	form := url.Values{}
	if tok := r.URL.Query().Get("invite"); tok != "" && h.Signup != nil {
		if email, ok := h.Signup.InviteEmail(r.Context(), tok); ok {
			form.Set("invite", tok)
			form.Set("email", email)
		}
	}
	h.view.Page(w, r, http.StatusOK, "auth/register_participant", httpx.View{Title: "reg.participant.title", Form: form})
}

func (h *Handlers) participantSubmit(w http.ResponseWriter, r *http.Request) {
	in := ParticipantInput{
		FullName: r.PostFormValue("full_name"), Email: r.PostFormValue("email"),
		Password: r.PostFormValue("password"), PasswordConfirm: r.PostFormValue("password_confirm"),
	}
	u, err := h.svc.RegisterParticipant(r.Context(), in)
	if h.formError(w, r, err, "auth/register_participant", "reg.participant.title") {
		return
	}
	if err := h.setSession(w, r, in.Email, in.Password); err != nil {
		h.fail(w, r, err)
		return
	}
	if tok := r.PostFormValue("invite"); tok != "" && h.Signup != nil {
		// The account exists already; a failed binding must not block onboarding.
		if err := h.Signup.AcceptAfterSignup(r.Context(), tok, u.ID); err != nil {
			log.Printf("auth: bind invitation after signup: %v", err)
		}
	}
	http.Redirect(w, r, "/onboarding", http.StatusSeeOther)
}

// formError re-renders the form when err is a validation error (or fails the
// request for anything else). It reports whether the request was handled.
func (h *Handlers) formError(w http.ResponseWriter, r *http.Request, err error, page, title string) bool {
	if err == nil {
		return false
	}
	var fe FieldErrors
	if errors.As(err, &fe) {
		form := url.Values{}
		for k, v := range r.PostForm {
			if k != "password" && k != "password_confirm" && k != "csrf_token" {
				form[k] = v
			}
		}
		h.view.Page(w, r, http.StatusUnprocessableEntity, page,
			httpx.View{Title: title, Form: form, Errors: fe})
		return true
	}
	h.fail(w, r, err)
	return true
}
