// Package talks sells the report of a single talk (session): an AI summary
// from Echo, the audience rating of that talk and the top audience
// questions, as a PDF. Anyone signed in can buy the report of any talk that
// has ended; the event's organizer gets it free.
//
// Payments are a test checkout (docs/decisions/feature-onboarding-talk-reports.md):
// card details are validated and charged through a PaymentProvider, but the
// only provider today is TestProvider, which accepts Stripe's test cards and
// never moves money.
package talks

import (
	"context"
	"errors"
	"time"
)

// PriceCents is the price of one talk report (EUR), decided by the team.
const (
	PriceCents = 299
	Currency   = "EUR"
)

var (
	ErrNotFound  = errors.New("talks: not found")
	ErrDuplicate = errors.New("talks: already purchased")
)

// Purchase is a paid talk report. Only the card brand and last four digits
// are kept, for the receipt; the card number and CVC are never stored.
type Purchase struct {
	ID          string
	UserID      string
	EventID     string
	SessionID   string
	AmountCents int
	Currency    string
	CardBrand   string
	CardLast4   string
	PaymentID   string
	Mode        string // "test" (no money moved) or a real provider later
	CreatedAt   time.Time
}

// PurchaseID makes "one purchase per user per talk" a document ID.
func PurchaseID(uid, eventID, sessionID string) string { return uid + "_" + eventID + "_" + sessionID }

type Repository interface {
	Get(ctx context.Context, uid, eventID, sessionID string) (Purchase, error)
	// Create returns ErrDuplicate when the user already owns the talk report.
	Create(ctx context.Context, p Purchase) error
	ListByUser(ctx context.Context, uid string) ([]Purchase, error)
}
