// Command seed fills the database with clearly fake demo data: one organizer,
// 20 participants and three events (finished with reviews, ongoing, upcoming),
// each with a generated floor plan, zones, a schedule and invitations.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"log"
	"math/rand/v2"
	"os"
	"path/filepath"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/auth"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/db"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

const (
	orgEmail     = "organizator@eho.demo"
	demoPassword = "demo-lozinka"
)

var names = []string{
	"Ana Demić", "Marko Testić", "Jelena Primerić", "Nikola Probić", "Milica Uzorić",
	"Stefan Lažić", "Ivana Fiktić", "Luka Izmišljenić", "Teodora Demović", "Vuk Primerović",
	"Sara Testović", "Filip Probović", "Katarina Uzorović", "Petar Lažović", "Mina Fiktović",
	"Đorđe Demski", "Nina Testska", "Aleksa Primerski", "Jovana Probska", "Uroš Uzorski",
}

func main() {
	reset := flag.Bool("reset", false, "delete the database and uploaded plans before seeding")
	flag.Parse()
	cfg := config.Load()
	if *reset {
		for _, p := range []string{cfg.DBPath, cfg.DBPath + "-wal", cfg.DBPath + "-shm"} {
			if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
				log.Fatal(err)
			}
		}
		_ = os.RemoveAll(filepath.Join(cfg.UploadDir, "venue"))
	}
	ctx := context.Background()
	conn, err := db.Open(ctx, cfg.DBPath)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	s := &seeder{
		users:   users.NewSQLiteRepo(conn),
		events:  events.NewSQLiteRepo(conn),
		invs:    invitations.NewSQLiteRepo(conn),
		reviews: reviews.NewSQLiteRepo(conn),
		cfg:     cfg,
		loc:     app.Location(cfg),
		rnd:     rand.New(rand.NewPCG(2026, 10)),
		now:     time.Now().UTC(),
	}
	if _, err := s.users.GetByEmail(orgEmail); err == nil {
		log.Fatalf("demo data already present in %s (run with -reset to recreate it)", cfg.DBPath)
	}
	authSvc := auth.NewService(s.users, conn)
	if err := s.run(authSvc); err != nil {
		log.Fatal(err)
	}
	fmt.Printf(`Demo data created in %s

  Organizer:    %s / %s
  Participants: ucesnik01@eho.demo … ucesnik20@eho.demo / %s

Start the server and open %s
`, cfg.DBPath, orgEmail, demoPassword, demoPassword, cfg.BaseURL)
}

type seeder struct {
	users   *users.SQLiteRepo
	events  *events.SQLiteRepo
	invs    *invitations.SQLiteRepo
	reviews *reviews.SQLiteRepo
	cfg     config.Config
	loc     *time.Location
	rnd     *rand.Rand
	now     time.Time

	orgID        string
	participants []users.User
}

func (s *seeder) run(authSvc *auth.Service) error {
	org, err := authSvc.RegisterOrganizer(auth.OrganizerInput{
		FullName: "Olivera Organizović", Email: orgEmail, Password: demoPassword, PasswordConfirm: demoPassword,
		OrgName: "Eho Demo Konferencije", Website: "eho.demo",
	})
	if err != nil {
		return err
	}
	o, err := s.users.GetOrganizationByOwner(org.ID)
	if err != nil {
		return err
	}
	s.orgID = o.ID

	if err := s.seedParticipants(authSvc); err != nil {
		return err
	}

	// Event times are local wall-clock times in EHO_TIMEZONE.
	today := time.Date(s.now.In(s.loc).Year(), s.now.In(s.loc).Month(), s.now.In(s.loc).Day(), 0, 0, 0, 0, s.loc)

	finished, err := s.seedEvent("Eho Dev Summit 2026",
		"Godišnja konferencija o razvoju softvera: veb, cloud i veštačka inteligencija.",
		"Bulevar Mihajla Pupina 10, Beograd", 44.8176, 20.4569,
		today.AddDate(0, 0, -10).Add(9*time.Hour), today.AddDate(0, 0, -10).Add(18*time.Hour), 1)
	if err != nil {
		return err
	}
	if err := s.invite(finished, 0, 20, 16, 3); err != nil {
		return err
	}
	if err := s.seedReviews(finished, 13); err != nil {
		return err
	}

	start := s.now.Add(-2 * time.Hour).Truncate(time.Hour)
	ongoing, err := s.seedEvent("AI meetup Beograd",
		"Veče kratkih predavanja o primeni velikih jezičkih modela u praksi.",
		"Kneza Mihaila 5, Beograd", 44.8170, 20.4573,
		start, start.Add(8*time.Hour), 1)
	if err != nil {
		return err
	}
	if err := s.invite(ongoing, 0, 14, 11, 1); err != nil {
		return err
	}

	upcoming, err := s.seedEvent("Startap vikend Novi Sad",
		"Dva dana radionica, mentorstva i pitchinga za mlade timove.",
		"Bulevar oslobođenja 30, Novi Sad", 45.2551, 19.8450,
		today.AddDate(0, 0, 14).Add(10*time.Hour), today.AddDate(0, 0, 15).Add(18*time.Hour), 2)
	if err != nil {
		return err
	}
	return s.invite(upcoming, 0, 12, 6, 1)
}

func (s *seeder) seedParticipants(authSvc *auth.Service) error {
	for i, name := range names {
		email := fmt.Sprintf("ucesnik%02d@eho.demo", i+1)
		u, err := authSvc.RegisterParticipant(auth.ParticipantInput{
			FullName: name, Email: email, Password: demoPassword, PasswordConfirm: demoPassword,
		})
		if err != nil {
			return fmt.Errorf("participant %s: %w", email, err)
		}
		prof, err := s.users.GetProfile(u.ID)
		if err != nil {
			return err
		}
		perm := s.rnd.Perm(len(users.Topics))
		for _, k := range perm[:3+s.rnd.IntN(3)] {
			prof.Interests = append(prof.Interests, users.Topics[k])
		}
		prof.CaptionLanguage = []string{"sr", "sr", "en", "de"}[s.rnd.IntN(4)]
		prof.Goal = users.Goals[s.rnd.IntN(len(users.Goals))]
		prof.Visible = i%3 == 0
		done := s.now
		prof.CompletedAt, prof.OnboardingStep = &done, users.OnboardingSteps+1
		if err := s.users.SaveProfile(prof); err != nil {
			return err
		}
		if err := s.users.GrantConsent(u.ID, users.ConsentGDPR, users.GDPRConsentVersion); err != nil {
			return err
		}
		s.participants = append(s.participants, u)
	}
	return nil
}

type zoneSpec struct {
	name       string
	kind       events.ZoneKind
	x, y, w, h float64
}

var layout = []zoneSpec{
	{"Velika sala", "hall", 4, 6, 38, 42},
	{"Sala Tesla", "hall", 46, 6, 24, 30},
	{"Sala Pupin", "hall", 73, 6, 23, 30},
	{"Štand Cloud", "booth", 46, 44, 12, 12},
	{"Štand AI", "booth", 61, 44, 12, 12},
	{"Štand Startapi", "booth", 76, 44, 12, 12},
	{"Kafe i ručak", "food", 4, 56, 30, 22},
	{"Info pult", "info", 40, 64, 16, 12},
	{"Toaleti", "toilet", 80, 64, 16, 14},
	{"Glavni ulaz", "entrance", 40, 86, 20, 10},
}

var talks = []struct {
	title, speaker, tags string
	hall                 int // index into the three halls
	startMin, durMin     int // offset from the day's start
}{
	{"Otvaranje i keynote: Budućnost eventa", "Ana Demić", "ai, eventi", 0, 0, 60},
	{"Go u produkciji", "Marko Testić", "go, backend", 1, 75, 45},
	{"Gemma na ivici mreže", "Jelena Primerić", "ai, gemma", 0, 75, 45},
	{"Dizajn pristupačnih interfejsa", "Mina Fiktović", "dizajn, ux", 2, 75, 45},
	{"Cloud Run bez tajni", "Stefan Lažić", "cloud", 1, 150, 45},
	{"Panel: AI i privatnost", "Ivana Fiktić", "ai, privatnost", 0, 150, 60},
	{"Radionica: od ideje do MVP-a", "Filip Probović", "startup", 2, 150, 90},
	{"Zatvaranje i networking", "Olivera Organizović", "networking", 0, 300, 45},
}

func (s *seeder) seedEvent(title, desc, addr string, lat, lng float64, start, end time.Time, days int) (events.Event, error) {
	pub := s.now.Add(-30 * 24 * time.Hour)
	st, en := start.UTC(), end.UTC()
	ev := events.Event{ID: id.New(), OrganizationID: s.orgID, Title: title, Description: desc,
		StartsAt: &st, EndsAt: &en, Address: addr, Lat: &lat, Lng: &lng, PublishedAt: &pub,
		CreatedAt: pub, UpdatedAt: pub}
	if err := s.events.Create(ev); err != nil {
		return ev, err
	}
	var halls []events.Zone
	for _, z := range layout {
		zone := events.Zone{ID: id.New(), EventID: ev.ID, Name: z.name, Kind: z.kind, X: z.x, Y: z.y, W: z.w, H: z.h, Created: pub}
		if err := s.events.CreateZone(zone); err != nil {
			return ev, err
		}
		if z.kind == events.ZoneHall {
			halls = append(halls, zone)
		}
		pub = pub.Add(time.Second) // keep a stable display order
	}
	if err := s.writePlan(ev.ID); err != nil {
		return ev, err
	}
	for d := 0; d < days; d++ {
		dayStart := start.AddDate(0, 0, d)
		for _, tk := range talks {
			from := dayStart.Add(time.Duration(tk.startMin) * time.Minute)
			to := from.Add(time.Duration(tk.durMin) * time.Minute)
			if to.After(end) {
				continue
			}
			tags, _ := events.ParseTags(tk.tags)
			title := tk.title
			if days > 1 {
				title = fmt.Sprintf("%s (dan %d)", tk.title, d+1)
			}
			if err := s.events.CreateSession(events.Session{ID: id.New(), EventID: ev.ID, ZoneID: halls[tk.hall].ID,
				Title: title, Speaker: tk.speaker, StartsAt: from.UTC(), EndsAt: to.UTC(), Tags: tags}); err != nil {
				return ev, err
			}
		}
	}
	return ev, nil
}

// writePlan draws a simple floor plan (walls and rooms) as a PNG.
func (s *seeder) writePlan(eventID string) error {
	const w, h = 1200, 800
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{250, 250, 247, 255}}, image.Point{}, draw.Src)
	wall := color.RGBA{70, 78, 92, 255}
	room := color.RGBA{232, 234, 238, 255}
	rect := func(x0, y0, x1, y1 int, c color.Color) {
		draw.Draw(img, image.Rect(x0, y0, x1, y1), &image.Uniform{c}, image.Point{}, draw.Src)
	}
	outline := func(x0, y0, x1, y1, t int) {
		rect(x0, y0, x1, y0+t, wall)
		rect(x0, y1-t, x1, y1, wall)
		rect(x0, y0, x0+t, y1, wall)
		rect(x1-t, y0, x1, y1, wall)
	}
	outline(10, 10, w-10, h-10, 8)
	for _, z := range layout {
		x0, y0 := int(z.x/100*w), int(z.y/100*h)
		x1, y1 := int((z.x+z.w)/100*w), int((z.y+z.h)/100*h)
		rect(x0, y0, x1, y1, room)
		outline(x0, y0, x1, y1, 3)
	}
	// Door gap at the main entrance.
	rect(int(0.42*w), h-18, int(0.58*w), h-10, color.RGBA{250, 250, 247, 255})

	dir := filepath.Join(s.cfg.UploadDir, "venue")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	name := eventID + "-seed.png"
	f, err := os.Create(filepath.Join(dir, name))
	if err != nil {
		return err
	}
	if err := png.Encode(f, img); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return s.events.SaveVenueMap(events.VenueMap{EventID: eventID, FileName: name, ContentType: "image/png",
		Width: w, Height: h, UploadedAt: s.now})
}

// invite invites participants[from:to]; the first `accepted` accept, the
// next `declined` decline, the rest stay unanswered.
func (s *seeder) invite(ev events.Event, from, to, accepted, declined int) error {
	sent := ev.StartsAt.Add(-21 * 24 * time.Hour)
	for i, u := range s.participants[from:to] {
		inv := invitations.Invitation{ID: id.New(), EventID: ev.ID, Email: u.Email, Token: id.Token(24),
			Status: invitations.StatusSent, ExpiresAt: sent.Add(invitations.TTL), CreatedAt: sent}
		if err := s.invs.Create(inv); err != nil {
			return err
		}
		resp := sent.Add(time.Duration(1+i) * 6 * time.Hour)
		switch {
		case i < accepted:
			err := s.invs.Respond(inv.ID, u.ID, invitations.StatusAccepted, resp)
			if err != nil {
				return err
			}
		case i < accepted+declined:
			if err := s.invs.Respond(inv.ID, u.ID, invitations.StatusDeclined, resp); err != nil {
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

func (s *seeder) seedReviews(ev events.Event, n int) error {
	sessions, err := s.events.ListSessions(ev.ID)
	if err != nil {
		return err
	}
	ratings := []int{5, 4, 5, 4, 2, 5, 4, 3, 5, 4, 1, 4, 5}
	for i := 0; i < n && i < len(ratings); i++ {
		u := s.participants[i]
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
		for j, sess := range sessions {
			if s.rnd.IntN(3) == 0 {
				continue
			}
			base := r
			if j == 5 { // the panel is the weak spot in the demo data
				base = 2
			} else if j == 0 && base < 5 {
				base++
			}
			v := base + s.rnd.IntN(3) - 1
			sr[sess.ID] = min(5, max(1, v))
		}
		at := ev.EndsAt.Add(time.Duration(2+i) * time.Hour)
		if err := s.reviews.Save(reviews.Review{ID: id.New(), EventID: ev.ID, UserID: u.ID, Rating: r,
			Comment: comment, Anonymous: i%4 == 1, SessionRatings: sr, CreatedAt: at, UpdatedAt: at}); err != nil {
			return err
		}
	}
	return nil
}
