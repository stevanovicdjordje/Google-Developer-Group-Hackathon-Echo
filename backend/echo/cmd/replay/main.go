// Command replay plays a pre-recorded transcript into Firestore as if the talk
// were live (team-captions-and-stt). Attendees see the lines appear through
// their snapshot listeners (contracts/echo/realtime.md).
//
//	go run ./cmd/replay -event <eventId> [-file demo/keynote.json] [-speed 2] [-instant]
//
// Without -event it picks the published demo event created by
// backend/maps `make seed` ("Eho Demo Expo").
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"

	"github.com/Ilij4n/eho/backend/echo/internal/assist"
	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

const demoEventName = "Eho Demo Expo"

type transcriptFile struct {
	SessionID string `json:"sessionId"`
	Title     string `json:"title"`
	Speaker   string `json:"speaker"`
	Language  string `json:"language"`
	Lines     []struct {
		AtSeconds int    `json:"atSeconds"`
		Text      string `json:"text"`
	} `json:"lines"`
}

func main() {
	eventID := flag.String("event", "", "event ID (default: the published "+demoEventName+")")
	sessionID := flag.String("session", "", "session ID (default: sessionId from the file)")
	file := flag.String("file", "demo/keynote.json", "transcript JSON file")
	speed := flag.Float64("speed", 2, "replay speed (2 = twice as fast as recorded)")
	instant := flag.Bool("instant", false, "write all lines at once")
	project := flag.String("project", envOr("FIREBASE_PROJECT_ID", "demo-eho"), "Firebase project ID")
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	if err := run(ctx, *project, *eventID, *sessionID, *file, *speed, *instant); err != nil {
		fmt.Fprintln(os.Stderr, "replay:", err)
		os.Exit(1)
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func load(path string) (transcriptFile, error) {
	var tf transcriptFile
	raw, err := os.ReadFile(path)
	if err != nil {
		return tf, err
	}
	if err := json.Unmarshal(raw, &tf); err != nil {
		return tf, fmt.Errorf("%s: %w", path, err)
	}
	if _, ok := assist.Languages[tf.Language]; !ok {
		return tf, fmt.Errorf("%s: unsupported language %q", path, tf.Language)
	}
	prev := 0
	for i, l := range tf.Lines {
		if strings.TrimSpace(l.Text) == "" || l.AtSeconds < prev {
			return tf, fmt.Errorf("%s: line %d is empty or out of order", path, i)
		}
		prev = l.AtSeconds
	}
	if len(tf.Lines) == 0 {
		return tf, fmt.Errorf("%s: no lines", path)
	}
	return tf, nil
}

func run(ctx context.Context, project, eventID, sessionID, file string, speed float64, instant bool) error {
	tf, err := load(file)
	if err != nil {
		return err
	}
	if sessionID == "" {
		sessionID = tf.SessionID
	}
	if speed <= 0 {
		return errors.New("-speed must be positive")
	}
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		fmt.Fprintln(os.Stderr, "FIRESTORE_EMULATOR_HOST is not set: writing to the real project", project)
	}

	fs, err := firestore.NewClient(ctx, project)
	if err != nil {
		return fmt.Errorf("firestore: %w", err)
	}
	defer fs.Close()
	st := store.NewFirestoreStore(fs)

	if eventID == "" {
		if eventID, err = findDemoEvent(ctx, fs); err != nil {
			return err
		}
	}
	ev, err := st.GetEvent(ctx, eventID)
	if err != nil {
		return fmt.Errorf("event %s: %w", eventID, err)
	}
	if !ev.Published() {
		fmt.Fprintln(os.Stderr, "warning: the event is not published, attendees can't read the transcript yet")
	}

	if err := st.ResetTranscript(ctx, eventID, sessionID, store.SessionMeta{Language: tf.Language, Title: tf.Title, Speaker: tf.Speaker}); err != nil {
		return err
	}
	fmt.Printf("replaying %q (%d lines) into event %s, session %s\n", tf.Title, len(tf.Lines), eventID, sessionID)
	start := time.Now()
	for i, l := range tf.Lines {
		if !instant {
			due := start.Add(time.Duration(float64(l.AtSeconds) / speed * float64(time.Second)))
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(time.Until(due)):
			}
		}
		line := store.Line{Index: i, AtSeconds: l.AtSeconds, Text: strings.TrimSpace(l.Text)}
		if err := st.AppendLine(ctx, eventID, sessionID, line, i == len(tf.Lines)-1); err != nil {
			return err
		}
		fmt.Printf("[%02d:%02d] %s\n", l.AtSeconds/60, l.AtSeconds%60, line.Text)
	}
	fmt.Println("done: session ended")
	return nil
}

func findDemoEvent(ctx context.Context, fs *firestore.Client) (string, error) {
	it := fs.Collection("events").Where("name", "==", demoEventName).Documents(ctx)
	defer it.Stop()
	for {
		d, err := it.Next()
		if errors.Is(err, iterator.Done) {
			return "", fmt.Errorf("no published %q event: run `make seed` in backend/maps first, or pass -event", demoEventName)
		}
		if err != nil {
			return "", fmt.Errorf("find demo event: %w", err)
		}
		if v, _ := d.Data()["publishedVersion"].(int64); v > 0 {
			return d.Ref.ID, nil
		}
	}
}
