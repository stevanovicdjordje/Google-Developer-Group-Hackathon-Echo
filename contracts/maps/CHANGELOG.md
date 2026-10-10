# contracts/maps — CHANGELOG

Venue map feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

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
