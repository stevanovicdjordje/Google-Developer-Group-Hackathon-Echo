package users

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Firestore layout (Admin SDK only; the project rules deny clients):
//
//	organizers/{uid}     name, website, createdAt
//	participants/{uid}   onboarding profile + consents
type FirestoreRepo struct{ c *firestore.Client }

func NewFirestoreRepo(c *firestore.Client) *FirestoreRepo { return &FirestoreRepo{c: c} }

func isNotFound(err error) bool { return status.Code(err) == codes.NotFound }

type orgDoc struct {
	Name      string    `firestore:"name"`
	Website   string    `firestore:"website"`
	CreatedAt time.Time `firestore:"createdAt"`
}

func (r *FirestoreRepo) SaveOrganization(ctx context.Context, o Organization) error {
	_, err := r.c.Collection("organizers").Doc(o.OwnerUID).Set(ctx, orgDoc{Name: o.Name, Website: o.Website, CreatedAt: o.CreatedAt})
	return err
}

func (r *FirestoreRepo) GetOrganization(ctx context.Context, ownerUID string) (Organization, error) {
	snap, err := r.c.Collection("organizers").Doc(ownerUID).Get(ctx)
	if isNotFound(err) {
		return Organization{}, ErrNotFound
	}
	if err != nil {
		return Organization{}, err
	}
	var d orgDoc
	if err := snap.DataTo(&d); err != nil {
		return Organization{}, err
	}
	return Organization{OwnerUID: ownerUID, Name: d.Name, Website: d.Website, CreatedAt: d.CreatedAt}, nil
}

type consentDoc struct {
	Kind      string    `firestore:"kind"`
	Version   string    `firestore:"version"`
	GrantedAt time.Time `firestore:"grantedAt"`
}

// profileDoc keeps interests, goal and the visibility opt-in as structured
// fields, ready for AI matching of opted-in participants.
type profileDoc struct {
	CaptionLanguage       string       `firestore:"captionLanguage"`
	Interests             []string     `firestore:"interests"`
	CustomInterests       []string     `firestore:"customInterests"`
	Goal                  string       `firestore:"goal"`
	Visible               bool         `firestore:"visible"`
	OnboardingStep        int          `firestore:"onboardingStep"`
	OnboardingCompletedAt *time.Time   `firestore:"onboardingCompletedAt"`
	Consents              []consentDoc `firestore:"consents"`
	UpdatedAt             time.Time    `firestore:"updatedAt"`
}

func (r *FirestoreRepo) profile(uid string) *firestore.DocumentRef {
	return r.c.Collection("participants").Doc(uid)
}

func (r *FirestoreRepo) CreateProfile(ctx context.Context, uid string, now time.Time) error {
	_, err := r.profile(uid).Create(ctx, profileDoc{OnboardingStep: 1, Interests: []string{}, CustomInterests: []string{},
		Consents: []consentDoc{}, UpdatedAt: now})
	if status.Code(err) == codes.AlreadyExists {
		return nil
	}
	return err
}

func (r *FirestoreRepo) GetProfile(ctx context.Context, uid string) (Profile, error) {
	snap, err := r.profile(uid).Get(ctx)
	if isNotFound(err) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, err
	}
	var d profileDoc
	if err := snap.DataTo(&d); err != nil {
		return Profile{}, fmt.Errorf("decode profile: %w", err)
	}
	return Profile{UserID: uid, CaptionLanguage: d.CaptionLanguage, Interests: d.Interests,
		CustomInterests: d.CustomInterests, Goal: Goal(d.Goal), Visible: d.Visible,
		OnboardingStep: d.OnboardingStep, CompletedAt: d.OnboardingCompletedAt}, nil
}

func (r *FirestoreRepo) SaveProfile(ctx context.Context, p Profile) error {
	interests, custom := p.Interests, p.CustomInterests
	if interests == nil {
		interests = []string{}
	}
	if custom == nil {
		custom = []string{}
	}
	_, err := r.profile(p.UserID).Update(ctx, []firestore.Update{
		{Path: "captionLanguage", Value: p.CaptionLanguage},
		{Path: "interests", Value: interests},
		{Path: "customInterests", Value: custom},
		{Path: "goal", Value: string(p.Goal)},
		{Path: "visible", Value: p.Visible},
		{Path: "onboardingStep", Value: p.OnboardingStep},
		{Path: "onboardingCompletedAt", Value: p.CompletedAt},
		{Path: "updatedAt", Value: time.Now().UTC()},
	})
	if isNotFound(err) {
		return ErrNotFound
	}
	return err
}

func (r *FirestoreRepo) GrantConsent(ctx context.Context, uid, kind, version string, at time.Time) error {
	_, err := r.profile(uid).Update(ctx, []firestore.Update{
		{Path: "consents", Value: firestore.ArrayUnion(map[string]any{"kind": kind, "version": version, "grantedAt": at})},
	})
	if isNotFound(err) {
		return ErrNotFound
	}
	return err
}
