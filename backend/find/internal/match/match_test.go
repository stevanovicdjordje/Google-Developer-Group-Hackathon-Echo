package match

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"unicode/utf8"
)

var people = []Candidate{
	{Key: "k-teo", Name: "Teodora Nikolić", Profile: Profile{Headline: "ML researcher, Univ. of Belgrade", Interests: []string{"AI / ML", "Data"}, LookingFor: "Industry partners for speech models"}},
	{Key: "k-stefan", Name: "Stefan Lazić", Profile: Profile{Headline: "Backend lead at Nebo Cloud", Interests: []string{"Backend", "Cloud"}, LookingFor: "Senior Go engineers"}},
	{Key: "k-nina", Name: "Nina Popović", Profile: Profile{Headline: "Designer at Talas AI", Interests: []string{"Design", "AI / ML"}, LookingFor: "Mobile devs to prototype with"}},
	{Key: "k-vuk", Name: "Vuk Tomić", Profile: Profile{Headline: "CTO, Mreža", Interests: []string{"Startups", "Backend", "Hiring"}, LookingFor: "Mobile engineers to hire"}},
	{Key: "k-aleksa", Name: "Aleksa Kovačević", Profile: Profile{Headline: "Junior Android dev", Interests: []string{"Mobile"}, LookingFor: "A mentor in mobile AI"}},
}

var ana = Profile{Headline: "Android dev at Fintio", Interests: []string{"Mobile", "AI / ML"}, LookingFor: "People who shipped on-device ML in production"}

func keys(r Result) []string {
	var out []string
	for _, p := range r.Picks {
		out = append(out, p.Key)
	}
	return out
}

func TestOfflineRecommend(t *testing.T) {
	r, err := Offline{}.Recommend(context.Background(), ana, people, 8)
	if err != nil || r.Model != OfflineModel {
		t.Fatal(r, err)
	}
	got := keys(r)
	if len(got) != len(people) {
		t.Fatalf("all candidates expected: %v", got)
	}
	// Two shared interests beats one; Stefan shares nothing and is last.
	if got[0] != "k-aleksa" && got[0] != "k-nina" && got[0] != "k-teo" {
		t.Fatalf("order %v", got)
	}
	if got[len(got)-1] != "k-stefan" {
		t.Fatalf("order %v", got)
	}
	for _, p := range r.Picks {
		if p.Why == "" || utf8.RuneCountInString(p.Why) > MaxWhy || strings.Contains(p.Why, "\n") {
			t.Fatalf("why %q", p.Why)
		}
		low := " " + strings.ToLower(p.Why) + " "
		for _, pron := range []string{" he ", " she ", " they ", " his ", " her ", " their "} {
			if strings.Contains(low, pron) {
				t.Fatalf("pronoun in %q", p.Why)
			}
		}
	}
	var nina string
	for _, p := range r.Picks {
		if p.Key == "k-nina" {
			nina = p.Why
		}
	}
	if nina != "You both care about AI / ML. Looking for: Mobile devs to prototype with." {
		t.Fatalf("nina why %q", nina)
	}
	// Deterministic, and limit applies.
	r2, _ := Offline{}.Recommend(context.Background(), ana, people, 2)
	if len(r2.Picks) != 2 || r2.Picks[0] != r.Picks[0] || r2.Picks[1] != r.Picks[1] {
		t.Fatalf("limit/determinism %v vs %v", r2.Picks, r.Picks[:2])
	}
}

func TestOfflineSearch(t *testing.T) {
	ctx := context.Background()
	r, _ := Offline{}.Search(ctx, "someone hiring mobile engineers", people, 8)
	got := keys(r)
	if len(got) == 0 || got[0] != "k-vuk" {
		t.Fatalf("got %v", got)
	}
	if !strings.Contains(r.Picks[0].Why, "Hiring") || !strings.Contains(r.Picks[0].Why, "engineers") {
		t.Fatalf("why %q", r.Picks[0].Why)
	}
	// Plural prefix match and diacritics.
	r, _ = Offline{}.Search(ctx, "engineer", people, 8)
	if g := keys(r); len(g) != 2 {
		t.Fatalf("engineer: %v", g)
	}
	r, _ = Offline{}.Search(ctx, "Mreža CTO", people, 8)
	if g := keys(r); len(g) != 1 || g[0] != "k-vuk" {
		t.Fatalf("mreza: %v", g)
	}
	r, _ = Offline{}.Search(ctx, "mreza", people, 8)
	if g := keys(r); len(g) != 1 {
		t.Fatalf("mreza ascii: %v", g)
	}
	// Short interest tokens ("ML") match interests.
	r, _ = Offline{}.Search(ctx, "ML people", people, 8)
	if g := keys(r); len(g) != 2 {
		t.Fatalf("ml: %v", g)
	}
	// Stopwords only / no match: empty, not nil.
	r, _ = Offline{}.Search(ctx, "someone who is looking for people", people, 8)
	if r.Picks == nil || len(r.Picks) != 0 {
		t.Fatalf("stopwords: %v", r.Picks)
	}
}

// fakeGemini answers generateContent with the given texts (one per call) and
// records the prompts.
type fakeGemini struct {
	texts   []string
	status  []int
	calls   atomic.Int32
	prompts []string
}

func (f *fakeGemini) server(t *testing.T) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := int(f.calls.Add(1)) - 1
		if r.Header.Get("x-goog-api-key") != "key" || !strings.HasSuffix(r.URL.Path, "/models/gemma-test:generateContent") {
			t.Errorf("bad request %s", r.URL.Path)
		}
		var req geminiRequest
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &req)
		f.prompts = append(f.prompts, req.Contents[0].Parts[0].Text)
		if n < len(f.status) && f.status[n] != 200 {
			w.WriteHeader(f.status[n])
			return
		}
		text := f.texts[min(n, len(f.texts)-1)]
		_ = json.NewEncoder(w).Encode(map[string]any{"candidates": []any{map[string]any{
			"content": map[string]any{"parts": []any{map[string]any{"text": text}}}, "finishReason": "STOP",
		}}})
	}))
	t.Cleanup(srv.Close)
	return srv
}

func newGemini(t *testing.T, f *fakeGemini) *Gemini {
	return &Gemini{APIKey: "key", ModelName: "gemma-test", BaseURL: f.server(t).URL, Log: slog.New(slog.NewTextHandler(io.Discard, nil))}
}

func TestGeminiValidJSON(t *testing.T) {
	f := &fakeGemini{texts: []string{`[{"c":"c3","why":"Designer who wants mobile devs to prototype AI products with."},{"c":"c1","why":"Works on speech models."}]`}}
	g := newGemini(t, f)
	r, err := g.Recommend(context.Background(), ana, people, 8)
	if err != nil || r.Model != "gemma-test" {
		t.Fatal(r, err)
	}
	if got := keys(r); len(got) != 2 || got[0] != "k-nina" || got[1] != "k-teo" {
		t.Fatalf("got %v", got)
	}
	// Privacy: the prompt carries no names or keys.
	p := f.prompts[0]
	for _, c := range people {
		if strings.Contains(p, c.Name) || strings.Contains(p, c.Key) {
			t.Fatalf("prompt leaks %s / %s", c.Name, c.Key)
		}
	}
	if !strings.Contains(p, "Industry partners for speech models") || !strings.Contains(p, "c5:") || !strings.Contains(p, "Android dev at Fintio") {
		t.Fatalf("prompt misses profile data:\n%s", p)
	}
}

func TestGeminiFencedJSONAndCleanup(t *testing.T) {
	long := strings.Repeat("word ", 80)
	f := &fakeGemini{texts: []string{"Sure!\n```json\n[{\"c\":\"C4\",\"why\":\"CTO hiring\\nmobile engineers.\"},{\"c\":\"c4\",\"why\":\"dup\"},{\"c\":\"c2\",\"why\":\"" + long + "\"},{\"c\":\"c1\",\"why\":\"  \"}]\n```"}}
	g := newGemini(t, f)
	r, err := g.Search(context.Background(), "hiring", people, 8)
	if err != nil || r.Model != "gemma-test" {
		t.Fatal(r, err)
	}
	if got := keys(r); len(got) != 2 || got[0] != "k-vuk" || got[1] != "k-stefan" {
		t.Fatalf("got %v", got)
	}
	if r.Picks[0].Why != "CTO hiring mobile engineers." {
		t.Fatalf("why %q", r.Picks[0].Why)
	}
	if utf8.RuneCountInString(r.Picks[1].Why) > MaxWhy {
		t.Fatal("why not cut")
	}
	if !strings.Contains(f.prompts[0], `"hiring"`) {
		t.Fatal("prompt misses search")
	}
}

func TestGeminiUnknownIndexFallsBack(t *testing.T) {
	f := &fakeGemini{texts: []string{`[{"c":"c99","why":"x"},{"c":"bob","why":"y"}]`}}
	r, err := newGemini(t, f).Recommend(context.Background(), ana, people, 8)
	if err != nil || r.Model != OfflineModel || len(r.Picks) != len(people) {
		t.Fatal(r, err)
	}
	// Mixed: unknown entries are dropped, known ones kept.
	f = &fakeGemini{texts: []string{`[{"c":"c99","why":"x"},{"c":"c2","why":"Go engineers wanted."}]`}}
	r, _ = newGemini(t, f).Recommend(context.Background(), ana, people, 8)
	if r.Model != "gemma-test" || len(r.Picks) != 1 || r.Picks[0].Key != "k-stefan" {
		t.Fatal(r)
	}
}

func TestGeminiGarbageFallsBack(t *testing.T) {
	for _, text := range []string{"I cannot help with that.", "[not json", `{"c":"c1"}`} {
		f := &fakeGemini{texts: []string{text}}
		r, err := newGemini(t, f).Search(context.Background(), "hiring mobile engineers", people, 8)
		if err != nil || r.Model != OfflineModel || len(r.Picks) == 0 || r.Picks[0].Key != "k-vuk" {
			t.Fatalf("%q: %v %v", text, r, err)
		}
	}
	// An empty array is a valid search answer, but not a valid recommendation.
	f := &fakeGemini{texts: []string{"[]"}}
	r, _ := newGemini(t, f).Search(context.Background(), "astronauts", people, 8)
	if r.Model != "gemma-test" || len(r.Picks) != 0 {
		t.Fatal(r)
	}
	r, _ = newGemini(t, f).Recommend(context.Background(), ana, people, 8)
	if r.Model != OfflineModel || len(r.Picks) == 0 {
		t.Fatal(r)
	}
}

func TestGeminiRetries5xxThenFallsBackOn4xx(t *testing.T) {
	f := &fakeGemini{status: []int{503, 200}, texts: []string{"", `[{"c":"c1","why":"Speech research."}]`}}
	r, _ := newGemini(t, f).Recommend(context.Background(), ana, people, 8)
	if r.Model != "gemma-test" || f.calls.Load() != 2 {
		t.Fatal(r, f.calls.Load())
	}
	f = &fakeGemini{status: []int{429}, texts: []string{""}}
	r, _ = newGemini(t, f).Recommend(context.Background(), ana, people, 8)
	if r.Model != OfflineModel || f.calls.Load() != 1 {
		t.Fatal(r, f.calls.Load())
	}
}

func TestGeminiCapsCandidates(t *testing.T) {
	var many []Candidate
	for i := range 55 {
		many = append(many, Candidate{Key: fmt.Sprintf("k%d", i), Name: fmt.Sprintf("P%02d", i), Profile: Profile{Headline: "dev", Interests: []string{"Mobile"}}})
	}
	f := &fakeGemini{texts: []string{`[{"c":"c40","why":"ok"},{"c":"c41","why":"out of range"}]`}}
	r, _ := newGemini(t, f).Recommend(context.Background(), ana, many, 8)
	if r.Model != "gemma-test" || len(r.Picks) != 1 {
		t.Fatal(r)
	}
	if strings.Contains(f.prompts[0], "c41:") || !strings.Contains(f.prompts[0], "c40:") {
		t.Fatal("not capped at 40")
	}
}

func TestCleanWhy(t *testing.T) {
	if got := CleanWhy("  **Bold**\tand\n`code` "); got != "Bold and code" {
		t.Fatalf("%q", got)
	}
}
