package invitations

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// FirestoreRepo layout (Admin SDK only; the project rules deny clients):
//
//	invitations/{eventId}_{sha256(email)[:20]}   eventId, email, token, status, userId,
//	                                             expiresAt, createdAt, respondedAt
//	members/{uid}/events/{eventId}               joinedAt (shared with backend/events: "My events")
//
// The document ID makes "one invitation per email per event" atomic.
type FirestoreRepo struct{ c *firestore.Client }

func NewFirestoreRepo(c *firestore.Client) *FirestoreRepo { return &FirestoreRepo{c: c} }

type invDoc struct {
	EventID     string     `firestore:"eventId"`
	Email       string     `firestore:"email"`
	Token       string     `firestore:"token"`
	Status      string     `firestore:"status"`
	UserID      string     `firestore:"userId"`
	ExpiresAt   time.Time  `firestore:"expiresAt"`
	CreatedAt   time.Time  `firestore:"createdAt"`
	RespondedAt *time.Time `firestore:"respondedAt"`
}

func DocID(eventID, email string) string {
	sum := sha256.Sum256([]byte(email))
	return eventID + "_" + hex.EncodeToString(sum[:])[:20]
}

func (r *FirestoreRepo) col() *firestore.CollectionRef { return r.c.Collection("invitations") }

func fromDoc(snap *firestore.DocumentSnapshot) (Invitation, error) {
	var d invDoc
	if err := snap.DataTo(&d); err != nil {
		return Invitation{}, fmt.Errorf("decode invitation %s: %w", snap.Ref.ID, err)
	}
	return Invitation{ID: snap.Ref.ID, EventID: d.EventID, Email: d.Email, Token: d.Token, Status: Status(d.Status),
		UserID: d.UserID, ExpiresAt: d.ExpiresAt, CreatedAt: d.CreatedAt, RespondedAt: d.RespondedAt}, nil
}

func (r *FirestoreRepo) query(ctx context.Context, q firestore.Query) ([]Invitation, error) {
	snaps, err := q.Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	out := make([]Invitation, 0, len(snaps))
	for _, s := range snaps {
		inv, err := fromDoc(s)
		if err != nil {
			return nil, err
		}
		out = append(out, inv)
	}
	return out, nil
}

func (r *FirestoreRepo) Create(ctx context.Context, inv Invitation) error {
	_, err := r.col().Doc(DocID(inv.EventID, inv.Email)).Create(ctx, invDoc{EventID: inv.EventID, Email: inv.Email,
		Token: inv.Token, Status: string(inv.Status), UserID: inv.UserID, ExpiresAt: inv.ExpiresAt, CreatedAt: inv.CreatedAt})
	if status.Code(err) == codes.AlreadyExists {
		return ErrDuplicate
	}
	return err
}

func (r *FirestoreRepo) ListByEvent(ctx context.Context, eventID string) ([]Invitation, error) {
	return r.query(ctx, r.col().Where("eventId", "==", eventID))
}

func (r *FirestoreRepo) GetByToken(ctx context.Context, token string) (Invitation, error) {
	list, err := r.query(ctx, r.col().Where("token", "==", token).Limit(1))
	if err != nil {
		return Invitation{}, err
	}
	if len(list) == 0 {
		return Invitation{}, ErrNotFound
	}
	return list[0], nil
}

func (r *FirestoreRepo) Respond(ctx context.Context, inv Invitation, userID string, st Status, at time.Time) error {
	ups := []firestore.Update{{Path: "status", Value: string(st)}, {Path: "respondedAt", Value: at}}
	member := inv.UserID
	if userID != "" {
		ups = append(ups, firestore.Update{Path: "userId", Value: userID})
		member = userID
	}
	batch := r.c.Batch()
	batch.Update(r.col().Doc(inv.ID), ups)
	if member != "" {
		ref := r.c.Collection("members").Doc(member).Collection("events").Doc(inv.EventID)
		if st == StatusAccepted {
			batch.Set(ref, map[string]any{"joinedAt": at})
		} else {
			batch.Delete(ref)
		}
	}
	_, err := batch.Commit(ctx)
	return err
}

func (r *FirestoreRepo) HasAccepted(ctx context.Context, eventID, userID string) (bool, error) {
	list, err := r.query(ctx, r.col().Where("eventId", "==", eventID).Where("userId", "==", userID).
		Where("status", "==", string(StatusAccepted)).Limit(1))
	return len(list) > 0, err
}

func (r *FirestoreRepo) ListForParticipant(ctx context.Context, userID, email string) ([]Invitation, error) {
	bound, err := r.query(ctx, r.col().Where("userId", "==", userID))
	if err != nil {
		return nil, err
	}
	open, err := r.query(ctx, r.col().Where("email", "==", email).Where("userId", "==", ""))
	if err != nil {
		return nil, err
	}
	return append(bound, open...), nil
}
