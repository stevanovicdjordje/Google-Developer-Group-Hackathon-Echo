package reports

import (
	"bytes"
	"context"
	"log"
	"net/http"
	"regexp"
	"strconv"
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
	// Text localizes the PDF (same catalog as the page).
	Text PDFText
	Loc  *time.Location
	Now  func() time.Time
}

func (h *Handlers) Register(mux *http.ServeMux, organizerOnly func(http.Handler) http.Handler) {
	mux.Handle("GET /org/events/{id}/report", organizerOnly(http.HandlerFunc(h.page)))
	mux.Handle("GET /org/events/{id}/report.pdf", organizerOnly(http.HandlerFunc(h.pdf)))
}

type pageData struct {
	Report   Report
	Summary  Summary
	NotReady bool
	Print    bool
}

func (h *Handlers) build(ctx context.Context, ev events.Event) (Report, error) {
	invs, err := h.Invitations.ListByEvent(ctx, ev.ID)
	if err != nil {
		return Report{}, err
	}
	revs, err := h.Reviews.ListByEvent(ctx, ev.ID)
	if err != nil {
		return Report{}, err
	}
	agenda, err := h.Events.GetAgenda(ctx, ev.ID)
	if err != nil {
		return Report{}, err
	}
	var sessions []events.Session
	for _, s := range agenda.SessionList(h.Loc) {
		if !s.IsBreak {
			sessions = append(sessions, s)
		}
	}
	return Compute(Input{Event: ev, Invitations: invs, Reviews: revs, Sessions: sessions, Now: h.Now()}), nil
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
	rep, err := h.build(r.Context(), ev)
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

func fileName(title string) string {
	name := unsafeFile.ReplaceAllString(title, "-")
	if name == "" || name == "-" {
		return "event"
	}
	return name
}

// pdf renders the full report (impression, turnout, ratings, sessions,
// comments) as a downloadable A4 PDF.
func (h *Handlers) pdf(w http.ResponseWriter, r *http.Request) {
	ev, ok := h.OwnedEvent(w, r)
	if !ok {
		return
	}
	if ev.Status(h.Now()) != events.StatusFinished {
		http.Redirect(w, r, "/org/events/"+ev.ID+"/report", http.StatusSeeOther)
		return
	}
	rep, err := h.build(r.Context(), ev)
	if err != nil {
		h.Fail(w, r, err)
		return
	}
	sum, err := h.Summarizer.Summarize(r.Context(), rep)
	if err != nil {
		log.Printf("report %s: summarizer: %v", ev.ID, err)
	}
	var buf bytes.Buffer
	if err := WritePDF(&buf, rep, sum, h.Text); err != nil {
		h.Fail(w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", `attachment; filename="eho-report-`+fileName(ev.Title)+`.pdf"`)
	w.Header().Set("Content-Length", strconv.Itoa(buf.Len()))
	_, _ = buf.WriteTo(w)
}
