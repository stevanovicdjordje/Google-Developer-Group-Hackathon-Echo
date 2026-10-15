package stats

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"
)

// Sink stores a day's counts by adding them to what is already stored.
type Sink interface {
	AddStats(ctx context.Context, eventID string, d *Day) error
}

type dayKey struct{ eventID, date string }

// Aggregator buffers counts in memory and adds them to the Sink in batches,
// so a busy event costs one write per event-day per flush instead of one per
// tap. Counts not yet flushed are lost if the process dies; that is fine for
// stats.
type Aggregator struct {
	sink Sink
	log  *slog.Logger
	now  func() time.Time

	mu      sync.Mutex
	pending map[dayKey]*Day
}

// NewAggregator returns an Aggregator writing to sink.
func NewAggregator(sink Sink, log *slog.Logger) *Aggregator {
	if log == nil {
		log = slog.Default()
	}
	return &Aggregator{sink: sink, log: log, now: time.Now, pending: map[dayKey]*Day{}}
}

// Add counts events for eventID on today's (UTC) day.
func (a *Aggregator) Add(eventID string, events []Event) {
	if len(events) == 0 {
		return
	}
	k := dayKey{eventID, DateOf(a.now())}
	a.mu.Lock()
	defer a.mu.Unlock()
	d := a.pending[k]
	if d == nil {
		d = NewDay(k.date)
		a.pending[k] = d
	}
	for _, e := range events {
		d.Add(e)
	}
}

// Flush writes all pending counts.
func (a *Aggregator) Flush(ctx context.Context) error { return a.flush(ctx, "") }

// FlushEvent writes the pending counts of one event (before showing its stats).
func (a *Aggregator) FlushEvent(ctx context.Context, eventID string) error {
	return a.flush(ctx, eventID)
}

func (a *Aggregator) flush(ctx context.Context, eventID string) error {
	a.mu.Lock()
	batch := map[dayKey]*Day{}
	for k, d := range a.pending {
		if eventID == "" || k.eventID == eventID {
			batch[k] = d
			delete(a.pending, k)
		}
	}
	a.mu.Unlock()

	var errs []error
	for k, d := range batch {
		if err := a.sink.AddStats(ctx, k.eventID, d); err != nil {
			errs = append(errs, err)
			// Keep the counts for the next flush.
			a.mu.Lock()
			if p := a.pending[k]; p != nil {
				p.Merge(d)
			} else {
				a.pending[k] = d
			}
			a.mu.Unlock()
		}
	}
	return errors.Join(errs...)
}

// Run flushes every interval until ctx is done, then flushes once more
// (bounded by finalTimeout) so a graceful shutdown keeps the counts.
func (a *Aggregator) Run(ctx context.Context, interval, finalTimeout time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			if err := a.Flush(ctx); err != nil {
				a.log.WarnContext(ctx, "stats flush failed; will retry", "err", err)
			}
		case <-ctx.Done():
			fctx, cancel := context.WithTimeout(context.Background(), finalTimeout)
			if err := a.Flush(fctx); err != nil {
				a.log.Warn("final stats flush failed", "err", err)
			}
			cancel()
			return
		}
	}
}
