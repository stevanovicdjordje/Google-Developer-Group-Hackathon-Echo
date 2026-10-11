package app_test

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/fb"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
)

// TestAgainstEmulators runs the main flow against the Firebase emulators
// started by backend/maps (`make dev`). It is skipped when they aren't
// configured: FIRESTORE_EMULATOR_HOST=127.0.0.1:8081
// FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199
func TestAgainstEmulators(t *testing.T) {
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" || os.Getenv("FIREBASE_AUTH_EMULATOR_HOST") == "" {
		t.Skip("Firebase emulators not configured")
	}
	ctx := context.Background()
	cfg := config.Load()
	cfg.BaseURL, cfg.AppURL, cfg.Lang = "http://eho.test", "http://app.test", "sr"
	clients, err := fb.New(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer clients.Close()
	deps := app.FirebaseDeps(cfg, clients)
	h, err := app.New(cfg, deps)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	defer srv.Close()

	run := fmt.Sprintf("%d", time.Now().UnixNano())
	org := newClient(t, srv)
	registerOrganizer(org, "org-"+run+"@eho.test")

	// Real Firebase session: the list page loads for the new organizer.
	res, body := org.get("/org/events")
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Još nemate evente")

	// Create an event and a session; both land in the shared documents.
	day := time.Now().In(app.Location(cfg)).AddDate(0, 0, 3)
	at := func(h int) string {
		return time.Date(day.Year(), day.Month(), day.Day(), h, 0, 0, 0, app.Location(cfg)).Format("2006-01-02T15:04")
	}
	res, _ = org.post("/org/events/new", "/org/events/new", url.Values{"title": {"Emulator test " + run},
		"starts_at": {at(9)}, "ends_at": {at(17)}, "address": {"Test 1"}, "action": {"next"}})
	expect(t, res, http.StatusSeeOther, "")
	evID := strings.Split(res.Header.Get("Location"), "/")[3]
	base := "/org/events/" + evID
	res, _ = org.post(base+"/schedule", base+"/sessions", url.Values{"title": {"Uvod"}, "stage_new": {"Glavna sala"},
		"speaker": {"Ana Demić"}, "starts_at": {at(10)}, "ends_at": {at(11)}})
	expect(t, res, http.StatusSeeOther, "")

	snap, err := clients.Firestore.Collection("events").Doc(evID).Get(ctx)
	if err != nil {
		t.Fatal(err)
	}
	data := snap.Data()
	if data["name"] != "Emulator test "+run || data["startDate"] != day.Format("2006-01-02") || data["ownerUid"] == "" {
		t.Fatalf("shared event doc: %v", data)
	}
	if _, err := clients.Firestore.Collection("events").Doc(evID).Collection("draft").Doc("map").Get(ctx); err != nil {
		t.Fatalf("draft/map for the map editor: %v", err)
	}
	ag, err := clients.Firestore.Collection("events").Doc(evID).Collection("published").Doc("agenda").Get(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if s := ag.Data()["sessions"].([]any); len(s) != 1 || s[0].(map[string]any)["start"] != "10:00" {
		t.Fatalf("agenda: %v", ag.Data())
	}

	// Invite, publish, register from the invite: membership for the app's "My events".
	res, _ = org.post(base+"/invitations", base+"/invitations", url.Values{"emails": {"p-" + run + "@eho.test"}})
	expect(t, res, http.StatusOK, "")
	res, _ = org.post(base+"/publish", base+"/publish", url.Values{})
	expect(t, res, http.StatusSeeOther, "/org/events?ok=published")
	invs, err := deps.Invitations.ListByEvent(ctx, evID)
	if err != nil || len(invs) != 1 {
		t.Fatalf("invitations %v %v", invs, err)
	}
	p := newClient(t, srv)
	res, _ = p.post("/register/participant", "/register/participant", url.Values{"full_name": {"Pera Test"},
		"email": {"p-" + run + "@eho.test"}, "password": {"lozinka123"}, "password_confirm": {"lozinka123"},
		"invite": {invs[0].Token}})
	expect(t, res, http.StatusSeeOther, "/onboarding")
	completeOnboarding(p)
	res, body = p.get("/me/events/" + evID)
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Uvod", "Glavna sala")
	inv, _ := deps.Invitations.GetByToken(ctx, invs[0].Token)
	if inv.Status != invitations.StatusAccepted || inv.UserID == "" {
		t.Fatalf("invitation %+v", inv)
	}
	if _, err := clients.Firestore.Collection("members").Doc(inv.UserID).Collection("events").Doc(evID).Get(ctx); err != nil {
		t.Fatalf("members entry: %v", err)
	}

	// Organizer and participant can't cross roles; login with a wrong password fails.
	res, _ = p.get("/org/events")
	expect(t, res, http.StatusForbidden, "")
	bad := newClient(t, srv)
	res, _ = bad.post("/login", "/login", url.Values{"email": {"p-" + run + "@eho.test"}, "password": {"pogresna-lozinka"}})
	expect(t, res, http.StatusUnauthorized, "")

	// The colleagues' demo event (backend/maps `make seed`) reads fine, with its map and floor image.
	dev, err := deps.Events.Get(ctx, "devfest")
	if err != nil {
		t.Skipf("devfest demo event not seeded (%v); the rest passed", err)
	}
	if !dev.Published() || dev.StartsAt == nil {
		t.Fatalf("devfest: %+v", dev)
	}
	m, err := deps.Events.GetPublishedMap(ctx, "devfest")
	if err != nil || m.Empty() || len(m.RoomNames()) == 0 {
		t.Fatalf("devfest map: %v %+v", err, m)
	}
	rd, ctype, err := deps.Images.FloorImage(ctx, m.Floors[0].ImagePath)
	if err != nil {
		t.Fatalf("floor image: %v", err)
	}
	b, _ := io.ReadAll(rd)
	rd.Close()
	if len(b) < 100 || !strings.HasPrefix(ctype, "image/") {
		t.Fatalf("floor image: %d bytes, %q", len(b), ctype)
	}
	a, err := deps.Events.GetAgenda(ctx, "devfest")
	if err != nil || len(a.SessionList(app.Location(cfg))) == 0 {
		t.Fatalf("devfest agenda: %v %+v", err, a)
	}
}
