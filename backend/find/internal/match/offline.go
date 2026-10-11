package match

import (
	"context"
	"sort"
	"strings"
	"unicode"
)

// Offline ranks by overlap of interests and words. Deterministic, no AI.
type Offline struct{}

var _ Matcher = Offline{}

// Model implements Matcher.
func (Offline) Model() string { return OfflineModel }

type scored struct {
	c       Candidate
	primary int
	words   int
	why     string
}

func sortScored(s []scored) {
	sort.SliceStable(s, func(i, j int) bool {
		if s[i].primary != s[j].primary {
			return s[i].primary > s[j].primary
		}
		if s[i].words != s[j].words {
			return s[i].words > s[j].words
		}
		if s[i].c.Name != s[j].c.Name {
			return s[i].c.Name < s[j].c.Name
		}
		return s[i].c.Key < s[j].c.Key
	})
}

// Recommend implements Matcher: every candidate, sorted by shared interests,
// then word overlap, then name.
func (Offline) Recommend(_ context.Context, me Profile, cands []Candidate, limit int) (Result, error) {
	mine := map[string]bool{}
	for _, i := range me.Interests {
		mine[strings.ToLower(strings.TrimSpace(i))] = true
	}
	myWords := words(me.Headline + " " + me.LookingFor + " " + strings.Join(me.Interests, " "))
	list := make([]scored, 0, len(cands))
	for _, c := range cands {
		var shared []string
		for _, i := range c.Interests {
			if mine[strings.ToLower(strings.TrimSpace(i))] {
				shared = append(shared, i)
			}
		}
		common := overlap(myWords, words(c.Headline+" "+c.LookingFor+" "+strings.Join(c.Interests, " ")))
		list = append(list, scored{c: c, primary: len(shared), words: len(common), why: recommendWhy(c, shared, common)})
	}
	sortScored(list)
	return result(list, limit), nil
}

func recommendWhy(c Candidate, shared, common []string) string {
	var parts []string
	switch {
	case len(shared) > 0:
		parts = append(parts, "You both care about "+joinAnd(shared)+".")
	case len(common) > 0:
		parts = append(parts, "Overlaps with your profile on "+joinAnd(common)+".")
	case strings.TrimSpace(c.Headline) != "":
		parts = append(parts, sentence(c.Headline))
	}
	if lf := strings.TrimSpace(c.LookingFor); lf != "" {
		parts = append(parts, "Looking for: "+sentence(lowerFirst(lf)))
	}
	if len(parts) == 0 {
		return "Also at this event."
	}
	return CleanWhy(strings.Join(parts, " "))
}

// Search implements Matcher: candidates with any word of the prompt in their
// headline, interests or lookingFor; the others are left out.
func (Offline) Search(_ context.Context, prompt string, cands []Candidate, limit int) (Result, error) {
	pw := words(prompt)
	pShort := tokens(prompt, 2)
	list := make([]scored, 0, len(cands))
	for _, c := range cands {
		var interests []string
		for _, i := range c.Interests {
			if len(overlapExact(tokens(i, 2), pShort)) > 0 {
				interests = append(interests, i)
			}
		}
		common := overlap(pw, words(c.Headline+" "+c.LookingFor+" "+strings.Join(c.Interests, " ")))
		if len(interests) == 0 && len(common) == 0 {
			continue
		}
		list = append(list, scored{c: c, primary: len(interests)*2 + len(common), words: len(common), why: searchWhy(c, interests, common)})
	}
	sortScored(list)
	return result(list, limit), nil
}

func searchWhy(c Candidate, interests, common []string) string {
	var parts []string
	if len(interests) > 0 {
		parts = append(parts, "Into "+joinAnd(interests)+".")
	}
	if len(common) > 0 {
		parts = append(parts, "Matches "+joinAnd(common)+".")
	}
	if h := strings.TrimSpace(c.Headline); h != "" {
		parts = append(parts, sentence(h))
	}
	if lf := strings.TrimSpace(c.LookingFor); lf != "" {
		parts = append(parts, "Looking for: "+sentence(lowerFirst(lf)))
	}
	return CleanWhy(strings.Join(parts, " "))
}

func result(list []scored, limit int) Result {
	out := Result{Model: OfflineModel, Picks: []Pick{}}
	for _, s := range list {
		if len(out.Picks) >= limit {
			break
		}
		out.Picks = append(out.Picks, Pick{Key: s.c.Key, Why: s.why})
	}
	return out
}

func sentence(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimRight(s, ".!? ")
	return s + "."
}

func lowerFirst(s string) string {
	r := []rune(s)
	// Keep acronyms ("AI researchers") as they are.
	if len(r) > 1 && unicode.IsUpper(r[0]) && !unicode.IsUpper(r[1]) {
		r[0] = unicode.ToLower(r[0])
	}
	return string(r)
}

func joinAnd(items []string) string {
	switch len(items) {
	case 0:
		return ""
	case 1:
		return items[0]
	}
	return strings.Join(items[:len(items)-1], ", ") + " and " + items[len(items)-1]
}

var diacritics = strings.NewReplacer("č", "c", "ć", "c", "ž", "z", "š", "s", "đ", "dj")

// tokens lowercases s, strips Serbian diacritics and splits it into words of
// at least minLen runes, dropping stopwords.
func tokens(s string, minLen int) []string {
	s = diacritics.Replace(strings.ToLower(s))
	var out []string
	for _, f := range strings.FieldsFunc(s, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }) {
		if len([]rune(f)) >= minLen && !stopwords[f] {
			out = append(out, f)
		}
	}
	return out
}

// words are the tokens longer than two characters.
func words(s string) []string { return tokens(s, 3) }

// wordMatch is equality or a plural/suffix prefix match (engineer/engineers).
func wordMatch(a, b string) bool {
	if a == b {
		return true
	}
	if len(a) > len(b) {
		a, b = b, a
	}
	return len(a) >= 4 && strings.HasPrefix(b, a) && len(b)-len(a) <= 3
}

// overlap returns the words of q (deduplicated, in order) that match a word of doc.
func overlap(q, doc []string) []string {
	var out []string
	seen := map[string]bool{}
	for _, w := range q {
		if seen[w] {
			continue
		}
		for _, d := range doc {
			if wordMatch(w, d) {
				seen[w] = true
				out = append(out, w)
				break
			}
		}
	}
	return out
}

func overlapExact(a, b []string) []string {
	var out []string
	for _, x := range a {
		for _, y := range b {
			if x == y {
				out = append(out, x)
				break
			}
		}
	}
	return out
}

var stopwords = func() map[string]bool {
	m := map[string]bool{}
	for _, w := range strings.Fields(`a an the and or but nor not no so of to in on at by for with from into onto over under
		about as is are was were be been being am do does did doing has have had having can could would should
		will shall may might must i me my we us our you your he him his she her they them their it its this that
		these those who whom whose which what when where why how all any some each every other such than then
		there here very really just also more most much many few one two someone somebody anyone anybody
		everyone people person persons guy guys folks find looking look want wants wanted need needs needed
		like know knows meet meeting talk talking chat interested interest working work works good great new
		get got make made let lets please help`) {
		m[w] = true
	}
	return m
}()
