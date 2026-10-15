package talks

import (
	"context"
	"errors"
	"testing"
	"time"
)

var now = time.Date(2026, 10, 11, 12, 0, 0, 0, time.UTC)

func TestParseCard(t *testing.T) {
	c, errs := ParseCard(CardInput{Name: " Ana  Anić ", Number: "4242 4242 4242 4242", Expiry: "12 / 29", CVC: "123"}, now)
	if errs != nil {
		t.Fatal(errs)
	}
	if c.Name != "Ana Anić" || c.Number != "4242424242424242" || c.ExpMonth != 12 || c.ExpYear != 2029 ||
		c.Brand() != "Visa" || c.Last4() != "4242" {
		t.Fatalf("%+v", c)
	}
	if _, errs := ParseCard(CardInput{Name: "A B", Number: "3782 822463 10005", Expiry: "01/30", CVC: "1234"}, now); errs != nil {
		t.Fatalf("amex with 4-digit CVC: %v", errs)
	}
	cases := []struct {
		in    CardInput
		field string
		key   string
	}{
		{CardInput{Name: "A B", Number: "4242 4242 4242 4241", Expiry: "12/29", CVC: "123"}, "card_number", "err.card_number"}, // Luhn
		{CardInput{Name: "A B", Number: "4242-x", Expiry: "12/29", CVC: "123"}, "card_number", "err.card_number"},
		{CardInput{Name: "A B", Number: "4242424242424242", Expiry: "09/26", CVC: "123"}, "card_expiry", "err.card_expired"},
		{CardInput{Name: "A B", Number: "4242424242424242", Expiry: "13/29", CVC: "123"}, "card_expiry", "err.card_expiry"},
		{CardInput{Name: "A B", Number: "4242424242424242", Expiry: "12/29", CVC: "12"}, "card_cvc", "err.card_cvc"},
		{CardInput{Name: "A B", Number: "378282246310005", Expiry: "12/29", CVC: "123"}, "card_cvc", "err.card_cvc"},
		{CardInput{Name: "", Number: "4242424242424242", Expiry: "12/29", CVC: "123"}, "card_name", "err.card_name"},
	}
	for _, c := range cases {
		if _, errs := ParseCard(c.in, now); errs[c.field] != c.key {
			t.Errorf("%+v: got %v, want %s=%s", c.in, errs, c.field, c.key)
		}
	}
	// The current month is still valid.
	if _, errs := ParseCard(CardInput{Name: "A B", Number: "4242424242424242", Expiry: "10/26", CVC: "123"}, now); errs != nil {
		t.Errorf("card valid until end of this month: %v", errs)
	}
}

func TestTestProvider(t *testing.T) {
	p := TestProvider{}
	ok, err := p.Charge(context.Background(), PriceCents, Currency, Card{Number: "4242424242424242"}, "x")
	if err != nil || ok.Mode != "test" || ok.Last4 != "4242" || ok.Brand != "Visa" || ok.ID == "" {
		t.Fatalf("%+v %v", ok, err)
	}
	for number, want := range map[string]error{
		"4000000000000002": ErrDeclined,
		"4000000000009995": ErrInsufficientFunds,
		"4111111111111111": ErrNotTestCard, // a real-looking Visa: refused in test mode
	} {
		if _, err := p.Charge(context.Background(), PriceCents, Currency, Card{Number: number}, "x"); !errors.Is(err, want) {
			t.Errorf("%s: got %v, want %v", number, err, want)
		}
	}
}

func TestMemRepoOnePurchasePerTalk(t *testing.T) {
	r := NewMemRepo()
	p := Purchase{UserID: "u", EventID: "e", SessionID: "s", AmountCents: PriceCents, CreatedAt: now}
	if err := r.Create(context.Background(), p); err != nil {
		t.Fatal(err)
	}
	if err := r.Create(context.Background(), p); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("got %v", err)
	}
	if got, _ := r.ListByUser(context.Background(), "u"); len(got) != 1 {
		t.Fatalf("%v", got)
	}
}
