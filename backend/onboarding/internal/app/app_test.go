package app_test

import (
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"testing"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
)

type client struct {
	t   *testing.T
	srv *httptest.Server
	c   *http.Client
}

func newServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv, _ := newServerDeps(t)
	return srv
}

func newServerDeps(t *testing.T) (*httptest.Server, app.Deps) {
	t.Helper()
	deps := app.MemDeps()
	h, err := app.New(config.Config{Timezone: "UTC", BaseURL: "http://eho.test", AppURL: "http://app.test"}, deps)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return srv, deps
}

func newClient(t *testing.T, srv *httptest.Server) *client {
	jar, _ := cookiejar.New(nil)
	return &client{t: t, srv: srv, c: &http.Client{
		Jar:           jar,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
}

func (c *client) get(path string) (*http.Response, string) {
	c.t.Helper()
	res, err := c.c.Get(c.srv.URL + path)
	if err != nil {
		c.t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res, string(b)
}

var csrfRe = regexp.MustCompile(`name="csrf_token" value="([0-9a-f]{64})"`)

// post fetches formPath to obtain a CSRF token, then posts form to path.
func (c *client) post(formPath, path string, form url.Values) (*http.Response, string) {
	c.t.Helper()
	_, body := c.get(formPath)
	m := csrfRe.FindStringSubmatch(body)
	if m == nil {
		c.t.Fatalf("no csrf token on %s", formPath)
	}
	form.Set("csrf_token", m[1])
	res, err := c.c.PostForm(c.srv.URL+path, form)
	if err != nil {
		c.t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res, string(b)
}

func expect(t *testing.T, res *http.Response, status int, location string) {
	t.Helper()
	if res.StatusCode != status {
		t.Fatalf("%s %s: status %d, want %d", res.Request.Method, res.Request.URL.Path, res.StatusCode, status)
	}
	if location != "" && res.Header.Get("Location") != location {
		t.Fatalf("%s: Location %q, want %q", res.Request.URL.Path, res.Header.Get("Location"), location)
	}
}

func registerOrganizer(c *client, email string) {
	res, _ := c.post("/register/organizer", "/register/organizer", url.Values{
		"full_name": {"Ana Anić"}, "email": {email}, "org_name": {"GDG Beograd"},
		"password": {"lozinka123"}, "password_confirm": {"lozinka123"},
	})
	expect(c.t, res, http.StatusSeeOther, "/org/events")
}

func registerParticipant(c *client, email string) {
	res, _ := c.post("/register/participant", "/register/participant", url.Values{
		"full_name": {"Marko Marković"}, "email": {email},
		"password": {"lozinka123"}, "password_confirm": {"lozinka123"},
	})
	expect(c.t, res, http.StatusSeeOther, "/onboarding")
}

func TestOrganizerRegistrationAndRoleIsolation(t *testing.T) {
	srv := newServer(t)
	c := newClient(t, srv)
	registerOrganizer(c, "ana@primer.rs")

	res, body := c.get("/org/events")
	expect(t, res, http.StatusOK, "")
	if !strings.Contains(body, "Još nemate evente") {
		t.Fatal("empty state missing")
	}
	// Organizers may not use participant routes.
	res, _ = c.get("/onboarding/1")
	expect(t, res, http.StatusForbidden, "")
	res, _ = c.get("/me/events")
	expect(t, res, http.StatusForbidden, "")
}

func TestAnonymousIsSentToLogin(t *testing.T) {
	c := newClient(t, newServer(t))
	res, _ := c.get("/org/events")
	expect(t, res, http.StatusSeeOther, "/login?next=%2Forg%2Fevents")
}

func TestDuplicateEmailAndValidation(t *testing.T) {
	srv := newServer(t)
	registerOrganizer(newClient(t, srv), "ana@primer.rs")

	c := newClient(t, srv)
	res, body := c.post("/register/participant", "/register/participant", url.Values{
		"full_name": {"X"}, "email": {"ANA@primer.rs"},
		"password": {"kratka"}, "password_confirm": {"kratka"},
	})
	expect(t, res, http.StatusUnprocessableEntity, "")
	for _, want := range []string{"Ime mora imati", "najmanje 8 karaktera"} {
		if !strings.Contains(body, want) {
			t.Errorf("missing error %q", want)
		}
	}
	res, body = c.post("/register/participant", "/register/participant", url.Values{
		"full_name": {"Xena"}, "email": {"ANA@primer.rs"},
		"password": {"lozinka123"}, "password_confirm": {"lozinka123"},
	})
	expect(t, res, http.StatusUnprocessableEntity, "")
	if !strings.Contains(body, "već postoji") {
		t.Error("expected email taken error")
	}
}

func TestCSRFRequired(t *testing.T) {
	c := newClient(t, newServer(t))
	c.get("/login") // obtain csrf cookie, but send no token
	res, err := c.c.PostForm(c.srv.URL+"/login", url.Values{"email": {"a@b.rs"}, "password": {"x"}})
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	expect(t, res, http.StatusForbidden, "")
}

func TestLoginLogout(t *testing.T) {
	srv := newServer(t)
	registerOrganizer(newClient(t, srv), "ana@primer.rs")

	c := newClient(t, srv)
	res, body := c.post("/login", "/login", url.Values{"email": {"ana@primer.rs"}, "password": {"pogresna1"}})
	expect(t, res, http.StatusUnauthorized, "")
	if !strings.Contains(body, "Pogrešan email ili lozinka") {
		t.Fatal("missing credentials error")
	}
	res, _ = c.post("/login", "/login", url.Values{"email": {"Ana@Primer.rs"}, "password": {"lozinka123"}})
	expect(t, res, http.StatusSeeOther, "/")
	res, _ = c.get("/")
	expect(t, res, http.StatusSeeOther, "/org/events")

	res, _ = c.post("/org/events", "/logout", url.Values{})
	expect(t, res, http.StatusSeeOther, "/")
	res, _ = c.get("/org/events")
	expect(t, res, http.StatusSeeOther, "/login?next=%2Forg%2Fevents")
}

func TestParticipantOnboardingFlow(t *testing.T) {
	srv := newServer(t)
	c := newClient(t, srv)
	registerParticipant(c, "marko@primer.rs")

	// Panel and later steps are locked until onboarding is done.
	res, _ := c.get("/me/events")
	expect(t, res, http.StatusSeeOther, "/onboarding")
	res, _ = c.get("/onboarding/3")
	expect(t, res, http.StatusSeeOther, "/onboarding/1")
	res, _ = c.get("/org/events")
	expect(t, res, http.StatusForbidden, "")

	res, _ = c.post("/onboarding/1", "/onboarding/1", url.Values{"language": {"xx"}})
	expect(t, res, http.StatusUnprocessableEntity, "")
	res, _ = c.post("/onboarding/1", "/onboarding/1", url.Values{"language": {"en"}})
	expect(t, res, http.StatusSeeOther, "/onboarding/2")

	res, _ = c.post("/onboarding/2", "/onboarding/2", url.Values{"interests": {"ai", "web"}})
	expect(t, res, http.StatusUnprocessableEntity, "")
	res, _ = c.post("/onboarding/2", "/onboarding/2", url.Values{"interests": {"ai", "web"}, "custom": {"Go"}})
	expect(t, res, http.StatusSeeOther, "/onboarding/3")

	res, _ = c.post("/onboarding/3", "/onboarding/3", url.Values{"goal": {"hiring"}})
	expect(t, res, http.StatusSeeOther, "/onboarding/4")

	// Visibility checkbox is off by default.
	_, body := c.get("/onboarding/4")
	if strings.Contains(body, `value="on" checked`) {
		t.Fatal("visibility must default to off")
	}
	res, _ = c.post("/onboarding/4", "/onboarding/4", url.Values{})
	expect(t, res, http.StatusSeeOther, "/onboarding/5")

	res, _ = c.post("/onboarding/5", "/onboarding/5", url.Values{})
	expect(t, res, http.StatusUnprocessableEntity, "")
	res, _ = c.post("/onboarding/5", "/onboarding/5", url.Values{"gdpr": {"on"}})
	expect(t, res, http.StatusSeeOther, "/me/events")

	res, _ = c.get("/me/events")
	expect(t, res, http.StatusOK, "")
	res, _ = c.get("/")
	expect(t, res, http.StatusSeeOther, "/me/events")
}

func TestOpenRedirectBlocked(t *testing.T) {
	srv := newServer(t)
	registerOrganizer(newClient(t, srv), "ana@primer.rs")
	c := newClient(t, srv)
	res, _ := c.post("/login", "/login", url.Values{
		"email": {"ana@primer.rs"}, "password": {"lozinka123"}, "next": {"//evil.example"}})
	expect(t, res, http.StatusSeeOther, "/")
}
