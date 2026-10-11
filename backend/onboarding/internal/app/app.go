// Package app wires repositories, services and HTTP handlers together.
package app

import (
	"context"
	"io/fs"
	"log"
	"net/http"
	"time"
	_ "time/tzdata" // the container image has no zoneinfo

	webassets "github.com/Ilij4n/eho/backend/onboarding"
	"github.com/Ilij4n/eho/backend/onboarding/internal/auth"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/fb"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/i18n"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/mail"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reports"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// Deps are the external dependencies: Firebase-backed in production
// (FirebaseDeps), in-memory in tests (MemDeps).
type Deps struct {
	Identity    auth.Identity
	Users       users.Repository
	Events      events.Repository
	Images      events.Images
	Invitations invitations.Repository
	Reviews     reviews.Repository
	Mail        mail.Sender
	Now         func() time.Time
}

// FirebaseDeps uses Firebase Auth, Firestore and Storage (or their emulators).
func FirebaseDeps(cfg config.Config, c *fb.Clients) Deps {
	return Deps{
		Identity:    &auth.FirebaseIdentity{Client: c.Auth, APIKey: cfg.APIKey, EmulatorHost: cfg.AuthEmulator},
		Users:       users.NewFirestoreRepo(c.Firestore),
		Events:      events.NewFirestoreRepo(c.Firestore, Location(cfg)),
		Images:      events.StorageImages{Bucket: c.Bucket},
		Invitations: invitations.NewFirestoreRepo(c.Firestore),
		Reviews:     reviews.NewFirestoreRepo(c.Firestore),
	}
}

// MemDeps keeps everything in memory (tests).
func MemDeps() Deps {
	ev := events.NewMemRepo()
	return Deps{
		Identity:    auth.NewMemIdentity(),
		Users:       users.NewMemRepo(),
		Events:      ev,
		Images:      ev,
		Invitations: invitations.NewMemRepo(),
		Reviews:     reviews.NewMemRepo(),
	}
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

// stats counts invitations and reviews for the organizer's event list.
type stats struct {
	inv invitations.Repository
	rev reviews.Repository
	now func() time.Time
}

func (s stats) EventStats(ctx context.Context, eventID string) (events.Stats, error) {
	var st events.Stats
	invs, err := s.inv.ListByEvent(ctx, eventID)
	if err != nil {
		return st, err
	}
	st.Invited = len(invs)
	for _, inv := range invs {
		switch inv.Status {
		case invitations.StatusAccepted:
			st.Accepted++
		case invitations.StatusDeclined:
			st.Declined++
		}
	}
	revs, err := s.rev.ListByEvent(ctx, eventID)
	if err != nil {
		return st, err
	}
	sum := 0
	for _, r := range revs {
		sum += r.Rating
	}
	if st.Reviews = len(revs); st.Reviews > 0 {
		st.AvgRating = float64(sum) / float64(st.Reviews)
	}
	return st, nil
}

// New builds the full HTTP handler.
func New(cfg config.Config, d Deps) (http.Handler, error) {
	if d.Now == nil {
		d.Now = time.Now
	}
	if d.Mail == nil {
		d.Mail = mail.LogSender{}
	}
	loc := Location(cfg)
	bundle := i18n.New(cfg.Lang)
	view, err := httpx.NewRenderer(webassets.FS, bundle, loc)
	if err != nil {
		return nil, err
	}
	access := events.Access{Events: d.Events, View: view}

	organizerOnly := httpx.RequireRole(string(users.RoleOrganizer))
	participantOnly := httpx.RequireRole(string(users.RoleParticipant))

	mux := http.NewServeMux()
	static, err := fs.Sub(webassets.FS, "static")
	if err != nil {
		return nil, err
	}
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServerFS(static)))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

	authH := auth.NewHandlers(auth.NewService(d.Identity, d.Users), d.Users, view, cfg.CookieSecure)
	authH.Signup = invitations.SignupHook{Repo: d.Invitations, Events: d.Events, Now: d.Now}
	authH.Register(mux)

	users.NewOnboardingHandlers(d.Users, view).Register(mux, participantOnly)

	(&events.Handlers{
		Access: access, Images: d.Images, Stats: stats{inv: d.Invitations, rev: d.Reviews, now: d.Now},
		Loc: loc, MapsKey: cfg.MapsAPIKey, AppURL: cfg.AppURL, Now: d.Now,
		CanViewPlan: invitations.CanViewPlan(d.Invitations),
	}).Register(mux, organizerOnly)

	(&invitations.Handlers{
		Access: access, Repo: d.Invitations, Mail: d.Mail, BaseURL: cfg.BaseURL,
		Loc: loc, MapsKey: cfg.MapsAPIKey, AppURL: cfg.AppURL, Now: d.Now,
	}).Register(mux, organizerOnly, participantOnly)

	(&reviews.Handlers{
		Repo: d.Reviews, Events: d.Events, Invitations: d.Invitations, View: view, Loc: loc, Now: d.Now,
	}).Register(mux, participantOnly)

	(&reports.Handlers{
		Access: access, Invitations: d.Invitations, Reviews: d.Reviews,
		Summarizer: reports.StatSummarizer{T: bundle.T, Rating: bundle.Rating}, Loc: loc, Now: d.Now,
	}).Register(mux, organizerOnly)

	var h http.Handler = mux
	h = authH.LoadPrincipal(h)
	h = httpx.CSRF(cfg.CookieSecure)(h)
	h = httpx.SecurityHeaders(h)
	h = httpx.Recover(h)
	return h, nil
}
