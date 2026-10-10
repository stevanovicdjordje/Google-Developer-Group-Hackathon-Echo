package routing

import (
	"sync"

	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Cache keeps the routing graph of recently routed events, keyed by event
// and published version, so a route needs no map read until the next publish.
type Cache struct {
	mu      sync.Mutex
	max     int
	entries map[string]cacheEntry
	tick    uint64
}

type cacheEntry struct {
	version int
	graph   *Graph
	used    uint64
}

// NewCache holds graphs of up to max events (least recently used evicted).
func NewCache(max int) *Cache {
	return &Cache{max: max, entries: map[string]cacheEntry{}}
}

// Get returns the graph of eventID at version, building it with load on a
// miss. load returns the published map and the version it belongs to.
func (c *Cache) Get(eventID string, version int, load func() (*venue.Map, int, error)) (*Graph, error) {
	c.mu.Lock()
	c.tick++
	if e, ok := c.entries[eventID]; ok && e.version == version {
		e.used = c.tick
		c.entries[eventID] = e
		c.mu.Unlock()
		return e.graph, nil
	}
	c.mu.Unlock()

	// Built outside the lock; two concurrent misses just build twice.
	m, v, err := load()
	if err != nil {
		return nil, err
	}
	g := Build(m)

	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.entries) >= c.max {
		if _, ok := c.entries[eventID]; !ok {
			oldest, oldestUsed := "", ^uint64(0)
			for id, e := range c.entries {
				if e.used < oldestUsed {
					oldest, oldestUsed = id, e.used
				}
			}
			delete(c.entries, oldest)
		}
	}
	c.tick++
	c.entries[eventID] = cacheEntry{version: v, graph: g, used: c.tick}
	return g, nil
}
