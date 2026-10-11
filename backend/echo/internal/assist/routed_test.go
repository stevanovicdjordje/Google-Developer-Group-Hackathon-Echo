package assist

import (
	"context"
	"testing"

	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

type namedModel struct {
	name  string
	calls *[]string
}

func (m namedModel) Name() string { return m.name }

func (m namedModel) Generate(_ context.Context, _ string, _ int) (string, error) {
	*m.calls = append(*m.calls, m.name)
	return `["prevod"]`, nil
}

func TestRoutedSendsTranslateToTranslator(t *testing.T) {
	var calls []string
	r := Routed{
		Main:       LLM{M: namedModel{"gemini-main", &calls}},
		Translator: LLM{M: namedModel{"gemma-translate", &calls}},
	}
	if r.Model() != "gemini-main" || TranslationModel(r) != "gemma-translate" {
		t.Fatalf("models: %q / %q", r.Model(), TranslationModel(r))
	}
	if TranslationModel(LLM{M: namedModel{"solo", &calls}}) != "solo" {
		t.Fatal("plain assistant should translate with its own model")
	}

	if _, err := r.Translate(context.Background(), []string{"hello"}, "sr"); err != nil {
		t.Fatal(err)
	}
	_, _ = r.Ask(context.Background(), store.Transcript{Lines: []store.Line{{Text: "hi"}}}, "q?", "en")
	if len(calls) != 2 || calls[0] != "gemma-translate" || calls[1] != "gemini-main" {
		t.Fatalf("calls = %v", calls)
	}
}
