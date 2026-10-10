package stats

import (
	"math"
	"sync"
	"time"
)

// Limiter is a per-key token bucket (one bucket per signed-in user). Keys
// live in memory only and are dropped once their bucket is full again.
type Limiter struct {
	rate  float64 // tokens per second
	burst float64
	now   func() time.Time

	mu      sync.Mutex
	buckets map[string]*bucket
}

type bucket struct {
	tokens float64
	last   time.Time
}

// NewLimiter allows burst tokens at once and perMinute tokens per minute after.
func NewLimiter(burst, perMinute int) *Limiter {
	return &Limiter{rate: float64(perMinute) / 60, burst: float64(burst), now: time.Now, buckets: map[string]*bucket{}}
}

// Allow takes cost tokens from key's bucket. If there are not enough, it
// takes nothing and returns how long to wait.
func (l *Limiter) Allow(key string, cost int) (bool, time.Duration) {
	now := l.now()
	l.mu.Lock()
	defer l.mu.Unlock()
	if len(l.buckets) > 10_000 {
		l.prune(now)
	}
	b := l.buckets[key]
	if b == nil {
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[key] = b
	}
	b.tokens = math.Min(l.burst, b.tokens+now.Sub(b.last).Seconds()*l.rate)
	b.last = now
	c := float64(cost)
	if b.tokens >= c {
		b.tokens -= c
		return true, 0
	}
	wait := time.Duration(math.Ceil((c-b.tokens)/l.rate)) * time.Second
	return false, wait
}

// prune drops buckets that have refilled completely (callers hold l.mu).
func (l *Limiter) prune(now time.Time) {
	for k, b := range l.buckets {
		if b.tokens+now.Sub(b.last).Seconds()*l.rate >= l.burst {
			delete(l.buckets, k)
		}
	}
}
