package reports

import (
	"log"
	"net/http"
	"regexp"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

type Handlers struct {
	events.Access
	Invitations invitations.Repository
	Reviews     reviews.Repository
	Summarizer  FeedbackSummarizer
	Loc         *time.Location
	Now         func() time.Time
}

func (h *Handlers) Register(mux *http.ServeMux, organizerOnly func(http.Handler) http.Handler) {
	mux.Handle("GET /org/events/{id}/report", organizerOnly(http.HandlerFunc(h.page)))
	mux.Handle("GET /org/events/{id}/report.csv", organizerOnly(http.HandlerFunc(h.csv)))
}

type pageData struct {
	Report   Report
	Summary  Summary
	NotReady bool
	Print    bool
}

func (h *Handlers) build(ev events.Event) (Report, []reviews.WithAuthor, []events.Session, error) {
	invs, err := h.Invitations.ListByEvent(ev.ID)
	if err != nil {
		return Report{}, nil, nil, err
	}
	revs, err := h.Reviews.ListByEvent(ev.ID)
	if err != nil {
		return Report{}, nil, nil, err
	}
	sessions, err := h.Events.ListSessions(ev.ID)
	if err != nil {
		return Report{}, nil, nil, err
	}
	zones, err := h.Events.ListZones(ev.ID)
	if err != nil {
		return Report{}, nil, nil, err
	}
	names := map[string]string{}
	for _, z := range zones {
		names[z.ID] = z.Name
	}
	rep := Compute(Input{Event: ev, Invitations: invs, Reviews: revs, Sessions: sessions, ZoneNames: names, Now: h.Now()})
	return rep, revs, sessions, nil
}

func (h *Handlers) page(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	if ev.Status(h.Now()) != events.StatusFinished {
		h.View.Page(w, r, http.StatusOK, "reports/report", httpx.View{Title: "report.title",
			Data: pageData{Report: Report{Event: ev}, NotReady: true}})
		return
	}
	rep, _, _, err := h.build(ev)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	sum, err := h.Summarizer.Summarize(r.Context(), rep)
	if err != nil {
		// The numbers are still useful without the text summary.
		log.Printf("report %s: summarizer: %v", ev.ID, err)
	}
	print := r.URL.Query().Get("print") == "1"
	v := httpx.View{Title: "report.title", Data: pageData{Report: rep, Summary: sum, Print: print}}
	if print {
		v.BodyClass = "print-view"
	}
	h.View.Page(w, r, http.StatusOK, "reports/report", v)
}

var unsafeFile = regexp.MustCompile(`[^A-Za-z0-9_-]+`)

func (h *Handlers) csv(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	if ev.Status(h.Now()) != events.StatusFinished {
		http.Redirect(w, r, "/org/events/"+ev.ID+"/report", http.StatusSeeOther)
		return
	}
	_, revs, sessions, err := h.build(ev)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	name := unsafeFile.ReplaceAllString(ev.Title, "-")
	if name == "" || name == "-" {
		name = "event"
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="eho-report-`+name+`.csv"`)
	// UTF-8 BOM so Excel shows Serbian diacritics correctly.
	w.Write([]byte("\xEF\xBB\xBF"))
	if err := WriteCSV(w, revs, sessions, h.Loc); err != nil {
		log.Printf("report csv %s: %v", ev.ID, err)
	}
}
