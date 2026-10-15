package extract

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

// ErrAIUnavailable means the files need a model and there is none, or the
// model failed and nothing else could read the files.
var ErrAIUnavailable = errors.New("ai unavailable")

// ErrNothing means no sessions were found in the files.
var ErrNothing = errors.New("nothing extracted")

// Result is a sanitised draft and the model that produced it.
type Result struct {
	Fields agenda.Fields
	Model  string
}

// Extractor turns files into a draft.
type Extractor struct {
	// Model is the AI on the Gemini API; nil = tables only.
	Model *Gemini
	Log   *slog.Logger
	// Now gives "today" for the model's date hints (default time.Now).
	Now func() time.Time
}

// ModelName is the configured model, or "offline".
func (e *Extractor) ModelName() string {
	if e.Model == nil {
		return OfflineModel
	}
	return e.Model.ModelName
}

// Extract uses the model when there is one, and falls back to reading
// spreadsheets/CSV tables when the model is missing or fails.
func (e *Extractor) Extract(ctx context.Context, files []File) (Result, error) {
	now := time.Now
	if e.Now != nil {
		now = e.Now
	}
	var tables []Table
	for _, f := range files {
		t, err := Tables(f)
		if err != nil {
			continue // unreadable table: the model may still read the file
		}
		tables = append(tables, t...)
	}

	if e.Model != nil {
		f, err := e.Model.Extract(ctx, files, now())
		if err == nil {
			agenda.Sanitize(&f)
			if len(f.Sessions) > 0 {
				return Result{Fields: f, Model: e.Model.ModelName}, nil
			}
			err = ErrNothing
		}
		if ctx.Err() != nil && !errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return Result{}, ctx.Err()
		}
		if e.Log != nil {
			// Error class only: never file content.
			e.Log.WarnContext(ctx, "ai extraction failed", "class", errorClass(err))
		}
		if f, ok := FromTables(tables, now().Year()); ok {
			agenda.Sanitize(&f)
			return Result{Fields: f, Model: OfflineModel}, nil
		}
		if errors.Is(err, ErrNothing) {
			return Result{}, ErrNothing
		}
		return Result{}, ErrAIUnavailable
	}

	if f, ok := FromTables(tables, now().Year()); ok {
		agenda.Sanitize(&f)
		if len(f.Sessions) > 0 {
			return Result{Fields: f, Model: OfflineModel}, nil
		}
	}
	for _, f := range files {
		if f.Kind != KindCSV && f.Kind != KindSpreadsheet {
			return Result{}, ErrAIUnavailable
		}
	}
	return Result{}, ErrNothing
}
