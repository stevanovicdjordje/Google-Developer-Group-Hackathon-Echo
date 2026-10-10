package assist

import (
	"cmp"
	"context"
	"slices"
	"strings"
	"unicode"

	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

// OfflineModel is the model name reported when no AI key is configured.
const OfflineModel = "offline"

// Offline answers by quoting the transcript. It needs no network, so local
// development and tests run without an API key. It always answers in English
// and marks translations instead of translating.
type Offline struct{}

var _ Assistant = Offline{}

// Model implements Assistant.
func (Offline) Model() string { return OfflineModel }

const notCovered = "The speaker hasn't covered that yet."

// Ask implements Assistant: the (up to) two lines sharing the most words with the question.
func (Offline) Ask(_ context.Context, lines []store.Line, question, _ string) (string, error) {
	q := words(question)
	lw := make([]map[string]bool, len(lines))
	df := map[string]int{}
	for i, l := range lines {
		lw[i] = words(l.Text)
		for w := range lw[i] {
			df[w]++
		}
	}
	type scored struct {
		i     int
		score float64
	}
	var best []scored
	for i := range lines {
		s := 0.0
		for w := range lw[i] {
			if q[w] {
				s += 1 / float64(df[w])
			}
		}
		if s > 0 {
			best = append(best, scored{i, s})
		}
	}
	if len(best) == 0 {
		return notCovered, nil
	}
	slices.SortStableFunc(best, func(a, b scored) int { return cmp.Compare(b.score, a.score) })
	best = best[:min(2, len(best))]
	slices.SortFunc(best, func(a, b scored) int { return a.i - b.i })
	parts := make([]string, len(best))
	for k, b := range best {
		parts[k] = lines[b.i].Text
	}
	return "From the talk: " + strings.Join(parts, " "), nil
}

// CatchUp implements Assistant: the opening line and the latest two.
func (Offline) CatchUp(_ context.Context, lines []store.Line, _ string) (string, error) {
	if len(lines) == 0 {
		return "The talk hasn't started yet.", nil
	}
	pick := []int{0}
	for i := max(1, len(lines)-2); i < len(lines); i++ {
		pick = append(pick, i)
	}
	parts := make([]string, len(pick))
	for k, i := range pick {
		parts[k] = lines[i].Text
	}
	return "So far: " + strings.Join(parts, " … "), nil
}

// Summary implements Assistant: up to six evenly spaced lines as bullets.
func (Offline) Summary(_ context.Context, lines []store.Line, _ string) (string, error) {
	if len(lines) == 0 {
		return "The talk hasn't started yet.", nil
	}
	n := min(6, len(lines))
	out := make([]string, n)
	for k := range n {
		out[k] = "• " + lines[k*len(lines)/n].Text
	}
	return strings.Join(out, "\n"), nil
}

// Translate implements Assistant: the source text, tagged with the language.
func (Offline) Translate(_ context.Context, texts []string, language string) ([]string, error) {
	out := make([]string, len(texts))
	for i, t := range texts {
		out[i] = "[" + language + "] " + t
	}
	return out, nil
}

var stopwords = map[string]bool{
	"the": true, "and": true, "for": true, "you": true, "are": true, "was": true, "what": true, "how": true,
	"did": true, "does": true, "that": true, "this": true, "with": true, "about": true, "they": true, "say": true,
	"said": true, "can": true, "why": true, "when": true, "who": true, "which": true, "his": true, "her": true,
	"speaker": true, "talk": true,
}

func words(s string) map[string]bool {
	out := map[string]bool{}
	for _, w := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}) {
		if len(w) >= 3 && !stopwords[w] {
			out[strings.TrimSuffix(w, "s")] = true
		}
	}
	return out
}
