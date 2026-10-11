// Command seed fills the Firebase emulators with clearly fake demo data for
// the onboarding module. Run backend/maps `make seed` (map of the "devfest"
// event) and backend/events `make seed` (its agenda) first; this adds:
//
//   - the organizer role and organization for the shared demo organizer
//     organizer@eho.test (created if missing),
//   - 20 participants ucesnik01..20@eho.test with finished onboarding,
//   - a finished event with invitations and 13 reviews, an upcoming
//     two-day event, and invitations to devfest (ongoing today).
//
// Re-running replaces this command's data (fixed IDs). It refuses to run
// outside the emulators.
package main

import (
	"context"
	"fmt"
	"log"
	"math/rand/v2"
	"os"
	"time"

	"cloud.google.com/go/firestore"
	fbauth "firebase.google.com/go/v4/auth"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/fb"
	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

const (
	orgEmail     = "organizer@eho.test" // same demo organizer as backend/maps
	demoPassword = "eho-demo-123"
	summitID     = "onb-summit"
	startupID    = "onb-startup"
	devfestID    = "devfest"
)

var names = []string{
	"Ana Demić", "Marko Testić", "Jelena Primerić", "Nikola Probić", "Milica Uzorić",
	"Stefan Lažić", "Ivana Fiktić", "Luka Izmišljenić", "Teodora Demović", "Vuk Primerović",
	"Sara Testović", "Filip Probović", "Katarina Uzorović", "Petar Lažović", "Mina Fiktović",
	"Đorđe Demski", "Nina Testska", "Aleksa Primerski", "Jovana Probska", "Uroš Uzorski",
}

func main() {
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" || os.Getenv("FIREBASE_AUTH_EMULATOR_HOST") == "" {
		log.Fatal("seed works only against the Firebase emulators (set FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST, or use scripts/dev.sh)")
	}
	ctx := context.Background()
	cfg := config.Load()
	c, err := fb.New(ctx, cfg)
	if err != nil {
		log.Fatal(err)
	}
	defer c.Close()
	loc := app.Location(cfg)
	s := &seeder{cfg: cfg, c: c, loc: loc, rnd: rand.New(rand.NewPCG(2026, 10)), now: time.Now().UTC(),
		users: users.NewFirestoreRepo(c.Firestore), events: events.NewFirestoreRepo(c.Firestore, loc),
		invs: invitations.NewFirestoreRepo(c.Firestore), reviews: reviews.NewFirestoreRepo(c.Firestore)}
	if err := s.run(ctx); err != nil {
		log.Fatal(err)
	}
}

type seeder struct {
	cfg     config.Config
	c       *fb.Clients
	loc     *time.Location
	rnd     *rand.Rand
	now     time.Time
	users   *users.FirestoreRepo
	events  *events.FirestoreRepo
	invs    *invitations.FirestoreRepo
	reviews *reviews.FirestoreRepo

	orgUID       string
	participants []participant
}

type participant struct{ uid, email, name string }

// account returns the user with this email, creating it if needed, and sets the role claim.
func (s *seeder) account(ctx context.Context, email, name string, role users.Role) (string, error) {
	u, err := s.c.Auth.GetUserByEmail(ctx, email)
	if fbauth.IsUserNotFound(err) {
		u, err = s.c.Auth.CreateUser(ctx, (&fbauth.UserToCreate{}).Email(email).Password(demoPassword).DisplayName(name))
	}
	if err != nil {
		return "", fmt.Errorf("account %s: %w", email, err)
	}
	if err := s.c.Auth.SetCustomUserClaims(ctx, u.UID, map[string]any{"role": string(role)}); err != nil {
		return "", err
	}
	return u.UID, nil
}

func (s *seeder) run(ctx context.Context) error {
	var err error
	if s.orgUID, err = s.account(ctx, orgEmail, "Olivera Organizović", users.RoleOrganizer); err != nil {
		return err
	}
	if err := s.users.SaveOrganization(ctx, users.Organization{OwnerUID: s.orgUID, Name: "Eho Demo Konferencije",
		Website: "https://eho.test", CreatedAt: s.now}); err != nil {
		return err
	}
	if err := s.seedParticipants(ctx); err != nil {
		return err
	}
	for _, evID := range []string{summitID, startupID, devfestID} {
		if err := s.clear(ctx, evID); err != nil {
			return err
		}
	}

	today := time.Date(s.now.In(s.loc).Year(), s.now.In(s.loc).Month(), s.now.In(s.loc).Day(), 0, 0, 0, 0, s.loc)

	summitDay := today.AddDate(0, 0, -10)
	if err := s.seedEvent(ctx, summitID, "Eho Dev Summit 2026",
		"Godišnja konferencija o razvoju softvera: veb, cloud i veštačka inteligencija.",
		"Bulevar Mihajla Pupina 10, Beograd", 44.8176, 20.4569, summitDay.Add(9*time.Hour), summitDay.Add(18*time.Hour), 1); err != nil {
		return err
	}
	if err := s.invite(ctx, summitID, 0, 20, 16, 3); err != nil {
		return err
	}
	if err := s.seedReviews(ctx, summitID, 13); err != nil {
		return err
	}

	startDay := today.AddDate(0, 0, 14)
	if err := s.seedEvent(ctx, startupID, "Startap vikend Novi Sad",
		"Dva dana radionica, mentorstva i pitchinga za mlade timove.",
		"Bulevar oslobođenja 30, Novi Sad", 45.2551, 19.8450, startDay.Add(10*time.Hour), startDay.AddDate(0, 0, 1).Add(18*time.Hour), 2); err != nil {
		return err
	}
	if err := s.invite(ctx, startupID, 0, 12, 6, 1); err != nil {
		return err
	}

	devfestNote := "devfest (backend/maps `make seed`) not found: run it first for the ongoing event with a venue map"
	if dev, err := s.events.Get(ctx, devfestID); err == nil && dev.OwnerUID == s.orgUID {
		if err := s.invite(ctx, devfestID, 0, 14, 12, 1); err != nil {
			return err
		}
		devfestNote = "devfest: 14 participants invited (12 accepted)"
	}

	fmt.Printf(`Onboarding demo data created (Firebase emulators, project %s)

  Organizer:    %s / %s   (same account as the map editor demo)
  Participants: ucesnik01@eho.test … ucesnik20@eho.test / %s
  Events:       %q (finished, 13 reviews), %q (upcoming), %s

Open %s
`, s.cfg.ProjectID, orgEmail, demoPassword, demoPassword, "Eho Dev Summit 2026", "Startap vikend Novi Sad", devfestNote, s.cfg.BaseURL)
	return nil
}

func (s *seeder) seedParticipants(ctx context.Context) error {
	for i, name := range names {
		email := fmt.Sprintf("ucesnik%02d@eho.test", i+1)
		uid, err := s.account(ctx, email, name, users.RoleParticipant)
		if err != nil {
			return err
		}
		if err := s.users.CreateProfile(ctx, uid, s.now); err != nil {
			return err
		}
		prof := users.Profile{UserID: uid, Visible: i%3 == 0, OnboardingStep: users.OnboardingSteps + 1}
		perm := s.rnd.Perm(len(users.Topics))
		for _, k := range perm[:3+s.rnd.IntN(3)] {
			prof.Interests = append(prof.Interests, users.Topics[k])
		}
		prof.CaptionLanguage = []string{"sr", "sr", "en", "de"}[s.rnd.IntN(4)]
		prof.Goal = users.Goals[s.rnd.IntN(len(users.Goals))]
		done := s.now
		prof.CompletedAt = &done
		if err := s.users.SaveProfile(ctx, prof); err != nil {
			return err
		}
		if err := s.users.GrantConsent(ctx, uid, users.ConsentGDPR, users.GDPRConsentVersion, s.now); err != nil {
			return err
		}
		s.participants = append(s.participants, participant{uid: uid, email: email, name: name})
	}
	return nil
}

// clear removes what an earlier run created for this event. For devfest only
// the invitations and memberships are removed (the event belongs to the map seed).
func (s *seeder) clear(ctx context.Context, evID string) error {
	fs := s.c.Firestore
	del := func(refs []*firestore.DocumentRef) error {
		for _, r := range refs {
			if _, err := r.Delete(ctx); err != nil {
				return err
			}
		}
		return nil
	}
	invs, err := fs.Collection("invitations").Where("eventId", "==", evID).Documents(ctx).GetAll()
	if err != nil {
		return err
	}
	for _, snap := range invs {
		if uid, _ := snap.Data()["userId"].(string); uid != "" {
			if _, err := fs.Collection("members").Doc(uid).Collection("events").Doc(evID).Delete(ctx); err != nil {
				return err
			}
		}
		if _, err := snap.Ref.Delete(ctx); err != nil {
			return err
		}
	}
	ev := fs.Collection("events").Doc(evID)
	revs, err := ev.Collection("reviews").DocumentRefs(ctx).GetAll()
	if err != nil {
		return err
	}
	if err := del(revs); err != nil {
		return err
	}
	if evID == devfestID {
		return nil
	}
	return del([]*firestore.DocumentRef{ev.Collection("published").Doc("agenda"), ev.Collection("draft").Doc("map"), ev})
}

var talks = []struct {
	title, speaker, tags, stage string
	startMin, durMin            int
	isBreak                     bool
}{
	{"Registracija i kafa", "", "", "Glavna sala", -45, 45, true},
	{"Otvaranje i keynote: Budućnost eventa", "Ana Demić", "ai, eventi", "Glavna sala", 0, 60, false},
	{"Go u produkciji", "Marko Testić", "go, backend", "Sala A", 75, 45, false},
	{"Gemma na ivici mreže", "Jelena Primerić", "ai, gemma", "Glavna sala", 75, 45, false},
	{"Dizajn pristupačnih interfejsa", "Mina Fiktović", "dizajn, ux", "Sala B", 75, 45, false},
	{"Cloud Run bez tajni", "Stefan Lažić", "cloud", "Sala A", 150, 45, false},
	{"Panel: AI i privatnost", "Ivana Fiktić", "ai, privatnost", "Glavna sala", 150, 60, false},
	{"Radionica: od ideje do MVP-a", "Filip Probović", "startup", "Sala B", 150, 90, false},
	{"Zatvaranje i networking", "Olivera Organizović", "networking", "Glavna sala", 300, 45, false},
}

func (s *seeder) seedEvent(ctx context.Context, evID, title, desc, addr string, lat, lng float64, start, end time.Time, days int) error {
	created := s.now.Add(-30 * 24 * time.Hour)
	st, en := start.UTC(), end.UTC()
	ev := events.Event{ID: evID, OwnerUID: s.orgUID, Title: title, Description: desc, Address: addr,
		StartsAt: &st, EndsAt: &en, Lat: &lat, Lng: &lng, PublishedAt: &created, CreatedAt: created, UpdatedAt: created}
	if err := s.events.Create(ctx, ev); err != nil {
		return err
	}
	var a events.Agenda
	for d := 0; d < days; d++ {
		dayStart := time.Date(start.Year(), start.Month(), start.Day()+d, start.Hour(), start.Minute(), 0, 0, s.loc)
		for _, tk := range talks {
			from := dayStart.Add(time.Duration(tk.startMin) * time.Minute)
			to := from.Add(time.Duration(tk.durMin) * time.Minute)
			if from.Before(start) || to.After(end) {
				continue
			}
			title := tk.title
			if days > 1 {
				title = fmt.Sprintf("%s (dan %d)", tk.title, d+1)
			}
			tags, _ := events.ParseTags(tk.tags)
			a.Add(events.Session{Title: title, Stage: tk.stage, Speaker: tk.speaker, Tags: tags,
				StartsAt: from, EndsAt: to}, s.loc)
			if tk.isBreak {
				a.Sessions[len(a.Sessions)-1].IsBreak = true
			}
		}
	}
	a.PublishedAt = created
	return s.events.SaveAgenda(ctx, evID, a)
}

// invite invites participants[from:to]; the first `accepted` accept, the
// next `declined` decline, the rest stay unanswered.
func (s *seeder) invite(ctx context.Context, evID string, from, to, accepted, declined int) error {
	sent := s.now.Add(-20 * 24 * time.Hour)
	for i, p := range s.participants[from:to] {
		inv := invitations.Invitation{EventID: evID, Email: p.email, Token: id.Token(24),
			Status: invitations.StatusSent, ExpiresAt: sent.Add(invitations.TTL), CreatedAt: sent}
		if err := s.invs.Create(ctx, inv); err != nil {
			return err
		}
		inv.ID = invitations.DocID(evID, p.email)
		resp := sent.Add(time.Duration(1+i) * 6 * time.Hour)
		switch {
		case i < accepted:
			if err := s.invs.Respond(ctx, inv, p.uid, invitations.StatusAccepted, resp); err != nil {
				return err
			}
		case i < accepted+declined:
			if err := s.invs.Respond(ctx, inv, p.uid, invitations.StatusDeclined, resp); err != nil {
				return err
			}
		}
	}
	return nil
}

var positive = []string{
	"Odlična organizacija, sve je teklo po satnici.",
	"Keynote je bio inspirativan, a govornici odlično pripremljeni.",
	"Sjajna atmosfera i odlični govornici. Networking je bio koristan.",
	"Titlovi uživo su mi mnogo pomogli, odlična organizacija!",
	"Radionica je bila praktična i korisna, sledeće godine opet dolazim.",
}

var negative = []string{
	"Sala je bila pretrpana, a ozvučenje loše.",
	"Panel je trajao predugo i bio je dosadan, ozvučenje loše.",
	"Kašnjenje na početku i premalo hrane za pauzu.",
}

var neutral = []string{
	"Solidno, ali neka predavanja su bila previše uvodna.",
	"",
}

func (s *seeder) seedReviews(ctx context.Context, evID string, n int) error {
	a, err := s.events.GetAgenda(ctx, evID)
	if err != nil {
		return err
	}
	ev, err := s.events.Get(ctx, evID)
	if err != nil {
		return err
	}
	var sessions []events.Session
	for _, se := range a.SessionList(s.loc) {
		if !se.IsBreak {
			sessions = append(sessions, se)
		}
	}
	ratings := []int{5, 4, 5, 4, 2, 5, 4, 3, 5, 4, 1, 4, 5}
	for i := 0; i < n && i < len(ratings); i++ {
		p := s.participants[i]
		r := ratings[i]
		var comment string
		switch {
		case r >= 4:
			comment = positive[s.rnd.IntN(len(positive))]
		case r <= 2:
			comment = negative[s.rnd.IntN(len(negative))]
		default:
			comment = neutral[s.rnd.IntN(len(neutral))]
		}
		sr := map[string]int{}
		for _, se := range sessions {
			if s.rnd.IntN(3) == 0 {
				continue
			}
			base := r
			switch {
			case se.Title == "Panel: AI i privatnost": // the weak spot in the demo data
				base = 2
			case se.Title == "Otvaranje i keynote: Budućnost eventa" && base < 5:
				base++
			}
			sr[se.ID] = min(5, max(1, base+s.rnd.IntN(3)-1))
		}
		at := ev.EndsAt.Add(time.Duration(2+i) * time.Hour)
		if err := s.reviews.Save(ctx, reviews.WithAuthor{
			Review: reviews.Review{ID: p.uid, EventID: evID, UserID: p.uid, Rating: r, Comment: comment,
				Anonymous: i%4 == 1, SessionRatings: sr, CreatedAt: at, UpdatedAt: at},
			AuthorName: p.name, AuthorEmail: p.email,
		}); err != nil {
			return err
		}
	}
	return nil
}
