package reviews

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// FirestoreRepo stores reviews as events/{eventId}/reviews/{uid}: the
// document ID enforces one review per participant per event. Session ratings
// are keyed by the agenda session ID. Admin SDK only; clients can't read them.
type FirestoreRepo struct{ c *firestore.Client }

func NewFirestoreRepo(c *firestore.Client) *FirestoreRepo { return &FirestoreRepo{c: c} }

type reviewDoc struct {
	Rating         int            `firestore:"rating"`
	Comment        string         `firestore:"comment"`
	Anonymous      bool           `firestore:"anonymous"`
	SessionRatings map[string]int `firestore:"sessionRatings"`
	AuthorName     string         `firestore:"authorName"`
	AuthorEmail    string         `firestore:"authorEmail"`
	CreatedAt      time.Time      `firestore:"createdAt"`
	UpdatedAt      time.Time      `firestore:"updatedAt"`
}

func (r *FirestoreRepo) col(eventID string) *firestore.CollectionRef {
	return r.c.Collection("events").Doc(eventID).Collection("reviews")
}

func decode(eventID string, snap *firestore.DocumentSnapshot) (WithAuthor, error) {
	var d reviewDoc
	if err := snap.DataTo(&d); err != nil {
		return WithAuthor{}, fmt.Errorf("decode review %s: %w", snap.Ref.Path, err)
	}
	if d.SessionRatings == nil {
		d.SessionRatings = map[string]int{}
	}
	return WithAuthor{
		Review: Review{ID: snap.Ref.ID, EventID: eventID, UserID: snap.Ref.ID, Rating: d.Rating, Comment: d.Comment,
			Anonymous: d.Anonymous, SessionRatings: d.SessionRatings, CreatedAt: d.CreatedAt, UpdatedAt: d.UpdatedAt},
		AuthorName: d.AuthorName, AuthorEmail: d.AuthorEmail,
	}, nil
}

func (r *FirestoreRepo) Get(ctx context.Context, eventID, userID string) (Review, error) {
	snap, err := r.col(eventID).Doc(userID).Get(ctx)
	if status.Code(err) == codes.NotFound {
		return Review{}, ErrNotFound
	}
	if err != nil {
		return Review{}, err
	}
	w, err := decode(eventID, snap)
	return w.Review, err
}

func (r *FirestoreRepo) Save(ctx context.Context, w WithAuthor) error {
	ref := r.col(w.EventID).Doc(w.UserID)
	return r.c.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		created := w.CreatedAt
		snap, err := tx.Get(ref)
		if err == nil {
			if t, ok := snap.Data()["createdAt"].(time.Time); ok {
				created = t
			}
		} else if status.Code(err) != codes.NotFound {
			return err
		}
		ratings := w.SessionRatings
		if ratings == nil {
			ratings = map[string]int{}
		}
		return tx.Set(ref, reviewDoc{Rating: w.Rating, Comment: w.Comment, Anonymous: w.Anonymous,
			SessionRatings: ratings, AuthorName: w.AuthorName, AuthorEmail: w.AuthorEmail,
			CreatedAt: created, UpdatedAt: w.UpdatedAt})
	})
}

func (r *FirestoreRepo) ListByEvent(ctx context.Context, eventID string) ([]WithAuthor, error) {
	snaps, err := r.col(eventID).Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	out := make([]WithAuthor, 0, len(snaps))
	for _, s := range snaps {
		w, err := decode(eventID, s)
		if err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, nil
}
