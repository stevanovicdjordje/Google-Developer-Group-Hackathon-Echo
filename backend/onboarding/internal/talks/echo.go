package talks

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/reports"
)

// Echo is what a talk report needs from the Echo service (backend/echo).
type Echo interface {
	// Summary returns the AI summary of the talk in lang, or nil when the
	// talk has none yet.
	Summary(ctx context.Context, eventID, sessionID, lang string) (*reports.TalkSummary, error)
	Questions(ctx context.Context, eventID, sessionID string) ([]reports.TalkQuestion, error)
}

// TokenSource gives an ID token to call other Eho services with.
type TokenSource interface {
	Token(ctx context.Context) (string, error)
}

// HTTPEcho calls Echo's public API (contracts/echo) as this server's service
// user. Summaries can take seconds (model call, cached per session by Echo).
type HTTPEcho struct {
	BaseURL string
	Tokens  TokenSource
	HTTP    *http.Client
}

func (e *HTTPEcho) get(ctx context.Context, path string, out any) error {
	tok, err := e.Tokens.Token(ctx)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(e.BaseURL, "/")+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	client := e.HTTP
	if client == nil {
		client = &http.Client{Timeout: 45 * time.Second}
	}
	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("echo %s: HTTP %d", path, res.StatusCode)
	}
	return json.NewDecoder(res.Body).Decode(out)
}

func sessionPath(eventID, sessionID string) string {
	return "/v1/events/" + url.PathEscape(eventID) + "/sessions/" + url.PathEscape(sessionID)
}

func (e *HTTPEcho) Summary(ctx context.Context, eventID, sessionID, lang string) (*reports.TalkSummary, error) {
	var body struct {
		Text    string `json:"text"`
		Model   string `json:"model"`
		Summary *struct {
			Takeaway  string   `json:"takeaway"`
			KeyPoints []string `json:"keyPoints"`
			Tradeoffs []struct {
				Topic     string `json:"topic"`
				Issue     string `json:"issue"`
				Fix       string `json:"fix"`
				AtSeconds int    `json:"atSeconds"`
			} `json:"tradeoffs"`
		} `json:"summary"`
	}
	if err := e.get(ctx, sessionPath(eventID, sessionID)+"/summary?language="+url.QueryEscape(lang), &body); err != nil {
		return nil, err
	}
	if body.Summary == nil && strings.TrimSpace(body.Text) == "" {
		return nil, nil
	}
	out := &reports.TalkSummary{Text: clip(body.Text, 4000), Model: clip(body.Model, 60)}
	if s := body.Summary; s != nil {
		out.Takeaway = clip(s.Takeaway, 300)
		for _, k := range s.KeyPoints {
			out.KeyPoints = append(out.KeyPoints, clip(k, 300))
		}
		for _, t := range s.Tradeoffs {
			out.Tradeoffs = append(out.Tradeoffs, reports.Tradeoff{Topic: clip(t.Topic, 40), Issue: clip(t.Issue, 300),
				Fix: clip(t.Fix, 300), AtSeconds: max(0, t.AtSeconds)})
		}
	}
	return out, nil
}

func (e *HTTPEcho) Questions(ctx context.Context, eventID, sessionID string) ([]reports.TalkQuestion, error) {
	var body struct {
		Questions []struct {
			Text  string `json:"text"`
			Votes int    `json:"votes"`
		} `json:"questions"`
	}
	if err := e.get(ctx, sessionPath(eventID, sessionID)+"/questions", &body); err != nil {
		return nil, err
	}
	var out []reports.TalkQuestion
	for _, q := range body.Questions {
		out = append(out, reports.TalkQuestion{Text: clip(q.Text, 500), Votes: max(0, q.Votes)})
	}
	return out, nil
}

// clip bounds model/user text before it goes into the PDF (untrusted input).
func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if r := []rune(s); len(r) > n {
		return string(r[:n]) + "…"
	}
	return s
}

// FakeEcho is an Echo for tests and for running without the Echo service.
type FakeEcho struct {
	Sum *reports.TalkSummary
	Qs  []reports.TalkQuestion
	Err error
}

func (f FakeEcho) Summary(context.Context, string, string, string) (*reports.TalkSummary, error) {
	return f.Sum, f.Err
}

func (f FakeEcho) Questions(context.Context, string, string) ([]reports.TalkQuestion, error) {
	return f.Qs, f.Err
}
