# contracts/maps — CHANGELOG

Venue map feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

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
