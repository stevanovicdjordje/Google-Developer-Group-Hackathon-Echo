# feature:maps — STATUS

> **Single writer:** the `feature:maps` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 01:15 · **Owner:** @Vertiglo · **Scopes held:** feature:maps

## Current state

The venue map: `mobile/maps/` (Flutter package `eho_maps`), `backend/maps/` (Go service), `contracts/maps/` (this folder).
Phases 1–4 done: API + publish, attendee viewer (`/e/{eventId}`), organizer editor (`/o`, `/o/e/{eventId}`).
Phase 5 (routing) done: the server computes walking routes (`getRoute`, contract 0.2.0) and the attendee viewer draws them ("Prikaži put", from the scanned QR marker or a picked start, multi-floor banner). Phase 6 (location) done: organizers tie a floor to GPS with 3 points; attendees get a GPS dot with accuracy, the route starts there and follows them (re-route, "Stigli ste"), with QR / tap-on-map as fallback. Phase 7 (stats) done: the viewer reports searches (incl. ones without results), opened details, route targets and QR scans in batches (contract 0.3.0, never positions); organizers see them per day at `/o/e/{eventId}/stats` (chart icon in the editor). Next: phase 8 (polish + deploy). Details and the exact stop point: [`PLAN.md`](PLAN.md) → "Where we stopped".

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | `cd backend/maps && make dev` (emulators + API on `http://localhost:8080`), then `make seed` (prints the demo event's links) |
| Routes the app gets from `mapsRoutes()` | `/e/{eventId}` (`?at={markerId}`), `/e/{eventId}/stand/{featureId}` (any feature, rooms too), `/o`, `/o/e/{eventId}`, `/o/e/{eventId}/stats` (child of the `/o` route the app already mounts) |
| App integration | `MapsLocalizations.delegate` in the app; optional `mapsApiBaseUrlProvider` override (default `http://localhost:8080`) |
| Organizer demo login | `organizer@eho.test` / `eho-demo-123` (emulator only). On web with emulators every page load starts signed out |
| Contract | [`openapi.yaml`](openapi.yaml) 0.3.0, [`realtime.md`](realtime.md), [`CHANGELOG.md`](CHANGELOG.md) |

## Contract coverage

| Operation | Server (`backend/maps`) | App (`mobile/maps`) |
| --- | --- | --- |
| `listMyEvents`, `getEvent`, `createEvent`, `getDraftMap`, `publishEvent`, `createFloor`, `updateFloor`, `deleteFloor`, `putFloorGraph`, `createFeature`, `updateFeature`, `deleteFeature` | implemented (handler tests) | verified e2e (emulators, headless Chrome) |
| `putFloorGeoref`, `deleteFloorGeoref` | implemented (handler tests); transform checked against `testdata/georef.json` | editor GPS screen (widget tests, fake server); published georef verified e2e in the viewer |
| `updateEvent`, `deleteEvent`, `mapsHealthz` | implemented (handler tests) | not used yet |
| `getRoute` | implemented (A* tests vs Dijkstra, 0.5 ms on 5000 nodes, handler tests) | verified e2e (emulators, headless Chrome, inside the app's Map tab); widget tests incl. multi-floor |
| `recordStats`, `getStats` | implemented (handler tests incl. rate limit; Firestore store test on the emulator) | verified e2e (emulators, headless Chrome: viewer in the app's Map tab reports, organizer stats screen shows them); widget tests |
| Published map in Firestore (`realtime.md`) | written by publish | verified e2e; a publish reaches an open viewer in ~0.6 s |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 01:15 · INFO · for: all · Map contract 0.3.0 (additive): `recordStats` + `getStats`. The map viewer in the Map tab now reports, in batches, what attendees search/open/route to and QR scans (no positions, no user IDs stored). Organizers: Profile → Edit venue map → event → chart icon (`/o/e/{id}/stats`, already covered by the `/o` route you mount). Nothing to change in `mobile/app`.
- 2026-10-11 00:48 · INFO · for: mobile · `MapViewerScreen` has `highlightFeatureId` + `highlightLabel` for the meeting spot (mobile#6). The viewer stops GPS while its tab is offstage (`TickerMode` off); the attendee taps "Moja lokacija" again when back.
- 2026-10-11 00:45 · ACTION · for: mobile · The map viewer has "Moja lokacija" (GPS dot, route from GPS). It uses `geolocator` (the version your lock already has, so no lock change). On web it works as is; Android/iOS need the location permission entries, see maps#2.
- 2026-10-11 00:20 · INFO · for: mobile · The map viewer (`MapViewerScreen`, in your Map tab) now has "Prikaži put": it calls the map API (`POST /v1/events/{id}/route`) with the signed-in (anonymous) user's ID token. No API change for the app; the base URL comes from `mapsApiBaseUrlProvider` (default `http://localhost:8080`), so maps#1 (b) now matters for attendees too.
- 2026-10-11 00:04 · INFO · for: all · Map contract 0.2.0: `getRoute` (walking route on the published map). Additive; see `CHANGELOG.md`.
- 2026-10-10 23:52 · INFO · for: mobile · Organizer map editor is in `eho_maps` (`/o`, `/o/e/{eventId}`, mounted through `mapsRoutes()`). `eho_maps` now depends on `file_picker` and `http`, so `flutter pub get` in `mobile/app` updates its `pubspec.lock`. See request maps#1.
- 2026-10-10 23:52 · INFO · for: all · `feature:maps` registered (@Vertiglo). `backend` and `contracts` released (Owner TBD); `mobile` is @Ilij4n's.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| maps#1 | mobile | (a) Commit the `mobile/app/pubspec.lock` update from `flutter pub get` (`eho_maps` added `file_picker`). (b) In `main.dart`, override `mapsApiBaseUrlProvider` with `AppConfig.apiBaseUrl` so `--dart-define=API_BASE_URL` also reaches the map editor. (c) Somewhere for organizers (e.g. Profile), a way into `/o` (map editor). Placement is your call. | closed (done by mobile, 2026-10-11) | 2026-10-10 |
| maps#2 | mobile | For the GPS dot on native builds: Android `mobile/app/android/app/src/main/AndroidManifest.xml` → `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` and `ACCESS_COARSE_LOCATION`; iOS `mobile/app/ios/Runner/Info.plist` → `NSLocationWhenInUseUsageDescription` (e.g. "Eho prikazuje vašu tačku na planu objekta. Lokacija se ne čuva."). Only while in use, no background location. | closed (done by mobile, `3cee092`) | 2026-10-11 |
| mobile#1–#4 | product, integration | Opened by @Vertiglo while holding mobile (map in the MVP, `team-auth`, `team-event-join`, feature scopes). All answered as `done` in `mobile/STATUS.md`. | closed | 2026-10-10 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#7 | mobile | Done, nothing to change: every map string is in `maps_en.arb` (complete, incl. the new stats screen) and the map follows the app's locale through `MapsLocalizations.delegate`. Verified in the app's English build (headless Chrome): search, filters, details sheet, "Show the way", "You are here". Note: the **demo venue content** (room/stand names, categories, descriptions from `make seed`) is still Serbian; your demo data matches those names ("Glavna sala", "Sala A/B", "Info pult", "Hrana i piće"), so translating it would be a joint change — tell us if you want it. | done | 2026-10-11 |
| mobile#6 | mobile | (1) Accepted: the Map tab embeds `MapViewerScreen`; `mapsRoutes()` stays the source for `/o`. (2) Done: `MapViewerScreen(highlightFeatureId: id, highlightLabel: 'Sastanak: Ana')` opens on the place and shows the label on a pin (no details sheet). Look up the ID by name yourself, as `_showSpot` already does. (3) Partly: text, surfaces, selection and the new label use `Theme.of(context)`; room/stand fills, sponsor tiers and the route blue stay fixed for plan legibility (`MapPalette` in `viewer/labels.dart`). Ask if you want any of those on the theme. Also: GPS now stops when the Map tab is offstage. | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
