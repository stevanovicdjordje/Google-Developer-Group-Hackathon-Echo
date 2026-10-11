package assist

import (
	"context"

	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

// Routed sends Translate to one Assistant and everything else to another, so
// each Echo feature can use the model that suits it
// (docs/decisions/feature-echo-ai.md).
type Routed struct {
	// Main answers Ask, Catch up, Summary and question grouping.
	Main Assistant
	// Translator handles Translate.
	Translator Assistant
}

var _ Assistant = Routed{}

// Model implements Assistant: the model behind Ask, Catch up and Summary.
func (r Routed) Model() string { return r.Main.Model() }

// TranslationModel names the model behind Translate.
func (r Routed) TranslationModel() string { return r.Translator.Model() }

// Ask implements Assistant.
func (r Routed) Ask(ctx context.Context, t store.Transcript, question, language string) (string, error) {
	return r.Main.Ask(ctx, t, question, language)
}

// CatchUp implements Assistant.
func (r Routed) CatchUp(ctx context.Context, t store.Transcript, language string) (string, error) {
	return r.Main.CatchUp(ctx, t, language)
}

// Summary implements Assistant.
func (r Routed) Summary(ctx context.Context, t store.Transcript, language string) (Summary, error) {
	return r.Main.Summary(ctx, t, language)
}

// SameQuestion implements Assistant.
func (r Routed) SameQuestion(ctx context.Context, existing []QuestionRef, question string) (string, error) {
	return r.Main.SameQuestion(ctx, existing, question)
}

// Translate implements Assistant.
func (r Routed) Translate(ctx context.Context, texts []string, language string) ([]string, error) {
	return r.Translator.Translate(ctx, texts, language)
}

// TranslationModel returns the model that a's Translate uses.
func TranslationModel(a Assistant) string {
	if t, ok := a.(interface{ TranslationModel() string }); ok {
		return t.TranslationModel()
	}
	return a.Model()
}
