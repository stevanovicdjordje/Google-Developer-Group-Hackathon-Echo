package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/Ilij4n/eho/backend/echo/internal/assist"
	"github.com/Ilij4n/eho/backend/echo/internal/auth"
	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

type fakeVerifier struct{}

func (fakeVerifier) Verify(_ context.Context, tok string) (auth.Principal, error) {
	uid, ok := strings.CutPrefix(tok, "uid:")
	if !ok {
		return auth.Principal{}, auth.ErrInvalidToken
	}
	return auth.Principal{UID: uid, Anonymous: true}, nil
}

type countingAI struct {
	assist.Offline
	calls atomic.Int32
	fail  bool
}

func (c *countingAI) Model() string { return "fake-gemma" }

func (c *countingAI) Ask(ctx context.Context, lines []store.Line, q, lang string) (string, error) {
	c.calls.Add(1)
	if c.fail {
		return "", assist.ErrModel
	}
	return c.Offline.Ask(ctx, lines, q, lang)
}

func (c *countingAI) Summary(ctx context.Context, lines []store.Line, lang string) (string, error) {
	c.calls.Add(1)
	return c.Offline.Summary(ctx, lines, lang)
}

func (c *countingAI) Translate(ctx context.Context, texts []string, lang string) ([]string, error) {
	c.calls.Add(1)
	return c.Offline.Translate(ctx, texts, lang)
}

type fixture struct {
	t  *testing.T
	h  http.Handler
	st *store.MemStore
	ai *countingAI
}

const sessPath = "/v1/events/ev1/sessions/s1"

func newFixture(t *testing.T, lines ...string) *fixture {
	t.Helper()
	st := store.NewMemStore()
	st.PutEvent("ev1", store.Event{OwnerUID: "org", PublishedVersion: 1})
	st.PutEvent("draft", store.Event{OwnerUID: "org"})
	ctx := context.Background()
	if err := st.ResetTranscript(ctx, "ev1", "s1", "en"); err != nil {
		t.Fatal(err)
	}
	for i, l := range lines {
		if err := st.AppendLine(ctx, "ev1", "s1", store.Line{Index: i, AtSeconds: i * 5, Text: l}, false); err != nil {
			t.Fatal(err)
		}
	}
	ai := &countingAI{}
	h := NewHandler(Options{
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Store: st, Verifier: fakeVerifier{}, Assistant: ai,
		AILimit: 5, QuestionLimit: 2,
	})
	return &fixture{t: t, h: h, st: st, ai: ai}
}

func (f *fixture) do(method, path, uid, body string) (int, map[string]any) {
	f.t.Helper()
	var rd io.Reader
	if body != "" {
		rd = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, rd)
	if uid != "" {
		req.Header.Set("Authorization", "Bearer uid:"+uid)
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	var out map[string]any
	if rec.Body.Len() > 0 {
		if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
			f.t.Fatalf("%s %s: body is not JSON: %s", method, path, rec.Body.String())
		}
	}
	return rec.Code, out
}

var keynote = []string{
	"Today I want to talk about models on your phone.",
	"We measured a twelve percent battery hit for continuous transcription.",
	"The fix was batching: process audio in chunks, not every frame.",
}

func TestHealthzReportsModel(t *testing.T) {
	f := newFixture(t)
	code, body := f.do("GET", "/healthz", "", "")
	if code != 200 || body["model"] != "fake-gemma" {
		t.Fatalf("got %d %v", code, body)
	}
}

func TestAuthAndVisibility(t *testing.T) {
	f := newFixture(t, keynote...)
	cases := []struct {
		name, path, uid string
		code            int
		errCode         string
	}{
		{"no token", sessPath + "/summary", "", 401, "unauthenticated"},
		{"unknown event", "/v1/events/nope/sessions/s1/summary", "a1", 404, "not_found"},
		{"unpublished event, attendee", "/v1/events/draft/sessions/s1/summary", "a1", 404, "not_found"},
		{"unpublished event, owner, no transcript", "/v1/events/draft/sessions/s1/summary", "org", 404, "no_transcript"},
		{"no transcript", "/v1/events/ev1/sessions/s9/summary", "a1", 404, "no_transcript"},
		{"bad session id", "/v1/events/ev1/sessions/a.b/summary", "a1", 404, "not_found"},
		{"ok", sessPath + "/summary", "a1", 200, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			code, body := f.do("GET", c.path, c.uid, "")
			if code != c.code || (c.errCode != "" && body["code"] != c.errCode) {
				t.Fatalf("got %d %v, want %d %s", code, body, c.code, c.errCode)
			}
		})
	}
}

func TestAskGroundedAndCached(t *testing.T) {
	f := newFixture(t, keynote...)
	code, body := f.do("POST", sessPath+"/ask", "a1", `{"question":"How much battery did transcription cost?"}`)
	if code != 200 {
		t.Fatalf("got %d %v", code, body)
	}
	if !strings.Contains(body["text"].(string), "twelve percent") || body["basedOnLines"] != float64(3) || body["model"] != "fake-gemma" {
		t.Fatalf("unexpected answer %v", body)
	}
	f.do("POST", sessPath+"/ask", "a2", `{"question":"how much  BATTERY did transcription cost?"}`)
	if n := f.ai.calls.Load(); n != 1 {
		t.Fatalf("model called %d times, want 1 (cached)", n)
	}

	_ = f.st.AppendLine(context.Background(), "ev1", "s1", store.Line{Index: 3, AtSeconds: 20, Text: "More."}, false)
	f.do("POST", sessPath+"/ask", "a1", `{"question":"How much battery did transcription cost?"}`)
	if n := f.ai.calls.Load(); n != 2 {
		t.Fatalf("model called %d times, want 2 (new line invalidates)", n)
	}
}

func TestAskValidation(t *testing.T) {
	f := newFixture(t, keynote...)
	for _, body := range []string{`{"question":"   "}`, `{"question":"` + strings.Repeat("x", 501) + `"}`, `{"question":"hi","language":"xx"}`} {
		if code, out := f.do("POST", sessPath+"/ask", "a1", body); code != 422 || out["code"] != "validation_failed" {
			t.Fatalf("%.40s: got %d %v", body, code, out)
		}
	}
	if code, out := f.do("POST", sessPath+"/ask", "a1", `{"question":"hi","extra":1}`); code != 400 || out["code"] != "invalid_json" {
		t.Fatalf("unknown field: got %d %v", code, out)
	}
}

func TestAskBeforeTalkStarts(t *testing.T) {
	f := newFixture(t)
	code, body := f.do("POST", sessPath+"/ask", "a1", `{"question":"anything"}`)
	if code != 200 || body["basedOnLines"] != float64(0) || f.ai.calls.Load() != 0 {
		t.Fatalf("got %d %v, calls %d", code, body, f.ai.calls.Load())
	}
}

func TestModelFailureIs502(t *testing.T) {
	f := newFixture(t, keynote...)
	f.ai.fail = true
	code, body := f.do("POST", sessPath+"/ask", "a1", `{"question":"battery?"}`)
	if code != 502 || body["code"] != "ai_unavailable" {
		t.Fatalf("got %d %v", code, body)
	}
}

func TestAIRateLimitCountsOnlyCacheMisses(t *testing.T) {
	f := newFixture(t, keynote...)
	for range 10 {
		if code, _ := f.do("GET", sessPath+"/summary", "a1", ""); code != 200 {
			t.Fatalf("cached summary should not be limited, got %d", code)
		}
	}
	var last int
	for i := range 6 {
		last, _ = f.do("POST", sessPath+"/ask", "a1", `{"question":"question number `+string(rune('a'+i))+`"}`)
	}
	if last != 429 {
		t.Fatalf("sixth distinct miss after the summary: got %d, want 429", last)
	}
}

func TestTranslateIncremental(t *testing.T) {
	f := newFixture(t, keynote...)
	code, body := f.do("POST", sessPath+"/translate", "a1", `{"language":"sr","fromIndex":1}`)
	if code != 200 || body["nextIndex"] != float64(3) {
		t.Fatalf("got %d %v", code, body)
	}
	lines := body["lines"].([]any)
	if len(lines) != 2 || lines[0].(map[string]any)["index"] != float64(1) ||
		!strings.HasPrefix(lines[0].(map[string]any)["text"].(string), "[sr] We measured") {
		t.Fatalf("unexpected lines %v", lines)
	}
	f.do("POST", sessPath+"/translate", "a2", `{"language":"sr"}`)
	if n := f.ai.calls.Load(); n != 2 {
		t.Fatalf("model called %d times, want 2 (lines 1-2, then only line 0)", n)
	}
	code, body = f.do("POST", sessPath+"/translate", "a2", `{"language":"sr","fromIndex":99}`)
	if code != 200 || body["nextIndex"] != float64(3) || len(body["lines"].([]any)) != 0 {
		t.Fatalf("past the end: got %d %v", code, body)
	}
	if code, _ := f.do("POST", sessPath+"/translate", "a2", `{}`); code != 422 {
		t.Fatalf("missing language: got %d", code)
	}
}

func TestQuestionsFlow(t *testing.T) {
	f := newFixture(t, keynote...)
	code, q1 := f.do("POST", sessPath+"/questions", "a1", `{"text":"Which quantization did you use?"}`)
	if code != 201 || q1["votes"] != float64(1) || q1["mine"] != true || q1["voted"] != true {
		t.Fatalf("submit: %d %v", code, q1)
	}
	_, q2 := f.do("POST", sessPath+"/questions", "a2", `{"text":"Does it run on iOS?"}`)
	id2 := q2["id"].(string)

	for _, uid := range []string{"a1", "a3", "a3"} {
		if code, _ := f.do("PUT", sessPath+"/questions/"+id2+"/vote", uid, ""); code != 200 {
			t.Fatalf("vote: %d", code)
		}
	}
	_, list := f.do("GET", sessPath+"/questions", "a1", "")
	qs := list["questions"].([]any)
	top := qs[0].(map[string]any)
	if top["id"] != id2 || top["votes"] != float64(3) || top["mine"] != false || top["voted"] != true {
		t.Fatalf("top question %v", top)
	}
	if _, ok := top["authorUid"]; ok {
		t.Fatal("author leaked")
	}

	_, after := f.do("DELETE", sessPath+"/questions/"+id2+"/vote", "a3", "")
	if after["votes"] != float64(2) || after["voted"] != false {
		t.Fatalf("unvote %v", after)
	}
	if code, _ := f.do("PUT", sessPath+"/questions/nope/vote", "a1", ""); code != 404 {
		t.Fatalf("unknown question: %d", code)
	}
	if code, _ := f.do("POST", sessPath+"/questions", "a1", `{"text":"no"}`); code != 422 {
		t.Fatalf("short question: %d", code)
	}
	if code, _ := f.do("POST", sessPath+"/questions", "a1", `{"text":"second one in a minute"}`); code != 201 {
		t.Fatalf("second question: %d", code)
	}
	if code, _ := f.do("POST", sessPath+"/questions", "a1", `{"text":"third one in a minute"}`); code != 429 {
		t.Fatalf("question limit: %d", code)
	}
}

func TestCORSPreflight(t *testing.T) {
	h := NewHandler(Options{
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Store: store.NewMemStore(), Verifier: fakeVerifier{},
		Assistant: assist.Offline{}, AllowedOrigins: []string{"http://localhost:*"},
	})
	req := httptest.NewRequest("OPTIONS", sessPath+"/ask", nil)
	req.Header.Set("Origin", "http://localhost:5000")
	req.Header.Set("Access-Control-Request-Method", "POST")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 204 || rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5000" {
		t.Fatalf("got %d %v", rec.Code, rec.Header())
	}
}
