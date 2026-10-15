package httpapi

import (
	"sync"
	"time"
)

// limiter is a per-key fixed-window counter. It is per instance, which is
// enough to stop a runaway client from burning the AI quota during the demo.
type limiter struct {
	mu     sync.Mutex
	max    int
	window time.Duration
	now    func() time.Time
	hits   map[string]*window
}

type window struct {
	start time.Time
	n     int
}

func newLimiter(max int, per time.Duration) *limiter {
	return &limiter{max: max, window: per, now: time.Now, hits: map[string]*window{}}
}

// allow counts one hit for key. When over budget it returns the seconds until
// the window resets.
func (l *limiter) allow(key string) (ok bool, retryAfter int) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	w := l.hits[key]
	if w == nil || now.Sub(w.start) >= l.window {
		if len(l.hits) > 10000 {
			l.hits = map[string]*window{}
		}
		l.hits[key] = &window{start: now, n: 1}
		return true, 0
	}
	if w.n >= l.max {
		return false, int((l.window - now.Sub(w.start) + time.Second - 1) / time.Second)
	}
	w.n++
	return true, 0
}
