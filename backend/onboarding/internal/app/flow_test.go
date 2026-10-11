package app_test

import (
	"bytes"
	"context"
	"database/sql"
	"image"
	"image/color"
	"image/png"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/db"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
)

func newServerDB(t *testing.T) (*httptest.Server, *sql.DB) {
	t.Helper()
	dir := t.TempDir()
	conn, err := db.Open(context.Background(), filepath.Join(dir, "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	h, err := app.New(config.Config{Timezone: "UTC", UploadDir: filepath.Join(dir, "uploads"), BaseURL: "http://eho.test"}, conn)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return srv, conn
}

func completeOnboarding(c *client) {
	c.t.Helper()
	steps := []url.Values{
		{"language": {"sr"}},
		{"interests": {"ai", "web", "cloud"}},
		{"goal": {"learn"}},
		{},
		{"gdpr": {"on"}},
	}
	for i, form := range steps {
		p := "/onboarding/" + string(rune('1'+i))
		res, _ := c.post(p, p, form)
		if res.StatusCode != http.StatusSeeOther {
			c.t.Fatalf("onboarding step %d: %d", i+1, res.StatusCode)
		}
	}
}

func pngBytes(t *testing.T) []byte {
	img := image.NewRGBA(image.Rect(0, 0, 400, 300))
	for x := 0; x < 400; x++ {
		img.Set(x, 150, color.Black)
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func (c *client) upload(formPath, path, field, filename string, data []byte) *http.Response {
	c.t.Helper()
	_, body := c.get(formPath)
	m := csrfRe.FindStringSubmatch(body)
	if m == nil {
		c.t.Fatalf("no csrf on %s", formPath)
	}
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	mw.WriteField("csrf_token", m[1])
	fw, _ := mw.CreateFormFile(field, filename)
	fw.Write(data)
	mw.Close()
	res, err := c.c.Post(c.srv.URL+path, mw.FormDataContentType(), &buf)
	if err != nil {
		c.t.Fatal(err)
	}
	io.Copy(io.Discard, res.Body)
	res.Body.Close()
	return res
}

func mustContain(t *testing.T, body string, parts ...string) {
	t.Helper()
	for _, p := range parts {
		if !strings.Contains(body, p) {
			t.Errorf("response does not contain %q", p)
		}
	}
}

func TestFullEventLifecycle(t *testing.T) {
	srv, conn := newServerDB(t)
	eventRepo := events.NewSQLiteRepo(conn)
	invRepo := invitations.NewSQLiteRepo(conn)
	dt := func(d time.Duration) string { return time.Now().UTC().Add(d).Format("2006-01-02T15:04") }

	org := newClient(t, srv)
	registerOrganizer(org, "org@primer.rs")

	// Step 1: basics. Location carries the new event ID.
	res, _ := org.post("/org/events/new", "/org/events/new", url.Values{
		"title": {"Go konferencija"}, "starts_at": {dt(48 * time.Hour)}, "ends_at": {dt(56 * time.Hour)},
		"address": {"Bulevar 1, Beograd"}, "action": {"next"},
	})
	expect(t, res, http.StatusSeeOther, "")
	loc := res.Header.Get("Location")
	if !strings.HasSuffix(loc, "/venue") {
		t.Fatalf("Location %q", loc)
	}
	evID := strings.Split(loc, "/")[3]
	base := "/org/events/" + evID

	// Step 2: plan upload (non-image is rejected) and a hall zone.
	expect(t, org.upload(base+"/venue", base+"/venue/plan", "plan", "plan.png", []byte("not an image")), http.StatusUnprocessableEntity, "")
	expect(t, org.upload(base+"/venue", base+"/venue/plan", "plan", "plan.png", pngBytes(t)), http.StatusSeeOther, "")
	res, _ = org.post(base+"/venue", base+"/zones", url.Values{"name": {"Sala A"}, "kind": {"hall"}, "x": {"5"}, "y": {"5"}, "w": {"40"}, "h": {"30"}})
	expect(t, res, http.StatusSeeOther, "")
	zones, _ := eventRepo.ListZones(evID)
	if len(zones) != 1 {
		t.Fatalf("zones = %d", len(zones))
	}
	_, body := org.get(base + "/venue")
	mustContain(t, body, "<svg", "/events/"+evID+"/plan", "Sala A")

	// Step 3: two overlapping sessions in the same hall.
	for _, title := range []string{"Keynote", "Radionica"} {
		res, _ = org.post(base+"/schedule", base+"/sessions", url.Values{"title": {title}, "zone_id": {zones[0].ID},
			"starts_at": {dt(49 * time.Hour)}, "ends_at": {dt(50 * time.Hour)}})
		expect(t, res, http.StatusSeeOther, "")
	}
	_, body = org.get(base + "/schedule")
	mustContain(t, body, "Preklapanje u sali", "Keynote", "Radionica")

	// Step 4: invitations (one invalid address).
	res, body = org.post(base+"/invitations", base+"/invitations", url.Values{"emails": {"p1@primer.rs, p2@primer.rs\nlose"}})
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Dodato pozivnica: 2", "Neispravnih adresa: 1", "http://eho.test/i/")
	invs, _ := invRepo.ListByEvent(evID)
	tokens := map[string]string{}
	for _, inv := range invs {
		tokens[inv.Email] = inv.Token
	}

	// Before publishing, the invitation can't be accepted.
	anon := newClient(t, srv)
	_, body = anon.get("/i/" + tokens["p1@primer.rs"])
	mustContain(t, body, "još nije objavljen")

	// Step 5: publish.
	res, _ = org.post(base+"/publish", base+"/publish", url.Values{})
	expect(t, res, http.StatusSeeOther, "/org/events?ok=published")
	_, body = org.get("/org/events?ok=published")
	mustContain(t, body, "Predstojeći", "Go konferencija", "Event je objavljen.")

	// Participant 1 registers from the invitation link: it is bound automatically.
	p1 := newClient(t, srv)
	_, body = p1.get("/register/participant?invite=" + tokens["p1@primer.rs"])
	mustContain(t, body, `value="p1@primer.rs"`)
	res, _ = p1.post("/register/participant?invite="+tokens["p1@primer.rs"], "/register/participant", url.Values{
		"full_name": {"Petar Petrović"}, "email": {"p1@primer.rs"}, "password": {"lozinka123"},
		"password_confirm": {"lozinka123"}, "invite": {tokens["p1@primer.rs"]},
	})
	expect(t, res, http.StatusSeeOther, "/onboarding")
	completeOnboarding(p1)
	_, body = p1.get("/me/events")
	mustContain(t, body, "Go konferencija", "Predstojeći i u toku")
	res, body = p1.get("/me/events/" + evID)
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Keynote", "Sala A")
	res, _ = p1.get("/events/" + evID + "/plan")
	expect(t, res, http.StatusOK, "")
	if ct := res.Header.Get("Content-Type"); ct != "image/png" {
		t.Errorf("plan content type %q", ct)
	}

	// Participant 2 declines without an account.
	res, _ = anon.post("/i/"+tokens["p2@primer.rs"], "/i/"+tokens["p2@primer.rs"]+"/decline", url.Values{})
	expect(t, res, http.StatusSeeOther, "")
	_, body = org.get(base + "/invitations?status=declined")
	mustContain(t, body, "p2@primer.rs")

	// Role and ownership isolation.
	res, _ = p1.get("/org/events")
	expect(t, res, http.StatusForbidden, "")
	res, _ = p1.get("/org/events/" + evID + "/report")
	expect(t, res, http.StatusForbidden, "")
	other := newClient(t, srv)
	registerOrganizer(other, "drugi@primer.rs")
	for _, p := range []string{base + "/edit", base + "/invitations", base + "/report", base + "/report.csv"} {
		res, _ = other.get(p)
		expect(t, res, http.StatusNotFound, "")
	}
	res, _ = other.get("/events/" + evID + "/plan")
	expect(t, res, http.StatusNotFound, "")
	stranger := newClient(t, srv)
	registerParticipant(stranger, "stranger@primer.rs")
	completeOnboarding(stranger)
	res, _ = stranger.get("/me/events/" + evID)
	expect(t, res, http.StatusNotFound, "")
	res, _ = stranger.get("/events/" + evID + "/plan")
	expect(t, res, http.StatusNotFound, "")

	// No review before the event ends.
	res, _ = p1.get("/me/events/" + evID + "/review")
	expect(t, res, http.StatusConflict, "")

	// Move the event into the past.
	ev, _ := eventRepo.Get(evID)
	s, e := time.Now().UTC().Add(-10*time.Hour), time.Now().UTC().Add(-time.Hour)
	ev.StartsAt, ev.EndsAt = &s, &e
	if err := eventRepo.Update(ev); err != nil {
		t.Fatal(err)
	}

	// Finished events are no longer editable.
	res, _ = org.get(base + "/edit")
	expect(t, res, http.StatusSeeOther, base+"/report")

	// Review (anonymous) with a session rating; then edit it (still one review).
	sessions, _ := eventRepo.ListSessions(evID)
	form := url.Values{"rating": {"3"}, "comment": {"Odlična organizacija"}, "anonymous": {"on"}, "s_" + sessions[0].ID: {"5"}}
	res, _ = p1.post("/me/events/"+evID+"/review", "/me/events/"+evID+"/review", form)
	expect(t, res, http.StatusSeeOther, "/me/events/"+evID+"?ok=review")
	form.Set("rating", "4")
	res, _ = p1.post("/me/events/"+evID+"/review", "/me/events/"+evID+"/review", form)
	expect(t, res, http.StatusSeeOther, "")
	_, body = p1.get("/me/events/" + evID + "/review")
	mustContain(t, body, "Već ste ocenili")

	// A stranger can't review.
	res, _ = stranger.get("/me/events/" + evID + "/review")
	expect(t, res, http.StatusNotFound, "")

	// Report.
	res, body = org.get(base + "/report")
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Ukupan utisak", "4,0", "Anonimno", "Odlična organizacija", "50%")
	if strings.Contains(body, "Petar Petrović") {
		t.Error("anonymous review author leaked in report")
	}
	_, body = org.get("/org/events")
	mustContain(t, body, "Prethodni", "4,0 ★")

	res, body = org.get(base + "/report.csv")
	expect(t, res, http.StatusOK, "")
	if !strings.HasPrefix(res.Header.Get("Content-Type"), "text/csv") {
		t.Errorf("csv content type %q", res.Header.Get("Content-Type"))
	}
	mustContain(t, body, "Odlična organizacija", "session: Keynote")
	if strings.Contains(body, "p1@primer.rs") {
		t.Error("anonymous review author leaked in CSV")
	}
}

func TestEventListSearchAndEmptyState(t *testing.T) {
	srv, _ := newServerDB(t)
	org := newClient(t, srv)
	registerOrganizer(org, "org@primer.rs")
	for _, title := range []string{"Konferencija Čačak", "Meetup Novi Sad"} {
		res, _ := org.post("/org/events/new", "/org/events/new", url.Values{"title": {title}, "action": {"draft"}})
		expect(t, res, http.StatusSeeOther, "/org/events?ok=saved")
	}
	res, _ := org.post("/org/events/new", "/org/events/new", url.Values{"title": {"x"}})
	expect(t, res, http.StatusUnprocessableEntity, "")

	_, body := org.get("/org/events?q=cacak")
	mustContain(t, body, "Konferencija Čačak")
	if strings.Contains(body, "Meetup Novi Sad") {
		t.Error("search did not filter")
	}
	_, body = org.get("/org/events?status=finished")
	mustContain(t, body, "Nema eventova koji odgovaraju pretrazi")
}
