package talks

import (
	"bytes"
	"context"
	"errors"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reports"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

type Handlers struct {
	Events   events.Repository
	Reviews  reviews.Repository
	Repo     Repository
	Payments PaymentProvider
	Echo     Echo
	View     *httpx.Renderer
	Text     reports.PDFText
	Money    func(cents int) string
	Lang     string
	Loc      *time.Location
	Now      func() time.Time
}

func (h *Handlers) Register(mux *http.ServeMux) {
	signed := func(f http.HandlerFunc) http.Handler { return httpx.RequireSignedIn(f) }
	mux.Handle("GET /talks", signed(h.catalog))
	mux.Handle("GET /talks/{eid}/{sid}", signed(h.talk))
	mux.Handle("GET /talks/{eid}/{sid}/checkout", signed(h.checkoutForm))
	mux.Handle("POST /talks/{eid}/{sid}/checkout", signed(h.checkout))
	mux.Handle("GET /talks/{eid}/{sid}/report.pdf", signed(h.pdf))
	mux.Handle("GET /me/purchases", signed(h.purchases))
}

func (h *Handlers) fail(w http.ResponseWriter, r *http.Request, err error) {
	log.Printf("%s %s: %v", r.Method, r.URL.Path, err)
	h.View.Error(w, r, http.StatusInternalServerError, "error.title")
}

// ---- catalog ----

type talkRow struct {
	Event     events.Event
	Session   events.Session
	Purchased bool
	Free      bool
}

type eventGroup struct {
	Event events.Event
	Talks []talkRow
}

type catalogData struct {
	Query  string
	Groups []eventGroup
	Price  string
	Total  int
}

var foldReplacer = strings.NewReplacer("č", "c", "ć", "c", "š", "s", "ž", "z", "đ", "dj")

func fold(s string) string { return foldReplacer.Replace(strings.ToLower(s)) }

// talks returns the event's real talks (no breaks) from its agenda.
func (h *Handlers) talks(ctx context.Context, ev events.Event) ([]events.Session, error) {
	a, err := h.Events.GetAgenda(ctx, ev.ID)
	if err != nil {
		return nil, err
	}
	var out []events.Session
	for _, s := range a.SessionList(h.Loc) {
		if !s.IsBreak {
			out = append(out, s)
		}
	}
	return out, nil
}

func (h *Handlers) catalog(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	evs, err := h.Events.ListPublished(r.Context())
	if err != nil {
		h.fail(w, r, err)
		return
	}
	owned, err := h.Repo.ListByUser(r.Context(), p.UserID)
	if err != nil {
		h.fail(w, r, err)
		return
	}
	bought := map[string]bool{}
	for _, o := range owned {
		bought[o.EventID+"/"+o.SessionID] = true
	}
	sort.SliceStable(evs, func(i, j int) bool {
		a, b := evs[i].StartsAt, evs[j].StartsAt
		if a == nil || b == nil {
			return b == nil && a != nil
		}
		return a.After(*b)
	})
	now := h.Now()
	q := fold(strings.TrimSpace(r.URL.Query().Get("q")))
	d := catalogData{Query: r.URL.Query().Get("q"), Price: h.Money(PriceCents)}
	for _, ev := range evs {
		ss, err := h.talks(r.Context(), ev)
		if err != nil {
			h.fail(w, r, err)
			return
		}
		g := eventGroup{Event: ev}
		for _, s := range ss {
			// Only talks that have ended have a complete report.
			if s.EndsAt.After(now) {
				continue
			}
			if q != "" && !strings.Contains(fold(s.Title+" "+s.Speaker+" "+ev.Title), q) {
				continue
			}
			g.Talks = append(g.Talks, talkRow{Event: ev, Session: s, Purchased: bought[ev.ID+"/"+s.ID],
				Free: events.IsOrganizerOf(p, ev)})
		}
		if len(g.Talks) > 0 {
			d.Groups = append(d.Groups, g)
			d.Total += len(g.Talks)
		}
	}
	h.View.Page(w, r, http.StatusOK, "talks/list", httpx.View{Title: "talks.title", Data: d})
}

// ---- one talk ----

type talkData struct {
	Event    events.Event
	Session  events.Session
	Ended    bool
	Free     bool
	Purchase *Purchase
	Price    string
	Paid     string // formatted amount of the purchase
	Ratings  int
	Avg      float64
}

// load resolves the talk in the URL. ok=false means the response is written.
func (h *Handlers) load(w http.ResponseWriter, r *http.Request) (talkData, bool) {
	p := httpx.PrincipalFrom(r.Context())
	ev, err := h.Events.Get(r.Context(), r.PathValue("eid"))
	if err != nil || !ev.Published() {
		if err != nil && !errors.Is(err, events.ErrNotFound) {
			h.fail(w, r, err)
			return talkData{}, false
		}
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return talkData{}, false
	}
	ss, err := h.talks(r.Context(), ev)
	if err != nil {
		h.fail(w, r, err)
		return talkData{}, false
	}
	d := talkData{Event: ev, Price: h.Money(PriceCents), Free: events.IsOrganizerOf(p, ev)}
	found := false
	for _, s := range ss {
		if s.ID == r.PathValue("sid") {
			d.Session, found = s, true
		}
	}
	if !found {
		h.View.Error(w, r, http.StatusNotFound, "error.title")
		return talkData{}, false
	}
	d.Ended = !d.Session.EndsAt.After(h.Now())
	pur, err := h.Repo.Get(r.Context(), p.UserID, ev.ID, d.Session.ID)
	switch {
	case err == nil:
		d.Purchase = &pur
		d.Paid = h.Money(pur.AmountCents)
	case !errors.Is(err, ErrNotFound):
		h.fail(w, r, err)
		return talkData{}, false
	}
	return d, true
}

func (d talkData) CanDownload() bool { return d.Ended && (d.Free || d.Purchase != nil) }

func (h *Handlers) talk(w http.ResponseWriter, r *http.Request) {
	d, ok := h.load(w, r)
	if !ok {
		return
	}
	if revs, err := h.Reviews.ListByEvent(r.Context(), d.Event.ID); err == nil {
		d.Ratings, d.Avg, _ = reports.TalkRatings(revs, d.Session.ID)
	}
	h.View.Page(w, r, http.StatusOK, "talks/talk", httpx.View{Title: "talk.report_title", Data: d})
}

// ---- checkout ----

func (h *Handlers) talkURL(d talkData) string {
	return "/talks/" + url.PathEscape(d.Event.ID) + "/" + url.PathEscape(d.Session.ID)
}

func (h *Handlers) renderCheckout(w http.ResponseWriter, r *http.Request, status int, d talkData, form url.Values, errs map[string]string) {
	h.View.Page(w, r, status, "talks/checkout", httpx.View{Title: "checkout.title", Form: form, Errors: errs, Data: d})
}

func (h *Handlers) checkoutForm(w http.ResponseWriter, r *http.Request) {
	d, ok := h.load(w, r)
	if !ok {
		return
	}
	if !d.Ended || d.CanDownload() {
		http.Redirect(w, r, h.talkURL(d), http.StatusSeeOther)
		return
	}
	h.renderCheckout(w, r, http.StatusOK, d, url.Values{"card_name": {httpx.PrincipalFrom(r.Context()).Name}}, nil)
}

func (h *Handlers) checkout(w http.ResponseWriter, r *http.Request) {
	d, ok := h.load(w, r)
	if !ok {
		return
	}
	if !d.Ended || d.CanDownload() {
		http.Redirect(w, r, h.talkURL(d), http.StatusSeeOther)
		return
	}
	// Only the name and expiry are ever shown again; card number and CVC are
	// dropped from the form on errors and never logged.
	keep := url.Values{"card_name": {r.PostFormValue("card_name")}, "card_expiry": {r.PostFormValue("card_expiry")}}
	card, errs := ParseCard(CardInput{Name: r.PostFormValue("card_name"), Number: r.PostFormValue("card_number"),
		Expiry: r.PostFormValue("card_expiry"), CVC: r.PostFormValue("card_cvc")}, h.Now())
	if errs != nil {
		h.renderCheckout(w, r, http.StatusUnprocessableEntity, d, keep, errs)
		return
	}
	p := httpx.PrincipalFrom(r.Context())
	ch, err := h.Payments.Charge(r.Context(), PriceCents, Currency, card, "Echo talk report: "+d.Session.Title)
	if err != nil {
		key := "err.pay_failed"
		switch {
		case errors.Is(err, ErrDeclined):
			key = "err.pay_declined"
		case errors.Is(err, ErrInsufficientFunds):
			key = "err.pay_funds"
		case errors.Is(err, ErrNotTestCard):
			key = "err.pay_test_only"
		default:
			log.Printf("payment for %s/%s: %v", d.Event.ID, d.Session.ID, err)
		}
		h.renderCheckout(w, r, http.StatusPaymentRequired, d, keep, map[string]string{"_form": key})
		return
	}
	err = h.Repo.Create(r.Context(), Purchase{UserID: p.UserID, EventID: d.Event.ID, SessionID: d.Session.ID,
		AmountCents: PriceCents, Currency: Currency, CardBrand: ch.Brand, CardLast4: ch.Last4,
		PaymentID: ch.ID, Mode: ch.Mode, CreatedAt: h.Now().UTC()})
	if err != nil && !errors.Is(err, ErrDuplicate) {
		h.fail(w, r, err)
		return
	}
	http.Redirect(w, r, h.talkURL(d)+"?ok=paid", http.StatusSeeOther)
}

// ---- the PDF ----

var unsafeFile = regexp.MustCompile(`[^A-Za-z0-9_-]+`)

func (h *Handlers) pdf(w http.ResponseWriter, r *http.Request) {
	d, ok := h.load(w, r)
	if !ok {
		return
	}
	if !d.CanDownload() {
		http.Redirect(w, r, h.talkURL(d), http.StatusSeeOther)
		return
	}
	tr := reports.TalkReport{Event: d.Event, Session: d.Session}
	if revs, err := h.Reviews.ListByEvent(r.Context(), d.Event.ID); err == nil {
		tr.Ratings, tr.AvgRating, tr.Distribution = reports.TalkRatings(revs, d.Session.ID)
	} else {
		log.Printf("talk report %s/%s: reviews: %v", d.Event.ID, d.Session.ID, err)
	}
	// Echo may be slow or down: the report still downloads, with a note.
	if sum, err := h.Echo.Summary(r.Context(), d.Event.ID, d.Session.ID, h.Lang); err == nil {
		tr.Summary = sum
	} else {
		log.Printf("talk report %s/%s: echo summary: %v", d.Event.ID, d.Session.ID, err)
	}
	if qs, err := h.Echo.Questions(r.Context(), d.Event.ID, d.Session.ID); err == nil {
		tr.Questions = reports.TopQuestions(qs, 5)
	} else {
		log.Printf("talk report %s/%s: echo questions: %v", d.Event.ID, d.Session.ID, err)
	}
	var buf bytes.Buffer
	if err := reports.WriteTalkPDF(&buf, tr, h.Text); err != nil {
		h.fail(w, r, err)
		return
	}
	name := unsafeFile.ReplaceAllString(d.Session.Title, "-")
	if len(name) > 60 {
		name = name[:60]
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", `attachment; filename="eho-talk-`+strings.Trim(name, "-")+`.pdf"`)
	w.Header().Set("Content-Length", strconv.Itoa(buf.Len()))
	_, _ = buf.WriteTo(w)
}

// ---- purchases ----

type purchaseRow struct {
	Purchase
	Amount       string
	EventTitle   string
	SessionTitle string
	URL          string
}

func (h *Handlers) purchases(w http.ResponseWriter, r *http.Request) {
	p := httpx.PrincipalFrom(r.Context())
	list, err := h.Repo.ListByUser(r.Context(), p.UserID)
	if err != nil {
		h.fail(w, r, err)
		return
	}
	titles := map[string]map[string]string{}
	evTitles := map[string]string{}
	var rows []purchaseRow
	for _, pu := range list {
		if _, ok := titles[pu.EventID]; !ok {
			titles[pu.EventID] = map[string]string{}
			if ev, err := h.Events.Get(r.Context(), pu.EventID); err == nil {
				evTitles[pu.EventID] = ev.Title
				if ss, err := h.talks(r.Context(), ev); err == nil {
					for _, s := range ss {
						titles[pu.EventID][s.ID] = s.Title
					}
				}
			}
		}
		rows = append(rows, purchaseRow{Purchase: pu, Amount: h.Money(pu.AmountCents), EventTitle: evTitles[pu.EventID],
			SessionTitle: titles[pu.EventID][pu.SessionID],
			URL:          "/talks/" + url.PathEscape(pu.EventID) + "/" + url.PathEscape(pu.SessionID)})
	}
	h.View.Page(w, r, http.StatusOK, "talks/purchases", httpx.View{Title: "purchases.title", Data: rows})
}
