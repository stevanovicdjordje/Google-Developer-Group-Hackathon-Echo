package assist

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"unicode"

	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

// Summary is the structured talk summary (contract: TalkSummary).
type Summary struct {
	Takeaway  string     `json:"takeaway"`
	KeyPoints []string   `json:"keyPoints"`
	Tradeoffs []Tradeoff `json:"tradeoffs"`
}

// Tradeoff is one "problem → fix" row, linked to the transcript time.
type Tradeoff struct {
	Topic     string `json:"topic"`
	Issue     string `json:"issue"`
	Fix       string `json:"fix"`
	AtSeconds int    `json:"atSeconds"`
	// At is the "mm:ss" label the model copies from the transcript; it is
	// turned into AtSeconds and never sent to clients.
	At string `json:"at,omitempty"`
}

// Text renders the summary as the plain text older clients show.
func (s Summary) Text() string {
	var b strings.Builder
	b.WriteString(s.Takeaway)
	if len(s.KeyPoints) > 0 {
		b.WriteString("\n")
		for _, k := range s.KeyPoints {
			b.WriteString("\n• " + k)
		}
	}
	for _, t := range s.Tradeoffs {
		fmt.Fprintf(&b, "\n• %s: %s → %s (%02d:%02d)", t.Topic, t.Issue, t.Fix, t.AtSeconds/60, t.AtSeconds%60)
	}
	return b.String()
}

const (
	maxSummaryItem  = 300
	maxSummaryTopic = 40
	maxKeyPoints    = 5
	maxTradeoffs    = 5
)

// Summary implements Assistant. It asks for JSON and retries once if the
// shape is wrong.
func (a LLM) Summary(ctx context.Context, t store.Transcript, language string) (Summary, error) {
	prompt := "You are Echo. Summarize a conference talk for an attendee to keep.\n" + guard + "\n" +
		"Write every string in " + Languages[language] + ". Return only one JSON object, no markdown, with exactly these keys:\n" +
		`{"takeaway": "the speaker's single most important advice, as close to their own words as possible, at most 15 words",` + "\n" +
		` "keyPoints": ["2 to 3 short points (at most 20 words each) with the concrete numbers the speaker gave, not repeating the tradeoffs"],` + "\n" +
		` "tradeoffs": [{"topic": "1-2 words, e.g. Battery", "issue": "the problem, with numbers, at most 12 words", "fix": "how it was solved, at most 12 words", "at": "00:44"}]}` + "\n" +
		"List 0 to 4 tradeoffs: only problems the speaker named together with their fix. " +
		"\"at\" is copied exactly from the [mm:ss] label of the FIRST transcript line where that problem is mentioned.\n\n" +
		formatTranscript(t)
	var lastErr error
	for range 2 {
		out, err := a.M.Generate(ctx, prompt, 900)
		if err != nil {
			return Summary{}, err
		}
		sum, err := ParseSummary(out, t.Lines)
		if err == nil {
			return sum, nil
		}
		lastErr = err
	}
	return Summary{}, lastErr
}

// ParseSummary extracts and validates the model's JSON summary. Times are
// snapped to the start of a real transcript line.
func ParseSummary(out string, lines []store.Line) (Summary, error) {
	start, end := strings.Index(out, "{"), strings.LastIndex(out, "}")
	if start < 0 || end <= start {
		return Summary{}, fmt.Errorf("%w: no JSON object in summary", ErrModel)
	}
	var s Summary
	if err := json.Unmarshal([]byte(out[start:end+1]), &s); err != nil {
		return Summary{}, fmt.Errorf("%w: summary is not the expected JSON: %v", ErrModel, err)
	}
	var err error
	if s.Takeaway, err = cleanItem(s.Takeaway, maxSummaryItem); err != nil {
		return Summary{}, err
	}
	var points []string
	for _, k := range s.KeyPoints {
		if k, err = cleanItem(k, maxSummaryItem); err == nil {
			points = append(points, k)
		}
	}
	if len(points) == 0 {
		return Summary{}, fmt.Errorf("%w: summary has no key points", ErrModel)
	}
	s.KeyPoints = points[:min(len(points), maxKeyPoints)]
	var rows []Tradeoff
	for _, r := range s.Tradeoffs {
		var e1, e2, e3 error
		r.Topic, e1 = cleanItem(r.Topic, maxSummaryTopic)
		r.Issue, e2 = cleanItem(r.Issue, maxSummaryItem)
		r.Issue = strings.TrimRight(r.Issue, ".")
		r.Fix, e3 = cleanItem(r.Fix, maxSummaryItem)
		if e1 != nil || e2 != nil || e3 != nil {
			continue
		}
		if sec, ok := parseClock(r.At); ok {
			r.AtSeconds = sec
		}
		r.AtSeconds = snapToLine(r.AtSeconds, lines)
		r.At = ""
		rows = append(rows, r)
	}
	s.Tradeoffs = rows[:min(len(rows), maxTradeoffs)]
	if s.Tradeoffs == nil {
		s.Tradeoffs = []Tradeoff{}
	}
	return s, nil
}

func parseClock(s string) (int, bool) {
	var m, sec int
	if _, err := fmt.Sscanf(strings.Trim(strings.TrimSpace(s), "[]"), "%d:%d", &m, &sec); err != nil || m < 0 || sec < 0 || sec > 59 {
		return 0, false
	}
	return m*60 + sec, true
}

func cleanItem(s string, maxRunes int) (string, error) {
	s = strings.Join(strings.Fields(reBold.ReplaceAllString(s, "$1$2")), " ")
	s = strings.TrimLeft(s, "•-* ")
	if s == "" {
		return "", fmt.Errorf("%w: empty summary item", ErrModel)
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	if len(r) > maxRunes {
		r = append([]rune(strings.TrimSpace(string(r[:maxRunes-1]))), '…')
	}
	return string(r), nil
}

// snapToLine returns the start time of the last line at or before sec, so a
// summary row never points past the transcript or between lines.
func snapToLine(sec int, lines []store.Line) int {
	if len(lines) == 0 {
		return 0
	}
	i, found := slices.BinarySearchFunc(lines, sec, func(l store.Line, s int) int { return l.AtSeconds - s })
	if found {
		return lines[i].AtSeconds
	}
	if i == 0 {
		return lines[0].AtSeconds
	}
	return lines[i-1].AtSeconds
}

// Summary implements Assistant: the speaker's advice line (or the last line)
// as takeaway, evenly spaced lines as key points, and lines with numbers as
// trade-off rows.
func (Offline) Summary(_ context.Context, t store.Transcript, _ string) (Summary, error) {
	lines := t.Lines
	if len(lines) == 0 {
		return Summary{}, fmt.Errorf("%w: no transcript", ErrModel)
	}
	s := Summary{Takeaway: lines[len(lines)-1].Text, Tradeoffs: []Tradeoff{}}
	for _, l := range lines {
		if strings.Contains(strings.ToLower(l.Text), "advice") {
			s.Takeaway = l.Text
		}
	}
	n := min(3, len(lines))
	for k := range n {
		s.KeyPoints = append(s.KeyPoints, lines[k*len(lines)/n].Text)
	}
	for i, l := range lines {
		if len(s.Tradeoffs) == 3 || i+1 >= len(lines) {
			break
		}
		if strings.IndexFunc(l.Text, func(r rune) bool { return r >= '0' && r <= '9' }) >= 0 ||
			strings.Contains(l.Text, "percent") {
			s.Tradeoffs = append(s.Tradeoffs, Tradeoff{Topic: "Point", Issue: l.Text, Fix: lines[i+1].Text, AtSeconds: l.AtSeconds})
		}
	}
	return s, nil
}
