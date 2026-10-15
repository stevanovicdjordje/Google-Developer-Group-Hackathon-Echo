package talks

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
)

// Card is what the checkout form collects. It lives only for the duration of
// one request: it is never logged, stored or rendered back into the page.
type Card struct {
	Name     string
	Number   string // digits only
	ExpMonth int
	ExpYear  int // four digits
	CVC      string
}

// Brand guesses the card network from the number (for the receipt).
func (c Card) Brand() string {
	n := c.Number
	switch {
	case strings.HasPrefix(n, "4"):
		return "Visa"
	case strings.HasPrefix(n, "34"), strings.HasPrefix(n, "37"):
		return "American Express"
	case len(n) >= 2 && n[0] == '5' && n[1] >= '1' && n[1] <= '5':
		return "Mastercard"
	case len(n) >= 4 && n[:4] >= "2221" && n[:4] <= "2720":
		return "Mastercard"
	case strings.HasPrefix(n, "6011"), strings.HasPrefix(n, "65"):
		return "Discover"
	}
	return "Card"
}

func (c Card) Last4() string {
	if len(c.Number) < 4 {
		return c.Number
	}
	return c.Number[len(c.Number)-4:]
}

// luhn reports whether digits pass the card checksum.
func luhn(digits string) bool {
	sum, double := 0, false
	for i := len(digits) - 1; i >= 0; i-- {
		d := int(digits[i] - '0')
		if double {
			if d *= 2; d > 9 {
				d -= 9
			}
		}
		sum += d
		double = !double
	}
	return sum%10 == 0
}

func onlyDigits(s string) (string, bool) {
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == ' ' || r == '-':
		default:
			return "", false
		}
	}
	return b.String(), true
}

// CardInput is the raw form.
type CardInput struct {
	Name, Number, Expiry, CVC string
}

// ParseCard validates the form and returns field -> i18n error keys.
func ParseCard(in CardInput, now time.Time) (Card, map[string]string) {
	errs := map[string]string{}
	c := Card{Name: strings.Join(strings.Fields(in.Name), " ")}
	if n := utf8.RuneCountInString(c.Name); n < 2 || n > 100 {
		errs["card_name"] = "err.card_name"
	}
	num, ok := onlyDigits(in.Number)
	if !ok || len(num) < 12 || len(num) > 19 || !luhn(num) {
		errs["card_number"] = "err.card_number"
	}
	c.Number = num

	exp := strings.ReplaceAll(strings.TrimSpace(in.Expiry), " ", "")
	parts := strings.Split(exp, "/")
	month, year := 0, 0
	if len(parts) == 2 {
		month, _ = strconv.Atoi(parts[0])
		year, _ = strconv.Atoi(parts[1])
		if year < 100 {
			year += 2000
		}
	}
	switch {
	case month < 1 || month > 12 || year < 2000:
		errs["card_expiry"] = "err.card_expiry"
	case time.Date(year, time.Month(month)+1, 1, 0, 0, 0, 0, time.UTC).Before(now):
		errs["card_expiry"] = "err.card_expired"
	}
	c.ExpMonth, c.ExpYear = month, year

	cvc, ok := onlyDigits(in.CVC)
	want := 3
	if c.Brand() == "American Express" {
		want = 4
	}
	if !ok || len(cvc) != want {
		errs["card_cvc"] = "err.card_cvc"
	}
	c.CVC = cvc
	if len(errs) > 0 {
		return Card{}, errs
	}
	return c, nil
}

// Charge is a successful payment.
type Charge struct {
	ID    string
	Mode  string
	Brand string
	Last4 string
}

var (
	ErrDeclined          = errors.New("payment: card declined")
	ErrInsufficientFunds = errors.New("payment: insufficient funds")
	// ErrNotTestCard: test mode accepts only test card numbers, so nobody
	// types a real card believing they are paying.
	ErrNotTestCard = errors.New("payment: test mode accepts only test cards")
)

// PaymentProvider charges a card. A Stripe implementation can replace
// TestProvider without touching the checkout.
type PaymentProvider interface {
	Charge(ctx context.Context, amountCents int, currency string, card Card, description string) (Charge, error)
}

// TestProvider simulates a card processor with Stripe's test card numbers.
// No money moves.
type TestProvider struct{}

// Test cards (the same numbers Stripe documents for test mode).
var testCards = map[string]error{
	"4242424242424242": nil,
	"5555555555554444": nil,
	"4000000000000002": ErrDeclined,
	"4000000000009995": ErrInsufficientFunds,
}

func (TestProvider) Charge(_ context.Context, _ int, _ string, card Card, _ string) (Charge, error) {
	outcome, known := testCards[card.Number]
	if !known {
		return Charge{}, ErrNotTestCard
	}
	if outcome != nil {
		return Charge{}, outcome
	}
	return Charge{ID: "test_ch_" + id.Token(10), Mode: "test", Brand: card.Brand(), Last4: card.Last4()}, nil
}
