package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	fbauth "firebase.google.com/go/v4/auth"

	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// FirebaseIdentity uses the Admin SDK for accounts and session cookies, and
// the Identity Toolkit REST API for the password check (the Admin SDK can't
// verify passwords). Both honor the Auth emulator.
type FirebaseIdentity struct {
	Client *fbauth.Client
	APIKey string
	// EmulatorHost is FIREBASE_AUTH_EMULATOR_HOST ("" in production).
	EmulatorHost string
	HTTP         *http.Client
}

func (f *FirebaseIdentity) SignUp(ctx context.Context, email, password, name string, role users.Role) (string, error) {
	u, err := f.Client.CreateUser(ctx, (&fbauth.UserToCreate{}).Email(email).Password(password).DisplayName(name))
	if fbauth.IsEmailAlreadyExists(err) {
		return "", users.ErrEmailTaken
	}
	if err != nil {
		return "", fmt.Errorf("create user: %w", err)
	}
	if err := f.Client.SetCustomUserClaims(ctx, u.UID, map[string]any{"role": string(role)}); err != nil {
		return "", fmt.Errorf("set role claim: %w", err)
	}
	return u.UID, nil
}

func (f *FirebaseIdentity) restURL(method string) string {
	base := "https://identitytoolkit.googleapis.com/v1/"
	if f.EmulatorHost != "" {
		base = "http://" + f.EmulatorHost + "/identitytoolkit.googleapis.com/v1/"
	}
	return base + method + "?key=" + url.QueryEscape(f.APIKey)
}

func (f *FirebaseIdentity) SignIn(ctx context.Context, email, password string) (string, error) {
	body, _ := json.Marshal(map[string]any{"email": email, "password": password, "returnSecureToken": true})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.restURL("accounts:signInWithPassword"), bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	client := f.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	res, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("sign in: %w", err)
	}
	defer res.Body.Close()
	var out struct {
		IDToken string `json:"idToken"`
		Error   *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		return "", fmt.Errorf("sign in: decode: %w", err)
	}
	if out.Error != nil {
		// Messages look like "INVALID_PASSWORD" or "TOO_MANY_ATTEMPTS_TRY_LATER : ...".
		code := strings.TrimSpace(strings.SplitN(out.Error.Message, ":", 2)[0])
		switch code {
		case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS", "USER_DISABLED", "INVALID_EMAIL":
			return "", ErrInvalidCredentials
		case "TOO_MANY_ATTEMPTS_TRY_LATER":
			return "", ErrTooManyAttempts
		}
		return "", fmt.Errorf("sign in: %s", code)
	}
	if out.IDToken == "" {
		return "", fmt.Errorf("sign in: empty token (status %d)", res.StatusCode)
	}
	return out.IDToken, nil
}

// SignInWithCustomToken exchanges an Admin-minted custom token for an ID
// token (used by ServiceToken).
func (f *FirebaseIdentity) signInWithCustomToken(ctx context.Context, custom string) (string, int, error) {
	body, _ := json.Marshal(map[string]any{"token": custom, "returnSecureToken": true})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.restURL("accounts:signInWithCustomToken"), bytes.NewReader(body))
	if err != nil {
		return "", 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	client := f.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	res, err := client.Do(req)
	if err != nil {
		return "", 0, err
	}
	defer res.Body.Close()
	var out struct {
		IDToken   string `json:"idToken"`
		ExpiresIn string `json:"expiresIn"`
		Error     *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		return "", 0, err
	}
	if out.Error != nil || out.IDToken == "" {
		msg := "empty token"
		if out.Error != nil {
			msg = out.Error.Message
		}
		return "", 0, fmt.Errorf("custom token sign-in: %s", msg)
	}
	secs := 3600
	fmt.Sscan(out.ExpiresIn, &secs)
	return out.IDToken, secs, nil
}

// ServiceToken returns an ID token for this server's own service account
// user, to call other Eho services (Echo). It is cached until shortly
// before it expires.
type ServiceToken struct {
	Identity *FirebaseIdentity
	UID      string // e.g. "svc-onboarding"

	mu    sync.Mutex
	token string
	until time.Time
}

func (s *ServiceToken) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token != "" && time.Now().Before(s.until) {
		return s.token, nil
	}
	custom, err := s.Identity.Client.CustomTokenWithClaims(ctx, s.UID, map[string]any{"role": "service"})
	if err != nil {
		return "", fmt.Errorf("mint custom token: %w", err)
	}
	tok, secs, err := s.Identity.signInWithCustomToken(ctx, custom)
	if err != nil {
		return "", err
	}
	s.token, s.until = tok, time.Now().Add(time.Duration(secs)*time.Second-5*time.Minute)
	return tok, nil
}

func (f *FirebaseIdentity) NewSession(ctx context.Context, idToken string, ttl time.Duration) (string, error) {
	return f.Client.SessionCookie(ctx, idToken, ttl)
}

func (f *FirebaseIdentity) VerifySession(ctx context.Context, cookie string) (Claims, error) {
	tok, err := f.Client.VerifySessionCookie(ctx, cookie)
	if err != nil {
		return Claims{}, fmt.Errorf("%w: %v", ErrInvalidSession, err)
	}
	c := Claims{UID: tok.UID, Anonymous: tok.Firebase.SignInProvider == "anonymous"}
	c.Email, _ = tok.Claims["email"].(string)
	c.Name, _ = tok.Claims["name"].(string)
	c.Role = ResolveRole(tok.Claims["role"], c.Anonymous)
	return c, nil
}
