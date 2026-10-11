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
	"github.com/Ilij4n/eho/backend/onboarding/internal/reports"
	"github.com/Ilij4n/eho/backend/onboarding/internal/talks"
)

func TestBuyTalkReport(t *testing.T) {
	deps := app.MemDeps()
	deps.Echo = talks.FakeEcho{
		Sum: &reports.TalkSummary{Model: "gemma", Takeaway: "On-device models change the cost model.", KeyPoints: []string{"Privacy"}},
		Qs:  []reports.TalkQuestion{{Text: "Does it run on iOS?", Votes: 4}},
	}
	h, err := app.New(config.Config{Timezone: "UTC", Lang: "en"}, deps)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	defer srv.Close()
	ctx := context.Background()

	// An organizer with a published event: one talk has ended, one is later today.
	org := newClient(t, srv)
	res, _ := org.post("/register/organizer", "/register/organizer", url.Values{
		"full_name": {"Ana Anić"}, "email": {"org@example.com"}, "org_name": {"GDG"},
		"password": {"password123"}, "password_confirm": {"password123"},
	})
	expect(t, res, http.StatusSeeOther, "/org/events")
	res, _ = org.post("/org/events/new", "/org/events/new", url.Values{"title": {"DevFest"}, "action": {"draft"}})
	expect(t, res, http.StatusSeeOther, "")
	repo := deps.Events.(*events.MemRepo)
	ev := repo.ListAll()[0]
	day := time.Now().UTC().Truncate(24 * time.Hour)
	start, end := day.Add(-24*time.Hour), day.Add(48*time.Hour)
	ev.StartsAt, ev.EndsAt, ev.PublishedAt = &start, &end, &start
	repo.Update(ctx, ev)
	var a events.Agenda
	a.Add(events.Session{Title: "On-device AI", Stage: "Glavna sala", Speaker: "Mara Ilić",
		StartsAt: start.Add(9 * time.Hour), EndsAt: start.Add(10 * time.Hour)}, time.UTC)
	a.Add(events.Session{Title: "Tomorrow's talk", StartsAt: end.Add(-5 * time.Hour), EndsAt: end.Add(-4 * time.Hour)}, time.UTC)
	repo.SaveAgenda(ctx, ev.ID, a)
	ended, later := a.Sessions[0].ID, a.Sessions[1].ID
	talk := "/talks/" + ev.ID + "/" + ended

	// Someone who wasn't at the event at all.
	buyer := newClient(t, srv)
	res, _ = buyer.post("/register/participant", "/register/participant", url.Values{
		"full_name": {"Pera Perić"}, "email": {"pera@example.com"}, "password": {"password123"}, "password_confirm": {"password123"},
	})
	expect(t, res, http.StatusSeeOther, "/onboarding")
	completeOnboarding(buyer)

	_, body := buyer.get("/talks")
	mustContain(t, body, "On-device AI", "Get report · €2.99", "Mara Ilić")
	if strings.Contains(body, "Tomorrow&#39;s talk") || strings.Contains(body, "Tomorrow's talk") {
		t.Error("talks that haven't ended must not be listed")
	}
	res, _ = buyer.get("/talks/" + ev.ID + "/" + later + "/checkout")
	expect(t, res, http.StatusSeeOther, "/talks/"+ev.ID+"/"+later)

	// Not paid yet: no download.
	res, _ = buyer.get(talk + "/report.pdf")
	expect(t, res, http.StatusSeeOther, talk)

	_, body = buyer.get(talk + "/checkout")
	mustContain(t, body, "Test mode", "Pay €2.99", "Talk report (PDF)", `autocomplete="cc-number"`)

	pay := func(number, expiry, cvc string) (*http.Response, string) {
		return buyer.post(talk+"/checkout", talk+"/checkout", url.Values{"card_name": {"Pera Perić"},
			"card_number": {number}, "card_expiry": {expiry}, "card_cvc": {cvc}})
	}
	res, body = pay("4242 4242 4242 4241", "12/29", "123")
	expect(t, res, http.StatusUnprocessableEntity, "")
	mustContain(t, body, "Enter a valid card number")
	if strings.Contains(body, "4241") {
		t.Error("the card number must never be rendered back")
	}
	res, body = pay("4111 1111 1111 1111", "12/29", "123")
	expect(t, res, http.StatusPaymentRequired, "")
	mustContain(t, body, "only test cards work")
	res, body = pay("4000 0000 0000 0002", "12/29", "123")
	expect(t, res, http.StatusPaymentRequired, "")
	mustContain(t, body, "The card was declined")

	res, _ = pay("4242 4242 4242 4242", "12/29", "123")
	expect(t, res, http.StatusSeeOther, talk+"?ok=paid")
	_, body = buyer.get(talk + "?ok=paid")
	mustContain(t, body, "Payment successful", "Paid €2.99 with Visa •••• 4242", "test payment", "Download PDF")

	res, body = buyer.get(talk + "/report.pdf")
	expect(t, res, http.StatusOK, "")
	if res.Header.Get("Content-Type") != "application/pdf" || !strings.HasPrefix(body, "%PDF-") ||
		!strings.Contains(res.Header.Get("Content-Disposition"), `filename="eho-talk-On-device-AI.pdf"`) {
		t.Fatalf("pdf: %q %q", res.Header.Get("Content-Type"), res.Header.Get("Content-Disposition"))
	}
	// Already bought: checkout goes back to the talk.
	res, _ = buyer.get(talk + "/checkout")
	expect(t, res, http.StatusSeeOther, talk)
	_, body = buyer.get("/me/purchases")
	mustContain(t, body, "On-device AI", "DevFest", "€2.99", "Visa •••• 4242")
	purchases, _ := deps.Purchases.ListByUser(ctx, purchasesOwner(t, deps))
	if len(purchases) != 1 || purchases[0].CardLast4 != "4242" || purchases[0].AmountCents != 299 || purchases[0].Mode != "test" {
		t.Fatalf("purchase: %+v", purchases)
	}

	// Another user still has to pay; the organizer gets it free.
	other := newClient(t, srv)
	res, _ = other.post("/register/participant", "/register/participant", url.Values{
		"full_name": {"Mika Mikić"}, "email": {"mika@example.com"}, "password": {"password123"}, "password_confirm": {"password123"},
	})
	expect(t, res, http.StatusSeeOther, "/onboarding")
	completeOnboarding(other)
	res, _ = other.get(talk + "/report.pdf")
	expect(t, res, http.StatusSeeOther, talk)
	res, _ = org.get(talk + "/report.pdf")
	expect(t, res, http.StatusOK, "")

	// Signed out: login first.
	res, _ = newClient(t, srv).get("/talks")
	expect(t, res, http.StatusSeeOther, "/login?next=%2Ftalks")
}

// purchasesOwner finds the buyer's UID from the stored purchases.
func purchasesOwner(t *testing.T, deps app.Deps) string {
	t.Helper()
	return deps.Purchases.(*talks.MemRepo).OnlyUser()
}
