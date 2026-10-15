// Package planimage inspects uploaded floor-plan images in Cloud Storage.
package planimage

import (
	"context"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg" // register decoders for DecodeConfig
	_ "image/png"

	"cloud.google.com/go/storage"
)

// MaxBytes is the largest accepted floor-plan image (matches storage.rules).
const MaxBytes = 10 << 20

// Errors returned by Inspector.
var (
	ErrNotFound    = errors.New("image not found")
	ErrUnsupported = errors.New("image must be a PNG or JPEG of at most 10 MB")
)

// Inspector reports the pixel dimensions of a stored image.
type Inspector interface {
	Dimensions(ctx context.Context, path string) (width, height int, err error)
}

// GCSInspector reads images from a Cloud Storage bucket. It honors
// STORAGE_EMULATOR_HOST.
type GCSInspector struct {
	Bucket *storage.BucketHandle
}

// Dimensions implements Inspector. Only the image header is read.
func (g GCSInspector) Dimensions(ctx context.Context, path string) (int, int, error) {
	obj := g.Bucket.Object(path)
	attrs, err := obj.Attrs(ctx)
	if errors.Is(err, storage.ErrObjectNotExist) {
		return 0, 0, ErrNotFound
	}
	if err != nil {
		return 0, 0, fmt.Errorf("stat %s: %w", path, err)
	}
	if attrs.Size > MaxBytes || (attrs.ContentType != "image/png" && attrs.ContentType != "image/jpeg") {
		return 0, 0, ErrUnsupported
	}
	r, err := obj.NewReader(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("open %s: %w", path, err)
	}
	defer r.Close()
	cfg, format, err := image.DecodeConfig(r)
	if err != nil || (format != "png" && format != "jpeg") {
		return 0, 0, ErrUnsupported
	}
	return cfg.Width, cfg.Height, nil
}
