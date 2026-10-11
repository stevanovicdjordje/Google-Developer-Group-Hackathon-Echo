// Command seed publishes the demo agenda (agenda.json, the same content as
// contracts/events/examples/agenda.response.json and the app's demo data)
// into the demo event created by backend/maps `make seed`.
//
//	go run ./cmd/seed [-event devfest]
//
// Session IDs stay fixed (s0…s6; the keynote is s1, which Echo's replay
// uses). Sessions are dated on the event's start date. Idempotent.
package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"time"

	"cloud.google.com/go/firestore"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
	"github.com/Ilij4n/eho/backend/events/internal/store"
)

//go:embed agenda.json
var agendaJSON []byte

func main() {
	eventID := flag.String("event", "devfest", "event ID (from backend/maps `make seed`)")
	flag.Parse()
	if err := run(*eventID); err != nil {
		fmt.Fprintln(os.Stderr, "seed:", err)
		os.Exit(1)
	}
}

func run(eventID string) error {
	ctx := context.Background()
	project := os.Getenv("FIREBASE_PROJECT_ID")
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		return errors.New("FIRESTORE_EMULATOR_HOST is not set: the seed only writes to the emulator")
	}
	fs, err := firestore.NewClient(ctx, project)
	if err != nil {
		return err
	}
	defer fs.Close()
	st := store.NewFirestoreStore(fs)

	e, err := st.GetEvent(ctx, eventID)
	if errors.Is(err, store.ErrNotFound) {
		return fmt.Errorf("no event %q: run `make seed` in backend/maps first", eventID)
	}
	if err != nil {
		return err
	}
	var a agenda.Agenda
	if err := json.Unmarshal(agendaJSON, &a); err != nil {
		return fmt.Errorf("agenda.json: %w", err)
	}
	for i := range a.Sessions {
		a.Sessions[i].Day = e.StartDate
	}
	a.PublishedAt = time.Now().UTC().Truncate(time.Millisecond)
	if err := agenda.Validate(&agenda.Fields{Name: e.Name, StartDate: e.StartDate, EndDate: e.EndDate,
		Stages: a.Stages, Speakers: a.Speakers, Sessions: a.Sessions}); err != nil {
		return fmt.Errorf("agenda.json invalid: %v", err)
	}
	if err := st.PublishAgenda(ctx, store.Publication{Event: *e, Agenda: a}); err != nil {
		return err
	}
	fmt.Printf("event %s: agenda published (%d sessions on %s)\n", eventID, len(a.Sessions), e.StartDate)
	return nil
}
