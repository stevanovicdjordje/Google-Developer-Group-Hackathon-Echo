// Package match ranks attendees for recommendations and prompt search.
// Gemini sends anonymised profiles to Gemma through the Gemini API; Offline
// ranks by overlap and is the fallback whenever the model fails.
package match

import (
	"context"
	"strings"
	"unicode"
	"unicode/utf8"
)

// OfflineModel is the model name reported for overlap ranking.
const OfflineModel = "offline"

// MaxWhy is the longest `why` returned (runes).
const MaxWhy = 240

// MaxModelCandidates is how many candidates are sent to the model at most.
const MaxModelCandidates = 40

// Profile is the part of a profile used for matching. The caller's profile
// carries no name.
type Profile struct {
	Headline   string
	Interests  []string
	LookingFor string
}

// Candidate is a visible attendee. Key is an opaque handle the caller maps
// back (never sent to the model); Name is only used for stable offline
// tie-breaks and is never sent to the model either.
type Candidate struct {
	Key  string
	Name string
	Profile
}

// Pick is one ranked candidate with a short plain-text reason.
type Pick struct {
	Key string
	Why string
}

// Result is a ranking and the model that produced it.
type Result struct {
	Picks []Pick
	Model string
}

// Matcher ranks candidates. Implementations never fail the request: errors
// mean a programming bug or a cancelled context.
type Matcher interface {
	// Model is the configured model name (or "offline").
	Model() string
	// Recommend ranks candidates for me, best first, at most limit.
	Recommend(ctx context.Context, me Profile, cands []Candidate, limit int) (Result, error)
	// Search returns the candidates who fit prompt, best first, at most limit.
	Search(ctx context.Context, prompt string, cands []Candidate, limit int) (Result, error)
}

// CleanWhy makes model or generated text a single plain line of at most MaxWhy runes.
func CleanWhy(s string) string {
	s = strings.Map(func(r rune) rune {
		switch {
		case r == '\n' || r == '\r' || r == '\t':
			return ' '
		case unicode.IsControl(r), r == '*', r == '`', r == '#':
			return -1
		}
		return r
	}, s)
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) > MaxWhy {
		r := []rune(s)
		s = strings.TrimSpace(string(r[:MaxWhy-1])) + "…"
	}
	return s
}
