# contracts/maps — CHANGELOG

Venue map feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

## 0.3.1 — 2026-10-11
- **Impact:** additive
- **Affected:** backend/maps (implements), seed scripts
- **Requested by:** mobile#16 (stable demo event ID)
- **Changes:**
  - ADDED optional `id` on `EventInput` (`createEvent`): `^[a-z0-9][a-z0-9-]{2,39}$`; an existing ID → `409 conflict` (new `Conflict` response)
  - `make seed` now publishes the demo event as `devfest` (`EVENT_ID=<id>` overrides)
- **Consumer action:** none; the app can keep `DEMO_EVENT_ID=devfest` across re-seeds.

## 0.3.0 — 2026-10-11
- **Impact:** additive
- **Affected:** backend/maps (implements), mobile/maps (consumes: viewer reports, organizer stats screen)
- **Requested by:** venue map plan, phase 7 (`PLAN.md`)
- **Changes:**
  - ADDED `recordStats` (`POST /v1/events/{eventId}/stats/events`): batched attendee events (`search`, `feature_view`, `route`, `qr_scan`), any signed-in user, rate limited per user (`429 rate_limited` + `Retry-After`); never positions, no user ID stored
  - ADDED `getStats` (`GET /v1/events/{eventId}/stats?from&to`): owner-only per-day counts (UTC) and top lists (searches, searches without results, opened features, route targets, QR scans)
  - ADDED schemas `StatsEvent`, `StatsBatch`, `StatsCounts`, `StatsDay`, `TermCount`, `FeatureCount`, `EventStats`; fixtures `stats-events.request.json`, `stats.response.json`
  - `realtime.md`: shape of `events/{eventId}/stats/{yyyy-mm-dd}` (owner-readable)
- **Consumer action:** none outside the map feature.

## Unreleased — 2026-10-11
- **Impact:** fixture-only
- **Affected:** backend/maps, mobile/maps (tests)
- **Requested by:** venue map plan, phase 6 (`PLAN.md`)
- **Changes:**
  - ADDED `testdata/georef.json`: georeferencing vectors (3 control points ↔ pixels/lat-lng, metersPerPixel, quality, a degenerate case) that the Go and Dart transforms must both match
- **Consumer action:** none; regenerate with `go test ./internal/geo -run TestSharedVectors -update` in `backend/maps`.

## 0.2.0 — 2026-10-11
- **Impact:** additive
- **Affected:** backend/maps (implements), mobile/maps (consumes)
- **Requested by:** venue map plan, phase 5 (`PLAN.md`)
- **Changes:**
  - ADDED `getRoute` (`POST /v1/events/{eventId}/route`): fastest walking route on the published map between two features or floor points; legs per floor, lift/stairs, distance, duration, `accessible` (no stairs)
  - ADDED schemas `RouteEndpoint`, `RouteRequest`, `RouteLeg`, `Route`; fixtures `route.request.json`, `route.response.json`
- **Consumer action:** mobile/maps draws the route in the attendee viewer.

## 0.1.0 — 2026-10-10
- **Impact:** additive (new feature contract)
- **Affected:** backend/maps (implements), mobile/maps (consumes)
- **Requested by:** venue map plan, phase 2 (`contracts/maps/PLAN.md`)
- **Changes:**
  - ADDED `mapsHealthz`, `listMyEvents`, `createEvent`, `getEvent`, `updateEvent`, `deleteEvent`, `getDraftMap`, `publishEvent`
  - ADDED `createFloor`, `updateFloor`, `deleteFloor`, `putFloorGeoref`, `deleteFloorGeoref`, `putFloorGraph`
  - ADDED `createFeature`, `updateFeature`, `deleteFeature`
  - ADDED `realtime.md`: readable Firestore paths of the published map
- **Consumer action:** mobile/maps uses these for the editor and reads the published map from Firestore.
