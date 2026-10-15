package rulestest

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

// Runs against the emulators only: `make dev` (or `firebase emulators:start`), then
// `make rules-test`. The current rule files are loaded into the running emulators
// first, so the tests always check what is in the repo.
//
// Storage rules read Firestore (firestore.get), and the Storage emulator asks the
// Firestore emulator of its own project, so everything uses the dev project.
const project = "demo-eho"

var (
	firestoreHost string // e.g. http://127.0.0.1:8081
	storageHost   string // e.g. http://127.0.0.1:9199
	bucket        = project + ".appspot.com"
)

func setup(t *testing.T) {
	t.Helper()
	fs, st := os.Getenv("FIRESTORE_EMULATOR_HOST"), os.Getenv("STORAGE_EMULATOR_HOST")
	if fs == "" || st == "" {
		t.Skip("FIRESTORE_EMULATOR_HOST / STORAGE_EMULATOR_HOST not set")
	}
	firestoreHost = "http://" + strings.TrimPrefix(fs, "http://")
	storageHost = "http://" + strings.TrimPrefix(st, "http://")

	load := func(method, u, name, file string) {
		src, err := os.ReadFile("../../firebase/" + file)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := json.Marshal(map[string]any{"rules": map[string]any{"files": []any{map[string]string{"name": name, "content": string(src)}}}})
		code, out := do(t, method, u, "", "application/json", body)
		if code != http.StatusOK {
			t.Fatalf("loading %s: %d %s", file, code, out)
		}
	}
	load(http.MethodPut, firestoreHost+"/emulator/v1/projects/"+project+":securityRules", "firestore.rules", "firestore.rules")
	load(http.MethodPut, storageHost+"/internal/setRules", "storage.rules", "storage.rules")
}

// token returns an unsigned Firebase ID token for uid; the emulators accept these.
// An empty uid means a signed-out request (no token).
func token(uid string) string {
	if uid == "" {
		return ""
	}
	enc := func(v any) string {
		b, _ := json.Marshal(v)
		return base64.RawURLEncoding.EncodeToString(b)
	}
	now := time.Now().Unix()
	claims := map[string]any{
		"iss": "https://securetoken.google.com/" + project, "aud": project,
		"sub": uid, "user_id": uid, "iat": now, "exp": now + 3600, "auth_time": now,
		"firebase": map[string]any{"sign_in_provider": "anonymous", "identities": map[string]any{}},
	}
	return enc(map[string]string{"alg": "none", "typ": "JWT"}) + "." + enc(claims) + "."
}

func do(t *testing.T, method, u, bearer, contentType string, body []byte) (int, string) {
	t.Helper()
	req, err := http.NewRequest(method, u, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	out, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(out)
}

func newID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func docURL(path string) string {
	return firestoreHost + "/v1/projects/" + project + "/databases/(default)/documents/" + path
}

// adminPut writes a document bypassing the rules (like the Go backend's Admin SDK).
func adminPut(t *testing.T, path string, fields map[string]any) {
	t.Helper()
	body, _ := json.Marshal(map[string]any{"fields": fields})
	if code, out := do(t, http.MethodPatch, docURL(path), "owner", "application/json", body); code != http.StatusOK {
		t.Fatalf("admin write %s: %d %s", path, code, out)
	}
}

func adminDelete(t *testing.T, path string) {
	do(t, http.MethodDelete, docURL(path), "owner", "", nil)
}

func str(s string) map[string]any { return map[string]any{"stringValue": s} }
func num(n int) map[string]any    { return map[string]any{"integerValue": fmt.Sprint(n)} }

const (
	ownerUID    = "rules-owner"
	attendeeUID = "rules-attendee"
)

// newEvent creates an event owned by ownerUID with a published map, draft, and stats doc.
func newEvent(t *testing.T, publishedVersion int) string {
	t.Helper()
	id := "rules-" + newID()
	docs := map[string]map[string]any{
		"events/" + id:                              {"ownerUid": str(ownerUID), "name": str("Rules test"), "publishedVersion": num(publishedVersion)},
		"events/" + id + "/published/map":           {"version": num(publishedVersion)},
		"events/" + id + "/published/map/floors/f1": {"name": str("P")},
		"events/" + id + "/draft/map/floors/f1":     {"name": str("P")},
		"events/" + id + "/stats/2026-10-11":        {"searches": num(3)},
		// Echo (feature:echo) replays transcripts under published/ and relies on these rules.
		"events/" + id + "/published/echo/sessions/s1/lines/00000": {"text": str("Dobro veče")},
	}
	for p, f := range docs {
		adminPut(t, p, f)
	}
	t.Cleanup(func() {
		for p := range docs {
			adminDelete(t, p)
		}
	})
	return id
}

func TestFirestoreRules(t *testing.T) {
	setup(t)
	pub := newEvent(t, 1)
	draft := newEvent(t, 0)

	reads := []struct {
		name, path, uid string
		allowed         bool
	}{
		{"signed out: published event", "events/" + pub, "", false},
		{"signed out: published map", "events/" + pub + "/published/map", "", false},
		{"attendee: published event", "events/" + pub, attendeeUID, true},
		{"attendee: published map", "events/" + pub + "/published/map", attendeeUID, true},
		{"attendee: published floor", "events/" + pub + "/published/map/floors/f1", attendeeUID, true},
		{"attendee: draft of published event", "events/" + pub + "/draft/map/floors/f1", attendeeUID, false},
		{"attendee: stats", "events/" + pub + "/stats/2026-10-11", attendeeUID, false},
		{"attendee: unpublished event", "events/" + draft, attendeeUID, false},
		{"attendee: unpublished map", "events/" + draft + "/published/map", attendeeUID, false},
		{"attendee: Echo transcript line", "events/" + pub + "/published/echo/sessions/s1/lines/00000", attendeeUID, true},
		{"attendee: Echo line of unpublished event", "events/" + draft + "/published/echo/sessions/s1/lines/00000", attendeeUID, false},
		{"signed out: Echo transcript line", "events/" + pub + "/published/echo/sessions/s1/lines/00000", "", false},
		{"owner: unpublished event", "events/" + draft, ownerUID, true},
		{"owner: draft", "events/" + draft + "/draft/map/floors/f1", ownerUID, true},
		{"owner: stats", "events/" + pub + "/stats/2026-10-11", ownerUID, true},
		{"attendee: unknown collection", "users/" + attendeeUID, attendeeUID, false},
	}
	for _, c := range reads {
		code, out := do(t, http.MethodGet, docURL(c.path), token(c.uid), "", nil)
		if got := code == http.StatusOK; got != c.allowed {
			t.Errorf("read %s: status %d, want allowed=%v (%s)", c.name, code, c.allowed, strings.TrimSpace(out))
		}
	}

	// Listing a collection the user may not read in full is denied as a whole.
	if code, _ := do(t, http.MethodGet, docURL("events"), token(attendeeUID), "", nil); code == http.StatusOK {
		t.Errorf("attendee listed all events")
	}

	// Clients never write, not even the owner. Every write goes through the API.
	body, _ := json.Marshal(map[string]any{"fields": map[string]any{"name": str("hacked")}})
	writes := []struct{ name, path, uid string }{
		{"owner: event", "events/" + pub, ownerUID},
		{"owner: published floor", "events/" + pub + "/published/map/floors/f1", ownerUID},
		{"owner: draft floor", "events/" + draft + "/draft/map/floors/f1", ownerUID},
		{"owner: stats", "events/" + pub + "/stats/2026-10-11", ownerUID},
		{"attendee: stats", "events/" + pub + "/stats/2026-10-11", attendeeUID},
		{"attendee: new event", "events/rules-" + newID(), attendeeUID},
	}
	for _, c := range writes {
		if code, _ := do(t, http.MethodPatch, docURL(c.path), token(c.uid), "application/json", body); code == http.StatusOK {
			t.Errorf("write %s was allowed", c.name)
		}
	}
	if code, _ := do(t, http.MethodDelete, docURL("events/"+pub), token(ownerUID), "", nil); code == http.StatusOK {
		t.Errorf("owner deleted the event doc directly")
	}
}

// Smallest valid PNG header bytes are enough: the rules only look at size and content type.
var pngBytes = []byte("\x89PNG\r\n\x1a\nrules-test")

func objectURL(path string) string {
	return storageHost + "/v0/b/" + bucket + "/o/" + url.PathEscape(path)
}

func upload(t *testing.T, path, uid, contentType string, data []byte) int {
	t.Helper()
	u := storageHost + "/v0/b/" + bucket + "/o?name=" + url.QueryEscape(path)
	code, _ := do(t, http.MethodPost, u, token(uid), contentType, data)
	return code
}

func TestStorageRules(t *testing.T) {
	setup(t)
	pub := newEvent(t, 1)
	draft := newEvent(t, 0)
	pubImg := "events/" + pub + "/floors/p.png"
	draftImg := "events/" + draft + "/floors/p.png"

	uploads := []struct {
		name, path, uid, contentType string
		data                         []byte
		allowed                      bool
	}{
		{"owner: png", pubImg, ownerUID, "image/png", pngBytes, true},
		{"owner: png on unpublished event", draftImg, ownerUID, "image/png", pngBytes, true},
		{"owner: jpeg", "events/" + pub + "/floors/p.jpg", ownerUID, "image/jpeg", pngBytes, true},
		{"owner: svg", "events/" + pub + "/floors/p.svg", ownerUID, "image/svg+xml", []byte("<svg/>"), false},
		{"owner: html", "events/" + pub + "/floors/p.html", ownerUID, "text/html", []byte("<p>"), false},
		{"owner: over 10 MB", "events/" + pub + "/floors/big.png", ownerUID, "image/png", make([]byte, 10<<20), false},
		{"owner: outside floors/", "events/" + pub + "/other/p.png", ownerUID, "image/png", pngBytes, false},
		{"attendee: png", "events/" + pub + "/floors/a.png", attendeeUID, "image/png", pngBytes, false},
		{"signed out: png", "events/" + pub + "/floors/s.png", "", "image/png", pngBytes, false},
	}
	for _, c := range uploads {
		code := upload(t, c.path, c.uid, c.contentType, c.data)
		if got := code == http.StatusOK; got != c.allowed {
			t.Errorf("upload %s: status %d, want allowed=%v", c.name, code, c.allowed)
		}
		if code == http.StatusOK {
			p := c.path
			t.Cleanup(func() { do(t, http.MethodDelete, objectURL(p), "owner", "", nil) })
		}
	}

	reads := []struct {
		name, path, uid string
		allowed         bool
	}{
		{"attendee: published event's plan", pubImg, attendeeUID, true},
		{"signed out: published event's plan", pubImg, "", false},
		{"attendee: unpublished event's plan", draftImg, attendeeUID, false},
		{"owner: unpublished event's plan", draftImg, ownerUID, true},
	}
	for _, c := range reads {
		code, _ := do(t, http.MethodGet, objectURL(c.path)+"?alt=media", token(c.uid), "", nil)
		if got := code == http.StatusOK; got != c.allowed {
			t.Errorf("read %s: status %d, want allowed=%v", c.name, code, c.allowed)
		}
	}

	if code, _ := do(t, http.MethodDelete, objectURL(pubImg), token(attendeeUID), "", nil); code == http.StatusOK || code == http.StatusNoContent {
		t.Errorf("attendee deleted a plan")
	}
	if code, _ := do(t, http.MethodDelete, objectURL(draftImg), token(ownerUID), "", nil); code != http.StatusOK && code != http.StatusNoContent {
		t.Errorf("owner delete: status %d", code)
	}
}
