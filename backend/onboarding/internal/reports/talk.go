package reports

import (
	"bytes"
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/go-pdf/fpdf"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

// TalkSummary is Echo's AI summary of one talk (contracts/echo TalkSummary).
// It is model output: it is only ever placed into the PDF as text.
type TalkSummary struct {
	Text      string
	Model     string
	Takeaway  string
	KeyPoints []string
	Tradeoffs []Tradeoff
}

type Tradeoff struct {
	Topic, Issue, Fix string
	AtSeconds         int
}

// TalkQuestion is an anonymous audience question from Echo's Q&A.
type TalkQuestion struct {
	Text  string
	Votes int
}

// TalkReport is the paid report of one talk.
type TalkReport struct {
	Event        events.Event
	Session      events.Session
	Summary      *TalkSummary // nil when Echo had no summary (or was unavailable)
	Ratings      int
	AvgRating    float64
	Distribution []Bucket // 5 stars first
	Questions    []TalkQuestion
}

// TalkRatings computes the audience rating of one session from the reviews.
func TalkRatings(revs []reviews.WithAuthor, sessionID string) (count int, avg float64, dist []Bucket) {
	counts := [6]int{}
	sum := 0
	for _, rv := range revs {
		if n, ok := rv.SessionRatings[sessionID]; ok && n >= 1 && n <= 5 {
			counts[n]++
			sum += n
			count++
		}
	}
	for s := 5; s >= 1; s-- {
		dist = append(dist, Bucket{Stars: s, Count: counts[s], Share: ratio(counts[s], count)})
	}
	return count, ratio(sum, count), dist
}

// TopQuestions keeps the n most-voted questions.
func TopQuestions(qs []TalkQuestion, n int) []TalkQuestion {
	out := append([]TalkQuestion(nil), qs...)
	sort.SliceStable(out, func(i, j int) bool { return out[i].Votes > out[j].Votes })
	if len(out) > n {
		out = out[:n]
	}
	return out
}

func mmss(sec int) string { return fmt.Sprintf("%02d:%02d", sec/60, sec%60) }

// WriteTalkPDF renders the talk report as an A4 PDF.
func WriteTalkPDF(w io.Writer, tr TalkReport, tx PDFText) error {
	p := fpdf.New("P", "mm", "A4", "")
	regular, err := pdfFonts.ReadFile("fonts/DejaVuSansCondensed.ttf")
	if err != nil {
		return err
	}
	bold, err := pdfFonts.ReadFile("fonts/DejaVuSansCondensed-Bold.ttf")
	if err != nil {
		return err
	}
	p.AddUTF8FontFromBytes("dejavu", "", regular)
	p.AddUTF8FontFromBytes("dejavu", "B", bold)
	p.SetMargins(margin, margin, margin)
	p.SetAutoPageBreak(true, 18)
	p.SetTitle(tx.T("talk.report_title")+" – "+tr.Session.Title, true)
	p.SetCreator("Echo", true)
	p.AliasNbPages("{nb}")
	d := &pdfDoc{Fpdf: p, tx: tx}
	p.SetFooterFunc(func() {
		d.SetY(-12)
		d.font(false, 8)
		d.text(cMuted)
		d.CellFormat(contentW*0.75, 5, "Echo · "+tr.Event.Title+" · "+tr.Session.Title, "", 0, "L", false, 0, "")
		d.CellFormat(contentW*0.25, 5, fmt.Sprintf("%d / {nb}", d.PageNo()), "", 0, "R", false, 0, "")
	})
	p.AddPage()

	// Header
	s := tr.Session
	d.font(true, 9)
	d.text(cMuted)
	d.CellFormat(contentW, 5, strings.ToUpper(tx.T("talk.report_title"))+" · "+tr.Event.Title, "", 1, "L", false, 0, "")
	d.font(true, 19)
	d.text(cInk)
	d.MultiCell(contentW, 8.5, s.Title, "", "L", false)
	var meta []string
	if s.Speaker != "" {
		meta = append(meta, s.Speaker)
	}
	if s.Stage != "" {
		meta = append(meta, s.Stage)
	}
	end := ""
	if tx.Clock != nil {
		end = "–" + tx.Clock(s.EndsAt)
	}
	meta = append(meta, tx.Date(s.StartsAt)+end)
	d.font(false, 10)
	d.text(cMuted)
	d.MultiCell(contentW, 5, strings.Join(meta, "  ·  "), "", "L", false)
	d.Ln(4)

	d.talkSummary(tr.Summary)
	d.talkRatings(tr)
	d.talkQuestions(tr.Questions)

	if err := p.Error(); err != nil {
		return err
	}
	var buf bytes.Buffer
	if err := p.Output(&buf); err != nil {
		return err
	}
	_, err = buf.WriteTo(w)
	return err
}

// talkSummary draws the dark "takeaway" block and the key points / trade-offs.
func (d *pdfDoc) talkSummary(sum *TalkSummary) {
	if sum == nil || (sum.Takeaway == "" && sum.Text == "") {
		d.heading(d.tx.T("talk.summary"))
		d.font(false, 10)
		d.text(cMuted)
		d.MultiCell(contentW, 5, d.tx.T("talk.summary_missing"), "", "L", false)
		return
	}
	takeaway := sum.Takeaway
	if takeaway == "" {
		takeaway = sum.Text
	}
	const pad = 7.0
	inner := contentW - 2*pad
	d.font(true, 12)
	lines := d.lines(takeaway, inner)
	h := pad + 7 + float64(len(lines))*6 + 8 + pad
	d.need(h)
	x0, y0 := margin, d.GetY()
	d.fill(cInk)
	d.RoundedRect(x0, y0, contentW, h, 4, "1234", "F")
	d.SetXY(x0+pad, y0+pad)
	d.font(true, 9)
	d.text(cOnDarkAcc)
	d.CellFormat(inner, 5, strings.ToUpper(d.tx.T("talk.takeaway")), "", 1, "L", false, 0, "")
	d.font(true, 12)
	d.text(cWhite)
	for i, l := range lines {
		d.SetXY(x0+pad, y0+pad+7+float64(i)*6)
		d.CellFormat(inner, 6, l, "", 0, "L", false, 0, "")
	}
	d.font(false, 8)
	d.text(cOnDark)
	d.SetXY(x0+pad, y0+h-pad-4)
	label := d.tx.T("talk.ai_note")
	if sum.Model != "" {
		label += " (" + sum.Model + ")"
	}
	d.CellFormat(inner, 4, label, "", 0, "L", false, 0, "")
	d.SetXY(margin, y0+h+2)

	if len(sum.KeyPoints) > 0 {
		d.heading(d.tx.T("talk.key_points"))
		for _, kp := range sum.KeyPoints {
			d.font(false, 10)
			ls := d.lines(kp, contentW-6)
			d.need(float64(len(ls))*5 + 1.5)
			y := d.GetY()
			d.text(cPrimary)
			d.CellFormat(6, 5, "•", "", 0, "L", false, 0, "")
			d.text(cInk)
			for i, l := range ls {
				d.SetXY(margin+6, y+float64(i)*5)
				d.CellFormat(contentW-6, 5, l, "", 0, "L", false, 0, "")
			}
			d.SetXY(margin, y+float64(len(ls))*5+1.5)
		}
	}

	if len(sum.Tradeoffs) > 0 {
		d.heading(d.tx.T("talk.tradeoffs"))
		cols := []float64{28, 68, 68, 16}
		d.font(true, 8.5)
		d.text(cMuted)
		for i, hd := range []string{d.tx.T("talk.topic"), d.tx.T("talk.issue"), d.tx.T("talk.fix"), d.tx.T("talk.at")} {
			d.CellFormat(cols[i], 6, hd, "B", 0, "L", false, 0, "")
		}
		d.Ln(-1)
		d.draw(cDivider)
		for _, t := range sum.Tradeoffs {
			d.font(false, 9)
			issue := d.lines(t.Issue, cols[1]-3)
			fix := d.lines(t.Fix, cols[2]-3)
			rowH := float64(max(len(issue), len(fix), 1))*4.5 + 4
			d.need(rowH)
			y := d.GetY()
			d.font(true, 9)
			d.text(cInk)
			d.SetXY(margin, y+2)
			d.CellFormat(cols[0], 4.5, t.Topic, "", 0, "L", false, 0, "")
			d.font(false, 9)
			for i, l := range issue {
				d.SetXY(margin+cols[0], y+2+float64(i)*4.5)
				d.CellFormat(cols[1], 4.5, l, "", 0, "L", false, 0, "")
			}
			for i, l := range fix {
				d.SetXY(margin+cols[0]+cols[1], y+2+float64(i)*4.5)
				d.CellFormat(cols[2], 4.5, l, "", 0, "L", false, 0, "")
			}
			d.text(cPrimary)
			d.SetXY(margin+cols[0]+cols[1]+cols[2], y+2)
			d.CellFormat(cols[3], 4.5, mmss(t.AtSeconds), "", 0, "L", false, 0, "")
			d.Line(margin, y+rowH, margin+contentW, y+rowH)
			d.SetXY(margin, y+rowH)
		}
	}
}

func (d *pdfDoc) talkRatings(tr TalkReport) {
	d.heading(d.tx.T("talk.audience_rating"))
	if tr.Ratings == 0 {
		d.font(false, 10)
		d.text(cMuted)
		d.CellFormat(contentW, 6, d.tx.T("talk.no_ratings"), "", 1, "L", false, 0, "")
		return
	}
	d.need(14 + 7*5)
	d.font(true, 26)
	d.text(cPrimary)
	v := d.tx.Rating(tr.AvgRating)
	vw := d.GetStringWidth(v) + 2
	d.CellFormat(vw, 12, v, "", 0, "L", false, 0, "")
	d.font(false, 10)
	d.text(cMuted)
	d.CellFormat(contentW-vw, 12, "/ 5 · "+d.tx.T("talk.ratings_count", tr.Ratings), "", 1, "L", false, 0, "")
	d.distribution(Report{Distribution: tr.Distribution})
}

func (d *pdfDoc) talkQuestions(qs []TalkQuestion) {
	d.heading(d.tx.T("talk.questions"))
	if len(qs) == 0 {
		d.font(false, 10)
		d.text(cMuted)
		d.CellFormat(contentW, 6, d.tx.T("talk.no_questions"), "", 1, "L", false, 0, "")
		return
	}
	d.draw(cDivider)
	for _, q := range qs {
		d.font(false, 10)
		ls := d.lines(q.Text, contentW-24)
		h := float64(len(ls))*5 + 4
		d.need(h)
		y := d.GetY()
		d.font(true, 10)
		d.text(cPrimary)
		d.SetXY(margin, y+2)
		d.CellFormat(22, 5, d.tx.T("talk.votes", q.Votes), "", 0, "L", false, 0, "")
		d.font(false, 10)
		d.text(cInk)
		for i, l := range ls {
			d.SetXY(margin+24, y+2+float64(i)*5)
			d.CellFormat(contentW-24, 5, l, "", 0, "L", false, 0, "")
		}
		d.Line(margin, y+h, margin+contentW, y+h)
		d.SetXY(margin, y+h)
	}
	d.Ln(2)
	d.font(false, 8)
	d.text(cMuted)
	d.MultiCell(contentW, 4, d.tx.T("talk.questions_note"), "", "L", false)
}
