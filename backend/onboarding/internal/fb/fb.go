// Package fb creates the Firebase clients (Auth, Firestore, Storage) shared
// with the rest of the Eho backend. Locally they talk to the Firebase
// emulators started by backend/maps (project demo-eho).
package fb

import (
	"context"
	"fmt"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	firebase "firebase.google.com/go/v4"
	fbauth "firebase.google.com/go/v4/auth"

	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
)

type Clients struct {
	Auth      *fbauth.Client
	Firestore *firestore.Client
	Bucket    *storage.BucketHandle
	storage   *storage.Client
}

func New(ctx context.Context, cfg config.Config) (*Clients, error) {
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: cfg.ProjectID})
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase auth: %w", err)
	}
	fs, err := firestore.NewClient(ctx, cfg.ProjectID)
	if err != nil {
		return nil, fmt.Errorf("firestore: %w", err)
	}
	st, err := storage.NewClient(ctx)
	if err != nil {
		fs.Close()
		return nil, fmt.Errorf("storage: %w", err)
	}
	return &Clients{Auth: authClient, Firestore: fs, Bucket: st.Bucket(cfg.StorageBucket), storage: st}, nil
}

func (c *Clients) Close() {
	c.Firestore.Close()
	c.storage.Close()
}
