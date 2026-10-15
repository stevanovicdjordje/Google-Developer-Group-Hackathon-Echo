package assist

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Model generates text from a prompt. It is the adapter boundary for the LLM.
type Model interface {
	Name() string
	Generate(ctx context.Context, prompt string, maxTokens int) (string, error)
}

// ErrModel wraps every model failure (transport, quota, empty or blocked output).
var ErrModel = errors.New("model call failed")

// Gemini calls a Gemma model through the Gemini API (generateContent).
type Gemini struct {
	APIKey string
	Model  string
	// Thinking is sent as thinkingConfig.thinkingLevel when set. Gemma 4 thinks
	// by default, which costs seconds and tokens; "minimal" turns it off.
	Thinking string
	// OutputPad is added to every call's token budget. Gemini 3 models spend
	// output tokens on thinking first, so short budgets would otherwise come
	// back empty. The visible answer is still capped by the prompt and CleanText.
	OutputPad int
	BaseURL   string
	Timeout   time.Duration
	HTTP      *http.Client
}

const defaultGeminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"

// retryBackoff is the wait before each retry of an HTTP 5xx, which the Gemini
// API returns now and then for Gemma.
var retryBackoff = []time.Duration{300 * time.Millisecond, time.Second}

// Name implements Model.
func (g *Gemini) Name() string { return g.Model }

type geminiPart struct {
	Text    string `json:"text"`
	Thought bool   `json:"thought,omitempty"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type geminiRequest struct {
	Contents         []geminiContent `json:"contents"`
	GenerationConfig struct {
		Temperature     float64         `json:"temperature"`
		MaxOutputTokens int             `json:"maxOutputTokens"`
		ThinkingConfig  *thinkingConfig `json:"thinkingConfig,omitempty"`
	} `json:"generationConfig"`
}

type thinkingConfig struct {
	ThinkingLevel string `json:"thinkingLevel"`
}

type geminiResponse struct {
	Candidates []struct {
		Content      geminiContent `json:"content"`
		FinishReason string        `json:"finishReason"`
	} `json:"candidates"`
	PromptFeedback *struct {
		BlockReason string `json:"blockReason"`
	} `json:"promptFeedback"`
}

// Generate implements Model. Gemma on the Gemini API has no system
// instruction, so the whole instruction is in the user turn.
func (g *Gemini) Generate(ctx context.Context, prompt string, maxTokens int) (string, error) {
	base := g.BaseURL
	if base == "" {
		base = defaultGeminiBaseURL
	}
	client := g.HTTP
	if client == nil {
		client = http.DefaultClient
	}
	if g.Timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, g.Timeout)
		defer cancel()
	}

	var body geminiRequest
	body.Contents = []geminiContent{{Role: "user", Parts: []geminiPart{{Text: prompt}}}}
	body.GenerationConfig.Temperature = 0.2
	body.GenerationConfig.MaxOutputTokens = maxTokens + g.OutputPad
	if g.Thinking != "" {
		body.GenerationConfig.ThinkingConfig = &thinkingConfig{ThinkingLevel: g.Thinking}
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("%w: encode: %v", ErrModel, err)
	}

	endpoint := base + "/models/" + url.PathEscape(g.Model) + ":generateContent"
	var raw []byte
	for attempt := 0; ; attempt++ {
		var status int
		status, raw, err = g.post(ctx, client, endpoint, buf)
		if err != nil {
			return "", err
		}
		if status == http.StatusOK {
			break
		}
		if status >= 500 && attempt < len(retryBackoff) {
			select {
			case <-ctx.Done():
				return "", fmt.Errorf("%w: %v", ErrModel, ctx.Err())
			case <-time.After(retryBackoff[attempt]):
			}
			continue
		}
		return "", fmt.Errorf("%w: HTTP %d: %s", ErrModel, status, truncate(string(raw), 300))
	}

	var out geminiResponse
	if err := json.Unmarshal(raw, &out); err != nil {
		return "", fmt.Errorf("%w: decode: %v", ErrModel, err)
	}
	if out.PromptFeedback != nil && out.PromptFeedback.BlockReason != "" {
		return "", fmt.Errorf("%w: prompt blocked (%s)", ErrModel, out.PromptFeedback.BlockReason)
	}
	if len(out.Candidates) == 0 {
		return "", fmt.Errorf("%w: no candidates", ErrModel)
	}
	var sb strings.Builder
	for _, p := range out.Candidates[0].Content.Parts {
		if !p.Thought {
			sb.WriteString(p.Text)
		}
	}
	text := strings.TrimSpace(sb.String())
	if text == "" {
		return "", fmt.Errorf("%w: empty output (finish reason %s)", ErrModel, out.Candidates[0].FinishReason)
	}
	return text, nil
}

func (g *Gemini) post(ctx context.Context, client *http.Client, endpoint string, body []byte) (int, []byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return 0, nil, fmt.Errorf("%w: %v", ErrModel, err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", g.APIKey)
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("%w: %v", ErrModel, err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return 0, nil, fmt.Errorf("%w: read: %v", ErrModel, err)
	}
	return resp.StatusCode, raw, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
