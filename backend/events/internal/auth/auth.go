// Package auth verifies Firebase ID tokens.
package auth

import (
	"context"
	"errors"
	"fmt"

	fbauth "firebase.google.com/go/v4/auth"
)

// Principal is the authenticated caller.
type Principal struct {
	UID string
	// Anonymous is true for attendees signed in with Firebase anonymous auth.
	Anonymous bool
}

// ErrInvalidToken is returned for missing, malformed, expired or revoked tokens.
var ErrInvalidToken = errors.New("invalid ID token")

// Verifier turns a bearer token into a Principal.
type Verifier interface {
	Verify(ctx context.Context, idToken string) (Principal, error)
}

// FirebaseVerifier verifies tokens with the Firebase Admin SDK. It honors
// FIREBASE_AUTH_EMULATOR_HOST, so it accepts emulator tokens locally.
type FirebaseVerifier struct {
	Client *fbauth.Client
}

// Verify implements Verifier.
func (v FirebaseVerifier) Verify(ctx context.Context, idToken string) (Principal, error) {
	tok, err := v.Client.VerifyIDToken(ctx, idToken)
	if err != nil {
		return Principal{}, fmt.Errorf("%w: %v", ErrInvalidToken, err)
	}
	return Principal{UID: tok.UID, Anonymous: tok.Firebase.SignInProvider == "anonymous"}, nil
}

type ctxKey struct{}

// WithPrincipal stores p in ctx.
func WithPrincipal(ctx context.Context, p Principal) context.Context {
	return context.WithValue(ctx, ctxKey{}, p)
}

// FromContext returns the principal stored by WithPrincipal.
func FromContext(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(ctxKey{}).(Principal)
	return p, ok
}
