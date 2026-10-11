package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/auth"
	"github.com/Ilij4n/eho/backend/events/internal/extract"
	"github.com/Ilij4n/eho/backend/events/internal/store"
)

// fakeVerifier accepts "user:<uid>" (organizer) and "anon:<uid>".
type fakeVerifier struct{}

func (fakeVerifier) Verify(_ context.Context, tok string) (auth.Principal, error) {
	switch {
	case strings.HasPrefix(tok, "user:"):
		return auth.Principal{UID: tok[5:]}, nil
	case strings.HasPrefix(tok, "anon:"):
		return auth.Principal{UID: tok[5:], Anonymous: true}, nil
	}
	return auth.Principal{}, auth.ErrInvalidToken
}

var day = time.Date(2026, 10, 11, 8, 0, 0, 0, time.UTC)

type api struct {
	t     *testing.T
	h     http.Handler
	store *store.MemStore
}

func newAPI(t *testing.T, ex *extract.Extractor) *api { return newAPIBurst(t, ex, 100) }

func newAPIBurst(t *testing.T, ex *extract.Extractor, burst int) *api {
	ms := store.NewMemStore()
	if ex == nil {
		ex = &extract.Extractor{Now: func() time.Time { return day }}
	}
	return &api{t: t, store: ms, h: NewHandler(Options{
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Store: ms, Verifier: fakeVerifier{},
		Extractor: ex, Now: func() time.Time { return day }, DraftBurst: burst,
	})}
}

type resp struct {
	Code int
	Body map[string]any
	Raw  string
}

func (a *api) do(method, path, token string, body any, contentType string) resp {
	a.t.Helper()
	var r io.Reader
	switch b := body.(type) {
	case nil:
	case []byte:
		r = bytes.NewReader(b)
	case string:
		r = strings.NewReader(b)
	default:
		buf, _ := json.Marshal(b)
		r = bytes.NewReader(buf)
	}
	req := httptest.NewRequest(method, path, r)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, req)
	out := resp{Code: rec.Code, Raw: rec.Body.String()}
	_ = json.Unmarshal(rec.Body.Bytes(), &out.Body)
	return out
}

func (a *api) must(want int, r resp) resp {
	a.t.Helper()
	if r.Code != want {
		a.t.Fatalf("status = %d, want %d; body = %s", r.Code, want, r.Raw)
	}
	return r
}

// upload builds a multipart body with the given name → content files.
func upload(files ...[2]string) ([]byte, string) {
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	for _, f := range files {
		w, _ := mw.CreateFormFile("files", f[0])
		_, _ = w.Write([]byte(f[1]))
	}
	_ = mw.Close()
	return buf.Bytes(), mw.FormDataContentType()
}

const org = "user:org1"

const agendaCSV = `Title,Stage,Day,Time,Speaker
Registration & coffee,Glavna sala,11.10.2026.,09:00-09:45,
On-device AI: when the model lives in your pocket,Glavna sala,11.10.2026.,10:00–10:45,"Mara Ilić (ML Engineer, Lumen Labs)"
Scaling event-driven backends on a startup budget,Sala A,11.10.2026.,11:00-11:40,Luka Marković
Designing for crowded rooms,,11.10.2026.,11:00-12:30,Jana Kostić
From prototype to paying customers with LLMs,Glavna sala,11.10.2026.,14:30-15:15,Sara Đorđević & Petar Vuković
`

func errCode(r resp) string { s, _ := r.Body["code"].(string); return s }

func TestOrganizerFlowCSV(t *testing.T) {
	a := newAPI(t, nil)
	a.store.PutEvent(store.Event{ID: "devfest", Name: "Old", StartDate: "2026-10-11", EndDate: "2026-10-12",
		OwnerUID: "org1", PublishedVersion: 1}, "Glavna sala", "Sala A", "Sala B")

	body, ct := upload([2]string{"agenda.csv", agendaCSV})
	a.must(403, a.do("POST", "/v1/organizer/drafts", "anon:x", body, ct))
	r := a.must(201, a.do("POST", "/v1/organizer/drafts", org, body, ct))
	if r.Body["model"] != "offline" {
		t.Fatalf("model = %v", r.Body["model"])
	}
	sessions := r.Body["sessions"].([]any)
	if len(sessions) != 5 {
		t.Fatalf("sessions = %d: %s", len(sessions), r.Raw)
	}
	keynote := sessions[1].(map[string]any)
	if keynote["start"] != "10:00" || keynote["end"] != "10:45" || keynote["day"] != "2026-10-11" {
		t.Fatalf("keynote %v", keynote)
	}
	sp := keynote["speakers"].([]any)[0].(map[string]any)
	if sp["name"] != "Mara Ilić" || sp["title"] != "ML Engineer, Lumen Labs" {
		t.Fatalf("speaker %v", sp)
	}
	if !sessions[0].(map[string]any)["isBreak"].(bool) {
		t.Fatal("registration should be a break")
	}
	if n := len(sessions[4].(map[string]any)["speakers"].([]any)); n != 2 {
		t.Fatalf("panel speakers = %d", n)
	}
	// Missing stage and missing event name are flagged.
	raw := r.Raw
	if !strings.Contains(raw, "No stage found") || !strings.Contains(raw, "No event name found") {
		t.Fatalf("issues: %s", raw)
	}
	id := r.Body["id"].(string)

	// Publishing needs a name.
	a.must(422, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, map[string]any{"eventId": "devfest"}, ""))

	// The organizer fixes the draft in the review.
	var d map[string]any
	_ = json.Unmarshal([]byte(r.Raw), &d)
	for _, k := range []string{"id", "issues", "model", "sourceFiles", "createdAt", "updatedAt"} {
		delete(d, k)
	}
	d["name"], d["address"] = "DevFest Belgrade 2026", "Sava Centar, Belgrade"
	for _, s := range d["sessions"].([]any) {
		if s := s.(map[string]any); s["title"] == "Designing for crowded rooms" {
			s["stage"] = "Sala B"
		}
	}
	d["stages"] = append(d["stages"].([]any), "Sala B", "Terasa")
	a.must(400, a.do("PUT", "/v1/organizer/drafts/"+id, org, `{"name":"x","bogus":1}`, ""))
	a.must(403, a.do("PUT", "/v1/organizer/drafts/"+id, "user:other", d, ""))
	r = a.must(200, a.do("PUT", "/v1/organizer/drafts/"+id, org, d, ""))
	if strings.Contains(r.Raw, "No stage found") {
		t.Fatalf("issue should be gone: %s", r.Raw)
	}

	// Into someone else's event: forbidden. Into devfest: ok.
	a.store.PutEvent(store.Event{ID: "theirs", OwnerUID: "other", Name: "T", StartDate: "2026-10-11", EndDate: "2026-10-11"})
	a.must(403, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, map[string]any{"eventId": "theirs"}, ""))
	r = a.must(200, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, map[string]any{"eventId": "devfest"}, ""))
	if r.Body["joinPath"] != "/e/devfest" || r.Body["sessions"].(float64) != 5 {
		t.Fatalf("publish %s", r.Raw)
	}
	if w := r.Body["warnings"].([]any); len(w) != 0 {
		t.Fatalf("no warnings expected (Terasa is unused): %s", r.Raw)
	}

	// Attendees see the agenda and the renamed event.
	ag := a.must(200, a.do("GET", "/v1/events/devfest/agenda", "anon:att", nil, ""))
	first := ag.Body["sessions"].([]any)[0].(map[string]any)
	if first["title"] != "Registration & coffee" || !strings.HasPrefix(first["id"].(string), "s-") {
		t.Fatalf("agenda %s", ag.Raw)
	}
	pe := a.must(200, a.do("GET", "/v1/events/devfest/public", "anon:att", nil, ""))
	if pe.Body["name"] != "DevFest Belgrade 2026" || pe.Body["hasMap"] != true || pe.Body["hasAgenda"] != true {
		t.Fatalf("public %s", pe.Raw)
	}

	// A re-publish keeps session IDs by title.
	keynoteID := ag.Body["sessions"].([]any)[1].(map[string]any)["id"]
	a.must(200, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, map[string]any{"eventId": "devfest"}, ""))
	ag2 := a.must(200, a.do("GET", "/v1/events/devfest/agenda", "anon:att", nil, ""))
	if ag2.Body["sessions"].([]any)[1].(map[string]any)["id"] != keynoteID {
		t.Fatal("session ID changed on re-publish")
	}

	// A new event without eventId.
	r = a.must(200, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, nil, ""))
	newID := r.Body["eventId"].(string)
	if newID == "devfest" || r.Body["joinPath"] != "/e/"+newID {
		t.Fatalf("new event %s", r.Raw)
	}
	pe = a.must(200, a.do("GET", "/v1/events/"+newID+"/public", "anon:att", nil, ""))
	if pe.Body["hasMap"] != false || pe.Body["hasAgenda"] != true {
		t.Fatalf("new public %s", pe.Raw)
	}
}

func TestStageWarnings(t *testing.T) {
	a := newAPI(t, nil)
	a.store.PutEvent(store.Event{ID: "devfest", Name: "D", StartDate: "2026-10-11", EndDate: "2026-10-11",
		OwnerUID: "org1", PublishedVersion: 1}, "Glavna sala")
	body, ct := upload([2]string{"a.csv", "title,room,start,end\nKeynote,Main hall,10:00,10:45\n"})
	r := a.must(201, a.do("POST", "/v1/organizer/drafts", org, body, ct))
	id := r.Body["id"].(string)
	var d map[string]any
	_ = json.Unmarshal([]byte(r.Raw), &d)
	for _, k := range []string{"id", "issues", "model", "sourceFiles", "createdAt", "updatedAt"} {
		delete(d, k)
	}
	d["name"], d["startDate"], d["endDate"] = "D", "2026-10-11", "2026-10-11"
	a.must(200, a.do("PUT", "/v1/organizer/drafts/"+id, org, d, ""))
	r = a.must(200, a.do("POST", "/v1/organizer/drafts/"+id+"/publish", org, map[string]any{"eventId": "devfest"}, ""))
	if !strings.Contains(r.Raw, `\"Main hall\" is not a room`) {
		t.Fatalf("warnings %s", r.Raw)
	}
}

func TestJoinAndMyEvents(t *testing.T) {
	a := newAPI(t, nil)
	a.store.PutEvent(store.Event{ID: "devfest", Name: "DevFest", StartDate: "2026-10-11", EndDate: "2026-10-12", PublishedVersion: 1})
	a.store.PutEvent(store.Event{ID: "past", Name: "Past", StartDate: "2026-09-18", EndDate: "2026-09-18", PublishedVersion: 1})
	a.store.PutEvent(store.Event{ID: "hidden", Name: "Hidden", StartDate: "2026-10-11", EndDate: "2026-10-11"})

	a.must(401, a.do("GET", "/v1/me/events", "", nil, ""))
	a.must(404, a.do("GET", "/v1/events/hidden/public", "anon:u", nil, ""))
	a.must(404, a.do("POST", "/v1/events/hidden/join", "anon:u", nil, ""))
	a.must(404, a.do("POST", "/v1/events/nope/join", "anon:u", nil, ""))
	a.must(204, a.do("POST", "/v1/events/past/join", "anon:u", nil, ""))
	a.must(204, a.do("POST", "/v1/events/devfest/join", "anon:u", nil, ""))
	a.must(204, a.do("POST", "/v1/events/devfest/join", "anon:u", nil, "")) // idempotent

	r := a.must(200, a.do("GET", "/v1/me/events", "anon:u", nil, ""))
	evs := r.Body["events"].([]any)
	if len(evs) != 2 {
		t.Fatalf("events %s", r.Raw)
	}
	byID := map[string]map[string]any{}
	for _, e := range evs {
		byID[e.(map[string]any)["id"].(string)] = e.(map[string]any)
	}
	if byID["past"]["isPast"] != true || byID["devfest"]["isPast"] != false {
		t.Fatalf("isPast %s", r.Raw)
	}
	if r := a.must(200, a.do("GET", "/v1/me/events", "anon:other", nil, "")); len(r.Body["events"].([]any)) != 0 {
		t.Fatal("other user sees memberships")
	}
	a.must(204, a.do("DELETE", "/v1/events/past/join", "anon:u", nil, ""))
	if r := a.must(200, a.do("GET", "/v1/me/events", "anon:u", nil, "")); len(r.Body["events"].([]any)) != 1 {
		t.Fatal("leave didn't remove")
	}
	a.must(404, a.do("GET", "/v1/events/devfest/agenda", "anon:u", nil, ""))
}

func TestUploadErrors(t *testing.T) {
	a := newAPI(t, nil)
	a.must(400, a.do("POST", "/v1/organizer/drafts", org, `{}`, "application/json"))
	body, ct := upload()
	if r := a.must(400, a.do("POST", "/v1/organizer/drafts", org, body, ct)); errCode(r) != "no_files" {
		t.Fatal(r.Raw)
	}
	body, ct = upload([2]string{"evil.exe", "MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff"})
	if r := a.must(415, a.do("POST", "/v1/organizer/drafts", org, body, ct)); errCode(r) != "unsupported_file" {
		t.Fatal(r.Raw)
	}
	// A PDF needs the model; there is none here.
	body, ct = upload([2]string{"agenda.pdf", "%PDF-1.4\n1 0 obj\n"})
	if r := a.must(503, a.do("POST", "/v1/organizer/drafts", org, body, ct)); errCode(r) != "ai_unavailable" {
		t.Fatal(r.Raw)
	}
	// A CSV without a usable header.
	body, ct = upload([2]string{"notes.csv", "hello,world\n1,2\n"})
	if r := a.must(422, a.do("POST", "/v1/organizer/drafts", org, body, ct)); errCode(r) != "nothing_extracted" {
		t.Fatal(r.Raw)
	}
	var files [][2]string
	for range 11 {
		files = append(files, [2]string{"a.csv", agendaCSV})
	}
	body, ct = upload(files...)
	a.must(413, a.do("POST", "/v1/organizer/drafts", org, body, ct))
}

func TestRateLimit(t *testing.T) {
	a := newAPIBurst(t, nil, 5)
	body, ct := upload([2]string{"a.csv", agendaCSV})
	for range 5 {
		a.must(201, a.do("POST", "/v1/organizer/drafts", org, body, ct))
	}
	a.must(429, a.do("POST", "/v1/organizer/drafts", org, body, ct))
}

// The model path: a fake Gemini answers with JSON; the PDF goes as inline data.
func TestGeminiExtraction(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewDecoder(r.Body).Decode(&got)
		answer := `{"name":"DevFest Belgrade 2026","startDate":"2026-10-11","endDate":"2026-10-12","address":"Sava Centar, Belgrade",
"stages":["Glavna sala","Sala A"],"speakers":[{"name":"Mara Ilić","title":"ML Engineer, Lumen Labs"}],
"sessions":[{"title":"On-device AI","stage":"Glavna sala","day":"2026-10-11","start":"10:00","end":"10:45","track":"AI","description":"","isBreak":false,"speakers":["Mara Ilić"]},
{"title":"","stage":"x","day":"","start":"","end":"","isBreak":false,"speakers":[]},
{"title":"Lunch","stage":"Glavna sala","day":"2026-10-11","start":"12.30","end":"13:30","isBreak":true,"speakers":["Nobody"]}]}`
		_ = json.NewEncoder(w).Encode(map[string]any{"candidates": []any{map[string]any{
			"content": map[string]any{"parts": []any{map[string]any{"text": answer}}}}}})
	}))
	t.Cleanup(srv.Close)
	ex := &extract.Extractor{Model: &extract.Gemini{APIKey: "k", ModelName: "gemini-test", BaseURL: srv.URL}, Now: func() time.Time { return day }}
	a := newAPI(t, ex)
	pdf := "%PDF-1.4\nfake agenda\n"
	body, ct := upload([2]string{"agenda.pdf", pdf})
	r := a.must(201, a.do("POST", "/v1/organizer/drafts", org, body, ct))
	if r.Body["model"] != "gemini-test" {
		t.Fatalf("model %v", r.Body["model"])
	}
	s := r.Body["sessions"].([]any)
	if len(s) != 2 {
		t.Fatalf("untitled session should be dropped: %s", r.Raw)
	}
	lunch := s[1].(map[string]any)
	if lunch["start"] != "12:30" || len(lunch["speakers"].([]any)) != 0 {
		t.Fatalf("lunch %v", lunch)
	}
	if !strings.Contains(r.Raw, `"type":"pdf"`) {
		t.Fatalf("source files %s", r.Raw)
	}
	parts := got["contents"].([]any)[0].(map[string]any)["parts"].([]any)
	inline := parts[2].(map[string]any)["inlineData"].(map[string]any)
	if inline["mimeType"] != "application/pdf" || inline["data"] != base64.StdEncoding.EncodeToString([]byte(pdf)) {
		t.Fatalf("inline %v", inline)
	}
	if gc := got["generationConfig"].(map[string]any); gc["responseMimeType"] != "application/json" {
		t.Fatalf("generationConfig %v", gc)
	}
}
