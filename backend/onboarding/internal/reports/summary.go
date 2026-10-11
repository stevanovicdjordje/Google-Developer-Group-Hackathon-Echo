package reports

import (
	"context"
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
)

// Summary is the text part of "ukupan utisak".
type Summary struct {
	Headline        string
	Liked           []string
	Disliked        []string
	Recommendations []string
}

// FeedbackSummarizer turns a report (incl. comments) into a short summary.
// Gemma will implement it later; StatSummarizer is the interim version. A
// model-backed implementation must treat its output as untrusted text: it is
// only ever rendered (escaped) on the page, never executed or stored as data.
type FeedbackSummarizer interface {
	Summarize(ctx context.Context, r Report) (Summary, error)
}

// StatSummarizer builds the summary from statistics and keyword counts, with
// no AI. T is the i18n lookup, so the generated sentences live in the catalog.
type StatSummarizer struct {
	T func(key string, args ...any) string
}

func (s StatSummarizer) Summarize(_ context.Context, r Report) (Summary, error) {
	t := s.T
	var out Summary
	if r.Reviews == 0 {
		out.Headline = t("sum.no_reviews")
		out.Recommendations = []string{t("sum.rec_ask_reviews")}
		return out, nil
	}
	switch {
	case r.AvgRating >= 4.5:
		out.Headline = t("sum.headline_excellent", r.Reviews)
	case r.AvgRating >= 3.5:
		out.Headline = t("sum.headline_good", r.Reviews)
	case r.AvgRating >= 2.5:
		out.Headline = t("sum.headline_mixed", r.Reviews)
	default:
		out.Headline = t("sum.headline_poor", r.Reviews)
	}

	rated := r.Rated()
	if r.PositiveShare > 0 {
		out.Liked = append(out.Liked, t("sum.positive_share", pct(r.PositiveShare)))
	}
	if len(rated) > 0 && rated[0].Avg >= 4 {
		out.Liked = append(out.Liked, t("sum.best_session", rated[0].Session.Title, httpx.FormatRating(rated[0].Avg)))
	}
	if kw := keywords(r.Comments, func(c Comment) bool { return c.Rating >= 4 }); len(kw) > 0 {
		out.Liked = append(out.Liked, t("sum.positive_words", strings.Join(kw, ", ")))
	}

	if r.NegativeShare > 0 {
		out.Disliked = append(out.Disliked, t("sum.negative_share", pct(r.NegativeShare)))
	}
	var worst *SessionScore
	if len(rated) > 1 && rated[len(rated)-1].Avg < 3.5 {
		worst = &rated[len(rated)-1]
		out.Disliked = append(out.Disliked, t("sum.worst_session", worst.Session.Title, httpx.FormatRating(worst.Avg)))
	}
	if kw := keywords(r.Comments, func(c Comment) bool { return c.Rating <= 2 }); len(kw) > 0 {
		out.Disliked = append(out.Disliked, t("sum.negative_words", strings.Join(kw, ", ")))
	}

	if worst != nil && worst.Avg < 3 {
		out.Recommendations = append(out.Recommendations, t("sum.rec_rethink_session", worst.Session.Title))
	}
	if r.ResponseRate < 0.5 {
		out.Recommendations = append(out.Recommendations, t("sum.rec_more_reviews"))
	}
	if r.Invited > 0 && r.AcceptanceRate < 0.5 {
		out.Recommendations = append(out.Recommendations, t("sum.rec_invite_earlier"))
	}
	if r.NegativeShare >= 0.25 {
		out.Recommendations = append(out.Recommendations, t("sum.rec_read_negative"))
	}
	if len(out.Recommendations) == 0 {
		out.Recommendations = append(out.Recommendations, t("sum.rec_keep_format"))
	}
	return out, nil
}

func pct(f float64) int { return int(f*100 + 0.5) }

// Serbian (and a few English) function words that carry no signal.
var stopwords = map[string]bool{}

func init() {
	for _, w := range strings.Fields(`bilo bila bilo bili biti bude budu čini dobar dobra dobro
		jako jedan jedna jedno kada kako koja koje koji koju malo mnogo možda nije nisu ništa
		onda ovaj ova ovo ovog ovde previše samo sasvim sigurno sledeći svaka svaki sve svi
		svima taj tako takođe tamo toga treba vrlo više zato zbog this that with very
		event eventu eventa događaj događaja predavanje predavanja sesija sesije`) {
		stopwords[w] = true
	}
}

// keywords returns up to three words that appear in at least two of the
// selected comments, most frequent first.
func keywords(comments []Comment, keep func(Comment) bool) []string {
	freq := map[string]int{}
	for _, c := range comments {
		if !keep(c) {
			continue
		}
		seen := map[string]bool{}
		for _, w := range strings.FieldsFunc(strings.ToLower(c.Text), func(r rune) bool { return !unicode.IsLetter(r) }) {
			if utf8.RuneCountInString(w) < 4 || stopwords[w] || seen[w] {
				continue
			}
			seen[w] = true
			freq[w]++
		}
	}
	type kv struct {
		w string
		n int
	}
	var list []kv
	for w, n := range freq {
		if n >= 2 {
			list = append(list, kv{w, n})
		}
	}
	sort.Slice(list, func(i, j int) bool {
		if list[i].n != list[j].n {
			return list[i].n > list[j].n
		}
		return list[i].w < list[j].w
	})
	var out []string
	for i := 0; i < len(list) && i < 3; i++ {
		out = append(out, list[i].w)
	}
	return out
}
