package httpapi

import (
	"math"
	"sync"
	"time"
)

// limiter is a per-key token bucket. It is per instance, which is enough to
// stop a runaway client from burning the AI quota during the demo.
type limiter struct {
	mu      sync.Mutex
	burst   float64
	perSec  float64
	now     func() time.Time
	buckets map[string]*bucket
}

type bucket struct {
	tokens float64
	last   time.Time
}

// newLimiter allows burst requests at once, refilled at rate per `per`.
func newLimiter(burst, rate int, per time.Duration) *limiter {
	return &limiter{
		burst: float64(burst), perSec: float64(rate) / per.Seconds(),
		now: time.Now, buckets: map[string]*bucket{},
	}
}

// allow takes one token for key. When none is left it returns the seconds
// until the next token.
func (l *limiter) allow(key string) (ok bool, retryAfter int) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	b := l.buckets[key]
	if b == nil {
		if len(l.buckets) > 10000 {
			l.buckets = map[string]*bucket{}
		}
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[key] = b
	}
	b.tokens = math.Min(l.burst, b.tokens+now.Sub(b.last).Seconds()*l.perSec)
	b.last = now
	if b.tokens >= 1 {
		b.tokens--
		return true, 0
	}
	return false, max(1, int(math.Ceil((1-b.tokens)/l.perSec)))
}
