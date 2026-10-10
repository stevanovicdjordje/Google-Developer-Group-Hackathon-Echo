# mobile/maps — venue map feature (Flutter package `eho_maps`)

Everything of the Eho **venue map** on the client: attendee viewer, organizer editor, location (GPS / QR "you are here"), map stats. The app in [`../app`](../app) only depends on this package and mounts its routes.

- Plan and phases: [`../../contracts/maps/PLAN.md`](../../contracts/maps/PLAN.md)
- API contract: [`../../contracts/maps/openapi.yaml`](../../contracts/maps/openapi.yaml), Firestore paths: [`../../contracts/maps/realtime.md`](../../contracts/maps/realtime.md)
- Server: [`../../backend/maps`](../../backend/maps)

```bash
cd mobile/maps
flutter test
flutter analyze
```

Layout: `lib/src/model/` (map data and routes, mirror the contract), `lib/src/data/` (published map from Firestore), `lib/src/viewer/` (attendee map, search, routing UI), `lib/src/editor/` (organizer editor, `MapsApi`). Location and stats come in the next phases.
