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
	APIKey  string
	Model   string
	BaseURL string
	Timeout time.Duration
	HTTP    *http.Client
}

const defaultGeminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"

// Name implements Model.
func (g *Gemini) Name() string { return g.Model }

type geminiPart struct {
	Text string `json:"text"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type geminiRequest struct {
	Contents         []geminiContent `json:"contents"`
	GenerationConfig struct {
		Temperature     float64 `json:"temperature"`
		MaxOutputTokens int     `json:"maxOutputTokens"`
	} `json:"generationConfig"`
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
	body.GenerationConfig.MaxOutputTokens = maxTokens
	buf, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("%w: encode: %v", ErrModel, err)
	}

	endpoint := base + "/models/" + url.PathEscape(g.Model) + ":generateContent"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(buf))
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrModel, err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", g.APIKey)

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrModel, err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("%w: read: %v", ErrModel, err)
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("%w: HTTP %d: %s", ErrModel, resp.StatusCode, truncate(string(raw), 300))
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
		sb.WriteString(p.Text)
	}
	text := strings.TrimSpace(sb.String())
	if text == "" {
		return "", fmt.Errorf("%w: empty output (finish reason %s)", ErrModel, out.Candidates[0].FinishReason)
	}
	return text, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
