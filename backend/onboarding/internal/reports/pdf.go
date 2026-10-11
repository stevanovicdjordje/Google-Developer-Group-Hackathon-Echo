package reports

import (
	"bytes"
	"embed"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/go-pdf/fpdf"
)

// DejaVu Sans Condensed (see fonts/LICENSE-DejaVu.txt): a Unicode TTF, so
// Serbian letters (č ć š ž đ), quotes and ★ render in the PDF.
//
//go:embed fonts/DejaVuSansCondensed.ttf fonts/DejaVuSansCondensed-Bold.ttf
var pdfFonts embed.FS

// PDFText supplies the localized strings and formats (the same i18n catalog
// as the HTML report).
type PDFText struct {
	T      func(key string, args ...any) string
	Rating func(float64) string
	Date   func(time.Time) string // date + time
	Day    func(time.Time) string // date only
	Clock  func(time.Time) string // time only
}

// Colors from the app design tokens (mobile/docs/design).
var (
	cInk        = rgb{0x0D, 0x13, 0x21}
	cMuted      = rgb{0x4A, 0x54, 0x68}
	cDivider    = rgb{0xDD, 0xE2, 0xEB}
	cTile       = rgb{0xF3, 0xF5, 0xF9}
	cPrimary    = rgb{0x2F, 0x4B, 0xFF}
	cOnDark     = rgb{0xD5, 0xDB, 0xE6}
	cOnDarkAcc  = rgb{0xB9, 0xC3, 0xFF}
	cDarkTrack  = rgb{0x2A, 0x35, 0x50}
	cGood       = rgb{0x2B, 0x8A, 0x3E}
	cWarn       = rgb{0xC2, 0x41, 0x0C}
	cBad        = rgb{0xC9, 0x2A, 0x2A}
	cWhite      = rgb{0xFF, 0xFF, 0xFF}
	pageW       = 210.0
	margin      = 15.0
	contentW    = pageW - 2*margin
	bottomLimit = 297.0 - 18
)

type rgb struct{ r, g, b int }

type pdfDoc struct {
	*fpdf.Fpdf
	tx PDFText
}

func (d *pdfDoc) text(c rgb) { d.SetTextColor(c.r, c.g, c.b) }
func (d *pdfDoc) fill(c rgb) { d.SetFillColor(c.r, c.g, c.b) }
func (d *pdfDoc) draw(c rgb) { d.SetDrawColor(c.r, c.g, c.b) }
func (d *pdfDoc) font(bold bool, size float64) {
	style := ""
	if bold {
		style = "B"
	}
	d.SetFont("dejavu", style, size)
}

// need starts a new page when h millimetres don't fit any more.
func (d *pdfDoc) need(h float64) {
	if d.GetY()+h > bottomLimit {
		d.AddPage()
	}
}

func (d *pdfDoc) heading(s string) {
	d.need(16)
	d.Ln(5)
	d.font(true, 13)
	d.text(cInk)
	d.CellFormat(contentW, 7, s, "", 1, "L", false, 0, "")
	d.Ln(1)
}

// lines wraps s to width w (mm) with the current font.
func (d *pdfDoc) lines(s string, w float64) []string {
	var out []string
	for _, para := range strings.Split(s, "\n") {
		if strings.TrimSpace(para) == "" {
			continue
		}
		for _, l := range d.SplitText(para, w) {
			out = append(out, l)
		}
	}
	return out
}

// WritePDF renders the report as an A4 PDF.
func WritePDF(w io.Writer, rep Report, sum Summary, tx PDFText) error {
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
	p.SetTitle(fmt.Sprintf("%s – %s", tx.T("report.title"), rep.Event.Title), true)
	p.SetCreator("Eho", true)
	p.AliasNbPages("{nb}")
	d := &pdfDoc{Fpdf: p, tx: tx}
	p.SetFooterFunc(func() {
		d.SetY(-12)
		d.font(false, 8)
		d.text(cMuted)
		d.CellFormat(contentW/2, 5, "Eho · "+rep.Event.Title, "", 0, "L", false, 0, "")
		d.CellFormat(contentW/2, 5, fmt.Sprintf("%d / {nb}", d.PageNo()), "", 0, "R", false, 0, "")
	})
	p.AddPage()

	d.header(rep)
	d.impression(rep, sum)
	d.turnout(rep)
	d.distribution(rep)
	d.sessions(rep)
	d.comments(rep)

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

func (d *pdfDoc) header(rep Report) {
	e := rep.Event
	d.font(true, 9)
	d.text(cMuted)
	d.CellFormat(contentW, 5, strings.ToUpper(d.tx.T("report.title")), "", 1, "L", false, 0, "")
	d.font(true, 20)
	d.text(cInk)
	d.MultiCell(contentW, 9, e.Title, "", "L", false)
	var meta []string
	if e.StartsAt != nil && e.EndsAt != nil {
		meta = append(meta, d.tx.Date(*e.StartsAt)+" – "+d.tx.Date(*e.EndsAt))
	}
	if e.Address != "" {
		meta = append(meta, e.Address)
	}
	if len(meta) > 0 {
		d.font(false, 10)
		d.text(cMuted)
		d.MultiCell(contentW, 5, strings.Join(meta, "  ·  "), "", "L", false)
	}
	d.Ln(4)
}

func (d *pdfDoc) impression(rep Report, sum Summary) {
	const pad = 7.0
	inner := contentW - 2*pad
	colGap := 5.0
	colW := (inner - 2*colGap) / 3
	headLeftW := 52.0

	// Measure first, so the dark block can be drawn behind the text.
	d.font(true, 12)
	headLines := d.lines(sum.Headline, inner-headLeftW)
	cols := []struct {
		title string
		items []string
	}{
		{d.tx.T("report.liked"), sum.Liked},
		{d.tx.T("report.disliked"), sum.Disliked},
		{d.tx.T("report.recommendations"), sum.Recommendations},
	}
	d.font(false, 9)
	colH := 0.0
	wrapped := make([][][]string, len(cols))
	for i, c := range cols {
		h := 6.0
		for _, it := range c.items {
			ls := d.lines(it, colW-4)
			wrapped[i] = append(wrapped[i], ls)
			h += float64(len(ls))*4.3 + 1.2
		}
		if len(c.items) == 0 {
			h += 4.3
		}
		colH = max(colH, h)
	}
	topH := max(30.0, float64(len(headLines))*6+8)
	noteLines := d.lines(d.tx.T("report.summary_note"), inner)
	total := pad + 8 + topH + colH + float64(len(noteLines))*3.8 + pad
	d.need(total)

	x0, y0 := margin, d.GetY()
	d.fill(cInk)
	d.RoundedRect(x0, y0, contentW, total, 4, "1234", "F")

	// Title
	d.SetXY(x0+pad, y0+pad)
	d.font(true, 13)
	d.text(cWhite)
	d.CellFormat(inner, 6, d.tx.T("report.impression"), "", 1, "L", false, 0, "")

	// Big rating + bar + "based on"
	yTop := d.GetY() + 2
	d.SetXY(x0+pad, yTop)
	d.font(true, 34)
	d.text(cOnDarkAcc)
	value := "—"
	if rep.Reviews > 0 {
		value = d.tx.Rating(rep.AvgRating)
	}
	vw := d.GetStringWidth(value)
	d.CellFormat(vw+1, 14, value, "", 0, "L", false, 0, "")
	if rep.Reviews > 0 {
		d.font(true, 11)
		d.text(cOnDark)
		d.SetXY(x0+pad+vw+1, yTop+6)
		d.CellFormat(10, 6, "/ 5", "", 0, "L", false, 0, "")
	}
	barY := yTop + 16
	d.fill(cDarkTrack)
	d.RoundedRect(x0+pad, barY, 44, 3, 1.5, "1234", "F")
	if rep.AvgRating > 0 {
		d.fill(cOnDarkAcc)
		d.RoundedRect(x0+pad, barY, 44*rep.AvgRating/5, 3, 1.5, "1234", "F")
	}
	d.SetXY(x0+pad, barY+4)
	d.font(false, 9)
	d.text(cOnDark)
	d.CellFormat(headLeftW, 5, d.tx.T("report.based_on", rep.Reviews), "", 0, "L", false, 0, "")

	// Headline to the right
	d.font(true, 12)
	d.text(cWhite)
	hy := yTop + (topH-float64(len(headLines))*6)/2 - 2
	for i, l := range headLines {
		d.SetXY(x0+pad+headLeftW, hy+float64(i)*6)
		d.CellFormat(inner-headLeftW, 6, l, "", 0, "L", false, 0, "")
	}

	// Three columns of bullets
	yCols := yTop + topH
	for i, c := range cols {
		cx := x0 + pad + float64(i)*(colW+colGap)
		d.SetXY(cx, yCols)
		d.font(true, 10)
		d.text(cWhite)
		d.CellFormat(colW, 5, c.title, "", 0, "L", false, 0, "")
		y := yCols + 6.5
		d.font(false, 9)
		if len(c.items) == 0 {
			d.text(cOnDark)
			d.SetXY(cx, y)
			d.CellFormat(colW, 4.3, "—", "", 0, "L", false, 0, "")
		}
		for _, ls := range wrapped[i] {
			d.text(cOnDarkAcc)
			d.SetXY(cx, y)
			d.CellFormat(4, 4.3, "•", "", 0, "L", false, 0, "")
			d.text(cWhite)
			for j, l := range ls {
				d.SetXY(cx+4, y+float64(j)*4.3)
				d.CellFormat(colW-4, 4.3, l, "", 0, "L", false, 0, "")
			}
			y += float64(len(ls))*4.3 + 1.2
		}
	}

	// Note: statistical, not AI
	d.font(false, 8)
	d.text(cOnDark)
	ny := yCols + colH + 1
	for i, l := range noteLines {
		d.SetXY(x0+pad, ny+float64(i)*3.8)
		d.CellFormat(inner, 3.8, l, "", 0, "L", false, 0, "")
	}
	d.SetXY(margin, y0+total+2)
}

func (d *pdfDoc) turnout(rep Report) {
	d.heading(d.tx.T("report.turnout"))
	tiles := []struct {
		v, k   string
		accent bool
	}{
		{fmt.Sprint(rep.Invited), d.tx.T("events.invited"), false},
		{fmt.Sprint(rep.Accepted), d.tx.T("events.accepted"), false},
		{fmt.Sprint(rep.Declined), d.tx.T("report.declined"), false},
		{fmt.Sprint(rep.Pending + rep.Expired), d.tx.T("report.no_answer"), false},
		{pctStr(rep.AcceptanceRate), d.tx.T("report.acceptance_rate"), true},
		{fmt.Sprint(rep.Reviews), d.tx.T("report.reviews"), false},
		{pctStr(rep.ResponseRate), d.tx.T("report.response_rate"), true},
	}
	gap := 2.0
	tw := (contentW - gap*float64(len(tiles)-1)) / float64(len(tiles))
	const th = 19.0
	d.need(th + 2)
	y := d.GetY()
	for i, t := range tiles {
		x := margin + float64(i)*(tw+gap)
		d.fill(cTile)
		d.RoundedRect(x, y, tw, th, 3, "1234", "F")
		d.SetXY(x+2.5, y+2.5)
		d.font(true, 15)
		if t.accent {
			d.text(cPrimary)
		} else {
			d.text(cInk)
		}
		d.CellFormat(tw-5, 8, t.v, "", 0, "L", false, 0, "")
		d.font(false, 7.5)
		d.text(cMuted)
		for j, l := range d.lines(t.k, tw-5) {
			d.SetXY(x+2.5, y+11+float64(j)*3.3)
			d.CellFormat(tw-5, 3.3, l, "", 0, "L", false, 0, "")
		}
	}
	d.SetXY(margin, y+th+2)
}

func pctStr(f float64) string { return fmt.Sprintf("%.0f%%", f*100) }

func (d *pdfDoc) distribution(rep Report) {
	d.heading(d.tx.T("report.distribution"))
	const rowH = 7.0
	d.need(rowH * 5)
	labelW, valueW := 14.0, 26.0
	barW := contentW - labelW - valueW - 4
	for _, b := range rep.Distribution {
		y := d.GetY()
		d.font(true, 10)
		d.text(cInk)
		d.CellFormat(labelW, rowH, fmt.Sprintf("%d ★", b.Stars), "", 0, "L", false, 0, "")
		bx := margin + labelW
		d.fill(cDivider)
		d.RoundedRect(bx, y+2, barW, 3.2, 1.6, "1234", "F")
		if b.Share > 0 {
			switch {
			case b.Stars >= 4:
				d.fill(cGood)
			case b.Stars == 3:
				d.fill(cWarn)
			default:
				d.fill(cBad)
			}
			d.RoundedRect(bx, y+2, max(barW*b.Share, 3.2), 3.2, 1.6, "1234", "F")
		}
		d.SetXY(bx+barW+4, y)
		d.font(false, 9.5)
		d.text(cInk)
		d.CellFormat(valueW, rowH, fmt.Sprintf("%d  (%s)", b.Count, pctStr(b.Share)), "", 1, "L", false, 0, "")
		d.SetX(margin)
	}
}

func (d *pdfDoc) sessions(rep Report) {
	d.heading(d.tx.T("report.sessions"))
	if len(rep.Sessions) == 0 {
		d.font(false, 10)
		d.text(cMuted)
		d.CellFormat(contentW, 6, d.tx.T("report.no_sessions"), "", 1, "L", false, 0, "")
		return
	}
	cols := []float64{8, 76, 28, 16, 36, 16} // #, title, room, avg, bar, count
	heads := []string{"#", d.tx.T("session.title"), d.tx.T("session.zone"), d.tx.T("report.avg"), "", d.tx.T("report.ratings")}
	d.font(true, 8.5)
	d.text(cMuted)
	for i, h := range heads {
		d.CellFormat(cols[i], 6, h, "B", 0, "L", false, 0, "")
	}
	d.Ln(-1)
	d.draw(cDivider)
	for i, s := range rep.Sessions {
		d.font(true, 9.5)
		title := d.lines(s.Session.Title, cols[1]-2)
		d.font(false, 8.5)
		speaker := d.lines(s.Session.Speaker, cols[1]-2)
		rowH := float64(len(title))*4.6 + float64(len(speaker))*4 + 4
		d.need(rowH)
		y := d.GetY()
		x := margin
		d.font(false, 9.5)
		d.text(cMuted)
		rank := "—"
		if s.Count > 0 {
			rank = fmt.Sprint(i + 1)
		}
		d.SetXY(x, y+2)
		d.CellFormat(cols[0], 4.6, rank, "", 0, "L", false, 0, "")
		x += cols[0]
		d.font(true, 9.5)
		d.text(cInk)
		for j, l := range title {
			d.SetXY(x, y+2+float64(j)*4.6)
			d.CellFormat(cols[1], 4.6, l, "", 0, "L", false, 0, "")
		}
		d.font(false, 8.5)
		d.text(cMuted)
		for j, l := range speaker {
			d.SetXY(x, y+2+float64(len(title))*4.6+float64(j)*4)
			d.CellFormat(cols[1], 4, l, "", 0, "L", false, 0, "")
		}
		x += cols[1]
		d.font(false, 9)
		d.text(cInk)
		room := s.ZoneName
		if room == "" {
			room = "—"
		}
		d.SetXY(x, y+2)
		d.CellFormat(cols[2], 4.6, room, "", 0, "L", false, 0, "")
		x += cols[2]
		d.font(true, 10)
		avg := "—"
		if s.Count > 0 {
			avg = d.tx.Rating(s.Avg)
		}
		d.SetXY(x, y+2)
		d.CellFormat(cols[3], 4.6, avg, "", 0, "L", false, 0, "")
		x += cols[3]
		d.fill(cDivider)
		d.RoundedRect(x, y+3, cols[4]-4, 2.8, 1.4, "1234", "F")
		if s.Count > 0 {
			d.fill(cPrimary)
			d.RoundedRect(x, y+3, max((cols[4]-4)*s.Avg/5, 2.8), 2.8, 1.4, "1234", "F")
		}
		x += cols[4]
		d.font(false, 9)
		d.text(cInk)
		d.SetXY(x, y+2)
		d.CellFormat(cols[5], 4.6, fmt.Sprint(s.Count), "", 0, "L", false, 0, "")
		d.Line(margin, y+rowH, margin+contentW, y+rowH)
		d.SetXY(margin, y+rowH)
	}
}

func (d *pdfDoc) comments(rep Report) {
	d.heading(fmt.Sprintf("%s (%d)", d.tx.T("report.comments"), len(rep.Comments)))
	if len(rep.Comments) == 0 {
		d.font(false, 10)
		d.text(cMuted)
		d.CellFormat(contentW, 6, d.tx.T("report.no_comments"), "", 1, "L", false, 0, "")
		return
	}
	d.draw(cDivider)
	for _, c := range rep.Comments {
		d.font(false, 9.5)
		body := d.lines(c.Text, contentW)
		h := 6 + float64(len(body))*4.6 + 3
		d.need(h)
		y := d.GetY()
		author := c.Author
		if author == "" {
			author = d.tx.T("report.anonymous")
		}
		d.font(true, 9.5)
		d.text(cInk)
		aw := d.GetStringWidth(author) + 3
		d.CellFormat(aw, 5, author, "", 0, "L", false, 0, "")
		d.font(false, 9)
		d.text(cMuted)
		d.CellFormat(contentW-aw, 5, fmt.Sprintf("%d ★  ·  %s", c.Rating, d.tx.Day(c.At)), "", 1, "L", false, 0, "")
		d.font(false, 9.5)
		d.text(cInk)
		for _, l := range body {
			d.CellFormat(contentW, 4.6, l, "", 1, "L", false, 0, "")
		}
		d.Line(margin, y+h-1, margin+contentW, y+h-1)
		d.SetXY(margin, y+h)
	}
}
