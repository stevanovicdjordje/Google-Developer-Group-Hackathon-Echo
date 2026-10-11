// Command seed writes fake demo attendees to Firestore (the emulator) and
// marks them present at the published demo event, so Find has people to show.
//
//	go run ./cmd/seed [-event <eventId>]
//
// Without -event it picks the published event created by backend/maps
// `make seed` ("DevFest Belgrade 2026"). Idempotent: person IDs are kept.
// Demo attendees (demo: true) accept contact requests at once.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"

	"github.com/Ilij4n/eho/backend/find/internal/store"
)

const demoEventName = "DevFest Belgrade 2026"

// The first 12 match mobile/app/lib/data/demo_data.dart (`people`); the rest
// are clearly fake extras. All names are invented.
var attendees = []store.ProfileFields{
	{Name: "Ana Petrović", Headline: "Android dev at Fintio", Interests: []string{"Mobile", "AI / ML"}, LookingFor: "People who shipped on-device ML in production"},
	{Name: "Milan Jovanović", Headline: "Founder, ParkIt", Interests: []string{"Startups", "Mobile"}, LookingFor: "A technical co-founder"},
	{Name: "Teodora Nikolić", Headline: "ML researcher, Univ. of Belgrade", Interests: []string{"AI / ML", "Data"}, LookingFor: "Industry partners for speech models"},
	{Name: "Stefan Lazić", Headline: "Backend lead at Nebo Cloud", Interests: []string{"Backend", "Cloud"}, LookingFor: "Senior Go engineers"},
	{Name: "Ivana Milić", Headline: "Product manager, Kvadrat", Interests: []string{"Product", "Design"}, LookingFor: "Designers interested in AI products"},
	{Name: "Dušan Ristić", Headline: "iOS & Flutter freelancer", Interests: []string{"Mobile", "Design"}, LookingFor: "Interesting side projects"},
	{Name: "Jelena Stanković", Headline: "Data engineer, Orbita", Interests: []string{"Data", "Cloud"}, LookingFor: "People running LLMs on a budget"},
	{Name: "Marko Simić", Headline: "Security engineer", Interests: []string{"Security", "Backend"}, LookingFor: "Talks on AI security"},
	{Name: "Nina Popović", Headline: "Designer at Talas AI", Interests: []string{"Design", "AI / ML"}, LookingFor: "Mobile devs to prototype with"},
	{Name: "Vuk Tomić", Headline: "CTO, Mreža", Interests: []string{"Startups", "Backend", "Hiring"}, LookingFor: "Mobile engineers to hire"},
	{Name: "Katarina Božić", Headline: "Speech tech PhD student", Interests: []string{"AI / ML", "Data"}, LookingFor: "Teams building transcription"},
	{Name: "Aleksa Kovačević", Headline: "Junior Android dev", Interests: []string{"Mobile"}, LookingFor: "A mentor in mobile AI"},
	{Name: "Mila Testić", Headline: "Engineering manager, Primer Labs", Interests: []string{"Hiring", "Mobile", "Backend"}, LookingFor: "Flutter and Kotlin engineers to hire this year"},
	{Name: "Petar Demović", Headline: "Staff engineer, mentor at a dev bootcamp", Interests: []string{"Backend", "Cloud", "Security"}, LookingFor: "Juniors to mentor in backend and cloud"},
	{Name: "Sara Uzorić", Headline: "Voice AI engineer at Glas Labs", Interests: []string{"AI / ML", "Mobile"}, LookingFor: "People building speech recognition on phones"},
	{Name: "Luka Primerović", Headline: "UX designer, freelance", Interests: []string{"Design", "Product"}, LookingFor: "Startups that need a product designer"},
	{Name: "Jovana Fiktić", Headline: "Founder, early-stage health startup", Interests: []string{"Startups", "Product", "AI / ML"}, LookingFor: "Investors and a first ML engineer"},
	{Name: "Nikola Lažić", Headline: "Cloud architect, consulting", Interests: []string{"Cloud", "Security", "Data"}, LookingFor: "Teams moving AI workloads to the cloud"},
	{Name: "Tamara Izmišljen", Headline: "Data scientist, mentor at Women in Tech", Interests: []string{"Data", "AI / ML"}, LookingFor: "Mentees starting a career in data science"},
	{Name: "Đorđe Probić", Headline: "Recruiter, Sever Tech", Interests: []string{"Hiring", "Startups"}, LookingFor: "Designers and AI engineers open to new roles"},
}

func main() {
	eventID := flag.String("event", "", "event ID (default: the published "+demoEventName+")")
	project := flag.String("project", envOr("FIREBASE_PROJECT_ID", "demo-eho"), "Firebase project ID")
	flag.Parse()
	if err := run(context.Background(), *project, *eventID); err != nil {
		fmt.Fprintln(os.Stderr, "seed:", err)
		os.Exit(1)
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func run(ctx context.Context, project, eventID string) error {
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		return errors.New("FIRESTORE_EMULATOR_HOST is not set: the seed only writes to the emulator")
	}
	fs, err := firestore.NewClient(ctx, project)
	if err != nil {
		return err
	}
	defer fs.Close()
	if eventID == "" {
		if eventID, err = findDemoEvent(ctx, fs); err != nil {
			return err
		}
	}
	st := store.NewFirestoreStore(fs)
	if e, err := st.GetEvent(ctx, eventID); err != nil || !e.Published() {
		return fmt.Errorf("event %s is missing or not published (%v)", eventID, err)
	}
	now := time.Now().UTC()
	for i, a := range attendees {
		uid := fmt.Sprintf("demo-attendee-%02d", i+1)
		a.VisibleInFind, a.AllowContact, a.ShareMeetingSpot = true, true, true
		if _, err := st.SaveProfile(ctx, uid, a, now); err != nil {
			return fmt.Errorf("%s: %w", uid, err)
		}
		if _, err := fs.Collection("profiles").Doc(uid).Update(ctx, []firestore.Update{{Path: "demo", Value: true}}); err != nil {
			return fmt.Errorf("%s: %w", uid, err)
		}
		if err := st.Join(ctx, eventID, uid, now); err != nil {
			return fmt.Errorf("%s: join: %w", uid, err)
		}
	}
	fmt.Printf("event %s: %d demo attendees present (demo-attendee-01..%02d)\n", eventID, len(attendees), len(attendees))
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
