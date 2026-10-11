// Package app wires repositories, services and HTTP handlers together.
package app

import (
	"database/sql"
	"io/fs"
	"log"
	"net/http"
	"time"
	_ "time/tzdata" // the container image has no zoneinfo

	webassets "github.com/Ilij4n/eho/backend/onboarding"
	"github.com/Ilij4n/eho/backend/onboarding/internal/auth"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/i18n"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/mail"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reports"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// Options override defaults (used by tests).
type Options struct {
	Now  func() time.Time
	Mail mail.Sender
}

// Location resolves cfg.Timezone, falling back to UTC.
func Location(cfg config.Config) *time.Location {
	loc, err := time.LoadLocation(cfg.Timezone)
	if err != nil || cfg.Timezone == "" {
		if cfg.Timezone != "" {
			log.Printf("config: unknown EHO_TIMEZONE %q, using UTC", cfg.Timezone)
		}
		return time.UTC
	}
	return loc
}

// New builds the full HTTP handler for the given config and migrated DB.
func New(cfg config.Config, conn *sql.DB) (http.Handler, error) {
	return NewWithOptions(cfg, conn, Options{})
}

func NewWithOptions(cfg config.Config, conn *sql.DB, opt Options) (http.Handler, error) {
	if opt.Now == nil {
		opt.Now = time.Now
	}
	if opt.Mail == nil {
		opt.Mail = mail.LogSender{}
	}
	loc := Location(cfg)
	bundle := i18n.New("sr")
	view, err := httpx.NewRenderer(webassets.FS, bundle, loc)
	if err != nil {
		return nil, err
	}

	userRepo := users.NewSQLiteRepo(conn)
	eventRepo := events.NewSQLiteRepo(conn)
	invRepo := invitations.NewSQLiteRepo(conn)
	reviewRepo := reviews.NewSQLiteRepo(conn)
	access := events.Access{Events: eventRepo, Users: userRepo, View: view}

	organizerOnly := httpx.RequireRole(string(users.RoleOrganizer))
	participantOnly := httpx.RequireRole(string(users.RoleParticipant))

	mux := http.NewServeMux()
	static, err := fs.Sub(webassets.FS, "static")
	if err != nil {
		return nil, err
	}
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

	authSvc := auth.NewService(userRepo, conn)
	authH := auth.NewHandlers(authSvc, userRepo, view, cfg.CookieSecure)
	authH.Signup = invitations.SignupHook{Repo: invRepo, Events: eventRepo, Now: opt.Now}
	authH.Register(mux)

	users.NewOnboardingHandlers(userRepo, view).Register(mux, participantOnly)

	(&events.Handlers{
		Access: access, Loc: loc, UploadDir: cfg.UploadDir, MapsKey: cfg.MapsAPIKey, Now: opt.Now,
		CanViewPlan: invitations.CanViewPlan(invRepo, userRepo),
	}).Register(mux, organizerOnly)

	(&invitations.Handlers{
		Access: access, Repo: invRepo, Mail: opt.Mail, BaseURL: cfg.BaseURL,
		Loc: loc, MapsKey: cfg.MapsAPIKey, Now: opt.Now,
	}).Register(mux, organizerOnly, participantOnly)

	(&reviews.Handlers{
		Repo: reviewRepo, Events: eventRepo, Invitations: invRepo, View: view, Now: opt.Now,
	}).Register(mux, participantOnly)

	(&reports.Handlers{
		Access: access, Invitations: invRepo, Reviews: reviewRepo,
		Summarizer: reports.StatSummarizer{T: bundle.T}, Loc: loc, Now: opt.Now,
	}).Register(mux, organizerOnly)

	var h http.Handler = mux
	h = authH.LoadPrincipal(h)
	h = httpx.CSRF(cfg.CookieSecure)(h)
	h = httpx.SecurityHeaders(h)
	h = httpx.Recover(h)
	return h, nil
}
