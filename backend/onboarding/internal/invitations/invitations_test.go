package invitations

import (
	"errors"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
)

var t0 = time.Date(2026, 10, 10, 10, 0, 0, 0, time.UTC)

func ptr(t time.Time) *time.Time { return &t }

func event(startH, endH int) events.Event {
	return events.Event{
		StartsAt:    ptr(t0.Add(time.Duration(startH) * time.Hour)),
		EndsAt:      ptr(t0.Add(time.Duration(endH) * time.Hour)),
		PublishedAt: ptr(t0.Add(-100 * time.Hour)),
	}
}

func TestEffectiveStatus(t *testing.T) {
	inv := Invitation{Status: StatusSent, ExpiresAt: t0.Add(24 * time.Hour)}
	upcoming := event(48, 50)
	if got := inv.Effective(upcoming, t0); got != StatusSent {
		t.Fatalf("got %s", got)
	}
	if got := inv.Effective(upcoming, t0.Add(25*time.Hour)); got != StatusExpired {
		t.Fatalf("past TTL: got %s", got)
	}
	if got := inv.Effective(event(-10, -5), t0); got != StatusExpired {
		t.Fatalf("event finished: got %s", got)
	}
	accepted := Invitation{Status: StatusAccepted, ExpiresAt: t0.Add(-time.Hour)}
	if got := accepted.Effective(event(-10, -5), t0); got != StatusAccepted {
		t.Fatalf("answered invitations never expire: got %s", got)
	}
}

func TestCheckRespond(t *testing.T) {
	inv := Invitation{Status: StatusSent, ExpiresAt: t0.Add(24 * time.Hour)}
	cases := []struct {
		name string
		inv  Invitation
		ev   events.Event
		user string
		want error
	}{
		{"open", inv, event(5, 8), "u1", nil},
		{"ongoing is still open", inv, event(-1, 8), "u1", nil},
		{"draft", inv, events.Event{}, "u1", ErrNotOpen},
		{"finished", inv, event(-10, -5), "u1", ErrNotOpen},
		{"expired", Invitation{Status: StatusSent, ExpiresAt: t0.Add(-time.Hour)}, event(5, 8), "u1", ErrExpired},
		{"bound to another account", Invitation{Status: StatusAccepted, UserID: "u2", ExpiresAt: t0.Add(time.Hour)}, event(5, 8), "u1", ErrTaken},
		{"owner may change answer", Invitation{Status: StatusDeclined, UserID: "u1", ExpiresAt: t0}, event(5, 8), "u1", nil},
	}
	for _, c := range cases {
		if err := CheckRespond(c.inv, c.ev, c.user, t0); !errors.Is(err, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, err, c.want)
		}
	}
}

func TestParseEmails(t *testing.T) {
	valid, invalid := ParseEmails("Ana@Primer.rs, marko@primer.rs;\n<jelena@primer.rs>  ana@primer.rs\nnije-email\n\n")
	if len(valid) != 3 || valid[0] != "ana@primer.rs" || valid[2] != "jelena@primer.rs" {
		t.Fatalf("valid = %v", valid)
	}
	if len(invalid) != 1 || invalid[0] != "nije-email" {
		t.Fatalf("invalid = %v", invalid)
	}
}
