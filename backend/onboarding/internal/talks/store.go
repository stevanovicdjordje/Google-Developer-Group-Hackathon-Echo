package talks

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// FirestoreRepo stores purchases as purchases/{uid}_{eventId}_{sessionId}
// (Admin SDK only; the project rules deny clients).
type FirestoreRepo struct{ c *firestore.Client }

func NewFirestoreRepo(c *firestore.Client) *FirestoreRepo { return &FirestoreRepo{c: c} }

type purchaseDoc struct {
	UserID      string    `firestore:"userId"`
	EventID     string    `firestore:"eventId"`
	SessionID   string    `firestore:"sessionId"`
	AmountCents int       `firestore:"amountCents"`
	Currency    string    `firestore:"currency"`
	CardBrand   string    `firestore:"cardBrand"`
	CardLast4   string    `firestore:"cardLast4"`
	PaymentID   string    `firestore:"paymentId"`
	Mode        string    `firestore:"mode"`
	CreatedAt   time.Time `firestore:"createdAt"`
}

func toPurchase(docID string, d purchaseDoc) Purchase {
	return Purchase{ID: docID, UserID: d.UserID, EventID: d.EventID, SessionID: d.SessionID,
		AmountCents: d.AmountCents, Currency: d.Currency, CardBrand: d.CardBrand, CardLast4: d.CardLast4,
		PaymentID: d.PaymentID, Mode: d.Mode, CreatedAt: d.CreatedAt}
}

func (r *FirestoreRepo) Get(ctx context.Context, uid, eventID, sessionID string) (Purchase, error) {
	snap, err := r.c.Collection("purchases").Doc(PurchaseID(uid, eventID, sessionID)).Get(ctx)
	if status.Code(err) == codes.NotFound {
		return Purchase{}, ErrNotFound
	}
	if err != nil {
		return Purchase{}, err
	}
	var d purchaseDoc
	if err := snap.DataTo(&d); err != nil {
		return Purchase{}, fmt.Errorf("decode purchase: %w", err)
	}
	return toPurchase(snap.Ref.ID, d), nil
}

func (r *FirestoreRepo) Create(ctx context.Context, p Purchase) error {
	_, err := r.c.Collection("purchases").Doc(PurchaseID(p.UserID, p.EventID, p.SessionID)).Create(ctx, purchaseDoc{
		UserID: p.UserID, EventID: p.EventID, SessionID: p.SessionID, AmountCents: p.AmountCents, Currency: p.Currency,
		CardBrand: p.CardBrand, CardLast4: p.CardLast4, PaymentID: p.PaymentID, Mode: p.Mode, CreatedAt: p.CreatedAt})
	if status.Code(err) == codes.AlreadyExists {
		return ErrDuplicate
	}
	return err
}

func (r *FirestoreRepo) ListByUser(ctx context.Context, uid string) ([]Purchase, error) {
	snaps, err := r.c.Collection("purchases").Where("userId", "==", uid).Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	var out []Purchase
	for _, s := range snaps {
		var d purchaseDoc
		if err := s.DataTo(&d); err != nil {
			return nil, fmt.Errorf("decode purchase: %w", err)
		}
		out = append(out, toPurchase(s.Ref.ID, d))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

// MemRepo is an in-memory Repository for tests.
type MemRepo struct {
	mu   sync.Mutex
	byID map[string]Purchase
}

func NewMemRepo() *MemRepo { return &MemRepo{byID: map[string]Purchase{}} }

func (m *MemRepo) Get(_ context.Context, uid, eventID, sessionID string) (Purchase, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.byID[PurchaseID(uid, eventID, sessionID)]
	if !ok {
		return Purchase{}, ErrNotFound
	}
	return p, nil
}

func (m *MemRepo) Create(_ context.Context, p Purchase) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	k := PurchaseID(p.UserID, p.EventID, p.SessionID)
	if _, ok := m.byID[k]; ok {
		return ErrDuplicate
	}
	p.ID = k
	m.byID[k] = p
	return nil
}

func (m *MemRepo) ListByUser(_ context.Context, uid string) ([]Purchase, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Purchase
	for _, p := range m.byID {
		if p.UserID == uid {
			out = append(out, p)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

// OnlyUser returns the user of the first purchase (tests).
func (m *MemRepo) OnlyUser() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, p := range m.byID {
		return p.UserID
	}
	return ""
}
