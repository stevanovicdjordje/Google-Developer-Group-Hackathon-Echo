package app_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

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

func mustContain(t *testing.T, body string, parts ...string) {
	t.Helper()
	for _, p := range parts {
		if !strings.Contains(body, p) {
			t.Errorf("response does not contain %q", p)
		}
	}
}

// demoMap is what backend/maps publishes: one floor with an image, a room and a stand.
func demoMap() (events.Map, map[string][]byte) {
	return events.Map{
		Floors: []events.Floor{{ID: "ground", Name: "Prizemlje", ImagePath: "events/x/floors/ground.png", Width: 1200, Height: 800}},
		Features: []events.Feature{
			{ID: "room1", Type: "room", FloorID: "ground", Name: "Sala A",
				Geometry: events.Geometry{Kind: "rect", Coords: []events.Point{{X: 100, Y: 100}, {X: 400, Y: 300}}}},
			{ID: "stand1", Type: "stand", FloorID: "ground", Name: "Štand AI",
				Geometry: events.Geometry{Kind: "rect", Coords: []events.Point{{X: 500, Y: 100}, {X: 560, Y: 150}}}},
		},
	}, map[string][]byte{"events/x/floors/ground.png": []byte("\x89PNG fake")}
}

func TestFullEventLifecycle(t *testing.T) {
	srv, deps := newServerDeps(t)
	eventRepo := deps.Events.(*events.MemRepo)
	invRepo := deps.Invitations.(*invitations.MemRepo)
	ctx := context.Background()
	day := time.Now().UTC().Add(48 * time.Hour).Truncate(24 * time.Hour)
	at := func(h, m int) string {
		return day.Add(time.Duration(h)*time.Hour + time.Duration(m)*time.Minute).Format("2006-01-02T15:04")
	}

	org := newClient(t, srv)
	registerOrganizer(org, "org@primer.rs")

	// Step 1: basics. Location carries the new event ID.
	res, _ := org.post("/org/events/new", "/org/events/new", url.Values{
		"title": {"Go konferencija"}, "starts_at": {at(8, 0)}, "ends_at": {at(18, 0)},
		"address": {"Bulevar 1, Beograd"}, "action": {"next"},
	})
	expect(t, res, http.StatusSeeOther, "")
	loc := res.Header.Get("Location")
	if !strings.HasSuffix(loc, "/venue") {
		t.Fatalf("Location %q", loc)
	}
	evID := strings.Split(loc, "/")[3]
	base := "/org/events/" + evID

	// Step 2: no map yet; it is made in the app's editor.
	_, body := org.get(base + "/venue")
	mustContain(t, body, "Mapa prostora još nije objavljena", "http://app.test/o\"")

	// backend/maps publishes a map for the same event: it shows up here.
	m, imgs := demoMap()
	eventRepo.PublishMap(evID, m, imgs)
	_, body = org.get(base + "/venue")
	mustContain(t, body, "<svg", "/events/"+evID+"/floors/ground/image", "Sala A", "Štand AI")

	// Step 3: rooms from the map are offered as halls; two overlapping sessions in Sala A.
	_, body = org.get(base + "/schedule")
	mustContain(t, body, `<option value="Sala A"`)
	for _, title := range []string{"Keynote", "Radionica"} {
		res, _ = org.post(base+"/schedule", base+"/sessions", url.Values{"title": {title}, "stage": {"Sala A"},
			"speaker": {"Ana Demić"}, "starts_at": {at(10, 0)}, "ends_at": {at(11, 0)}})
		expect(t, res, http.StatusSeeOther, "")
	}
	res, _ = org.post(base+"/schedule", base+"/sessions", url.Values{"title": {"Noćna"}, "starts_at": {at(17, 0)}, "ends_at": {at(19, 0)}})
	expect(t, res, http.StatusUnprocessableEntity, "")
	_, body = org.get(base + "/schedule")
	mustContain(t, body, "Preklapanje u sali", "Keynote", "Radionica")
	// The agenda is stored in the shared format (backend/events, Flutter app).
	agenda, _ := eventRepo.GetAgenda(ctx, evID)
	if len(agenda.Sessions) != 2 || agenda.Sessions[0].Stage != "Sala A" || agenda.Sessions[0].Start != "10:00" ||
		len(agenda.Speakers) != 1 || len(agenda.Stages) != 1 {
		t.Fatalf("agenda: %+v", agenda)
	}

	// Step 4: invitations (one invalid address).
	res, body = org.post(base+"/invitations", base+"/invitations", url.Values{"emails": {"p1@primer.rs, p2@primer.rs\nlose"}})
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Dodato pozivnica: 2", "Neispravnih adresa: 1", "http://eho.test/i/")
	invs, _ := invRepo.ListByEvent(ctx, evID)
	tokens := map[string]string{}
	for _, inv := range invs {
		tokens[inv.Email] = inv.Token
	}

	// Step 5: publish (the map is already published, so attendees see it in the app anyway).
	res, _ = org.post(base+"/publish", base+"/publish", url.Values{})
	expect(t, res, http.StatusSeeOther, "/org/events?ok=published")
	_, body = org.get("/org/events?ok=published")
	mustContain(t, body, "Predstojeći", "Go konferencija", "Event je objavljen.")

	// Participant 1 registers from the invitation link: it is bound and accepted.
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
	res, body = p1.get("/me/events/" + evID + "?zone=room1")
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, "Keynote", "Sala A", `class="zone-detail"`, "http://app.test/e/"+evID)
	res, _ = p1.get("/events/" + evID + "/floors/ground/image")
	expect(t, res, http.StatusOK, "")
	// Accepting adds the event to the user's "My events" in the app.
	inv, _ := invRepo.GetByToken(ctx, tokens["p1@primer.rs"])
	if !invRepo.IsMember(inv.UserID, evID) {
		t.Error("accepted invitation must create the members/{uid}/events entry")
	}

	// Participant 2 declines without an account.
	anon := newClient(t, srv)
	res, _ = anon.post("/i/"+tokens["p2@primer.rs"], "/i/"+tokens["p2@primer.rs"]+"/decline", url.Values{})
	expect(t, res, http.StatusSeeOther, "")
	_, body = org.get(base + "/invitations?status=declined")
	mustContain(t, body, "p2@primer.rs")

	// Role and ownership isolation.
	res, _ = p1.get("/org/events")
	expect(t, res, http.StatusForbidden, "")
	other := newClient(t, srv)
	registerOrganizer(other, "drugi@primer.rs")
	for _, p := range []string{base + "/edit", base + "/invitations", base + "/report", base + "/report.pdf"} {
		res, _ = other.get(p)
		expect(t, res, http.StatusNotFound, "")
	}
	res, _ = other.get("/events/" + evID + "/floors/ground/image")
	expect(t, res, http.StatusNotFound, "")
	stranger := newClient(t, srv)
	registerParticipant(stranger, "stranger@primer.rs")
	completeOnboarding(stranger)
	res, _ = stranger.get("/me/events/" + evID)
	expect(t, res, http.StatusNotFound, "")
	res, _ = stranger.get("/events/" + evID + "/floors/ground/image")
	expect(t, res, http.StatusNotFound, "")

	// No review before the event ends.
	res, _ = p1.get("/me/events/" + evID + "/review")
	expect(t, res, http.StatusConflict, "")

	// Move the event (and its agenda) into the past.
	ev, _ := eventRepo.Get(ctx, evID)
	shift := -72 * time.Hour
	s, e := ev.StartsAt.Add(shift), ev.EndsAt.Add(shift)
	ev.StartsAt, ev.EndsAt = &s, &e
	if err := eventRepo.Update(ctx, ev); err != nil {
		t.Fatal(err)
	}
	for i := range agenda.Sessions {
		agenda.Sessions[i].Day = s.Format("2006-01-02")
	}
	eventRepo.SaveAgenda(ctx, evID, agenda)

	res, _ = org.get(base + "/edit")
	expect(t, res, http.StatusSeeOther, base+"/report")

	// Review (anonymous) with a session rating; then edit it (still one review).
	form := url.Values{"rating": {"3"}, "comment": {"Odlična organizacija"}, "anonymous": {"on"}, "s_" + agenda.Sessions[0].ID: {"5"}}
	res, _ = p1.post("/me/events/"+evID+"/review", "/me/events/"+evID+"/review", form)
	expect(t, res, http.StatusSeeOther, "/me/events/"+evID+"?ok=review")
	form.Set("rating", "4")
	res, _ = p1.post("/me/events/"+evID+"/review", "/me/events/"+evID+"/review", form)
	expect(t, res, http.StatusSeeOther, "")
	_, body = p1.get("/me/events/" + evID + "/review")
	mustContain(t, body, "Već ste ocenili")
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

	// CSV export was removed; the PDF is the download.
	res, _ = org.get(base + "/report.csv")
	expect(t, res, http.StatusNotFound, "")

	// One-click PDF download.
	res, body = org.get(base + "/report.pdf")
	expect(t, res, http.StatusOK, "")
	if res.Header.Get("Content-Type") != "application/pdf" || !strings.HasPrefix(body, "%PDF-") ||
		!strings.Contains(res.Header.Get("Content-Disposition"), `attachment; filename="eho-report-Go-konferencija.pdf"`) {
		t.Fatalf("pdf: %q %q %q", res.Header.Get("Content-Type"), res.Header.Get("Content-Disposition"), body[:min(8, len(body))])
	}
	res, _ = other.get(base + "/report.pdf")
	expect(t, res, http.StatusNotFound, "")
	res, _ = p1.get(base + "/report.pdf")
	expect(t, res, http.StatusForbidden, "")
}

func TestAppEventsShowUp(t *testing.T) {
	// An event created in the Flutter app has only dates and a published map.
	srv, deps := newServerDeps(t)
	org := newClient(t, srv)
	registerOrganizer(org, "org@primer.rs")
	_, body := org.get("/org/events")
	mustContain(t, body, "Još nemate evente")

	// Learn the organizer's UID from an event created in the UI, then add an "app" event for them.
	res, _ := org.post("/org/events/new", "/org/events/new", url.Values{"title": {"Nacrt"}, "action": {"draft"}})
	expect(t, res, http.StatusSeeOther, "/org/events?ok=saved")
	repo := deps.Events.(*events.MemRepo)
	var owner string
	for _, e := range mustList(t, repo) {
		owner = e.OwnerUID
	}
	day := time.Now().UTC().Truncate(24 * time.Hour)
	end := day.Add(48 * time.Hour)
	repo.Create(context.Background(), events.Event{ID: "devfest", OwnerUID: owner, Title: "DevFest", StartsAt: &day, EndsAt: &end, MapVersion: 1})
	_, body = org.get("/org/events")
	mustContain(t, body, "DevFest", "U toku", "Nacrt")
}

func mustList(t *testing.T, repo *events.MemRepo) []events.Event {
	t.Helper()
	all := repo.ListAll()
	if len(all) == 0 {
		t.Fatal("no events")
	}
	return all
}

func TestEventListSearchAndEmptyState(t *testing.T) {
	srv := newServer(t)
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

func TestReportInEnglish(t *testing.T) {
	deps := app.MemDeps()
	h, err := app.New(config.Config{Timezone: "UTC", Lang: "en"}, deps)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	defer srv.Close()
	ctx := context.Background()

	org := newClient(t, srv)
	res, _ := org.post("/register/organizer", "/register/organizer", url.Values{
		"full_name": {"Ana Anić"}, "email": {"org@example.com"}, "org_name": {"GDG Belgrade"},
		"password": {"password123"}, "password_confirm": {"password123"},
	})
	expect(t, res, http.StatusSeeOther, "/org/events")
	res, _ = org.post("/org/events/new", "/org/events/new", url.Values{"title": {"DevFest Belgrade 2026"}, "action": {"draft"}})
	expect(t, res, http.StatusSeeOther, "/org/events?ok=saved")

	// Make it a finished event with one session and one review.
	repo := deps.Events.(*events.MemRepo)
	ev := repo.ListAll()[0]
	start, end := time.Now().UTC().Add(-48*time.Hour), time.Now().UTC().Add(-40*time.Hour)
	ev.StartsAt, ev.EndsAt, ev.PublishedAt = &start, &end, &start
	repo.Update(ctx, ev)
	var a events.Agenda
	a.Add(events.Session{Title: "On-device AI", Stage: "Glavna sala", StartsAt: start.Add(time.Hour), EndsAt: start.Add(2 * time.Hour)}, time.UTC)
	repo.SaveAgenda(ctx, ev.ID, a)
	deps.Reviews.Save(ctx, reviews.WithAuthor{Review: reviews.Review{ID: "u1", EventID: ev.ID, UserID: "u1", Rating: 4,
		Comment: "Great talks", SessionRatings: map[string]int{a.Sessions[0].ID: 5}, UpdatedAt: end}, AuthorName: "Mara"})

	res, body := org.get("/org/events/" + ev.ID + "/report")
	expect(t, res, http.StatusOK, "")
	mustContain(t, body, `<html lang="en">`, "Overall impression", "4.0", "Good: most attendees", "Best-rated session",
		"not AI", "Ratings per session", "Download PDF")
	if strings.Contains(body, "Export CSV") {
		t.Error("the CSV export button must be gone")
	}
	if strings.Contains(body, "Ukupan utisak") {
		t.Error("Serbian text on the English report")
	}
}
