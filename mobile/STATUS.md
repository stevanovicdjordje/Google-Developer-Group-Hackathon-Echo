# mobile — STATUS

> **Single writer:** the mobile owner and their agent. Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-11 01:33 · **Owner:** @Ilij4n · **Scopes held:** mobile, integration, product
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

@Ilij4n holds the **mobile module** (app shell `mobile/app/` and all non-map screens). The **venue map** in `mobile/maps/` belongs to `feature:maps` (@Vertiglo, see `contracts/maps/`).

**App skeleton done (2026-10-11):** the whole demo flow from `docs/MVP.md` runs with placeholder styling:
- Start → organizer upload → AI extraction (demo) → review → publish → join link + QR
- Join link `/e/{eventId}` → onboarding (name, interests, consent switches) → event
- Tabs: **Agenda** (stage filter → session → Echo / show on map), **Map** (the real `eho_maps` viewer + meeting-spot banner), **Find** (recommendations + prompt search → person → contact → mock Messages → meeting spot), **Profile** (consents, My events)
- **Echo**: transcript replay, Catch up, Ask AI / Ask speaker, Q&A sheet with votes, translate toggle, premium summary with mock unlock
- **My events** picker (`/events`)

Data: everything except the map is **demo data** behind repository interfaces (`mobile/app/lib/data/repositories.dart`). What the backend needs to provide: [`docs/api-needs.md`](docs/api-needs.md) (`mobile#5`).

Verified: `flutter analyze` clean; `flutter test` 5/5, including a happy-path test (deep link → join → onboarding → agenda → Echo ask → summary → Find); web build renders every screen in headless Chrome. Map tab not verified against a live backend (Go/Firebase CLI aren't installed on @Ilij4n's machine).

Known gaps: UI text is English and hardcoded (no l10n yet); state is in-memory (lost on reload); Firebase emulator banner shows on web.

## Stack

Flutter (web + Android + iOS), Riverpod, go_router, flutter_map (CrsSimple), geolocator, Firebase Auth/Firestore (read-only)/Storage. See [`docs/decisions/mobile-stack.md`](../docs/decisions/mobile-stack.md).

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Platforms targeted for the demo | Flutter web on phones (link/QR, no install); Android/iOS from the same code |
| How to build/install a demo build | `mobile/scripts/dev_all.sh` (local, everything). Hosted web build: not yet |
| Join link / deep-link scheme handled | `/e/{eventId}` (join), `/e/{eventId}/stand/{standId}` → Map tab; app routes in `mobile/app/lib/core/router.dart` |
| Backend base URL configuration | `--dart-define=API_BASE_URL=...` (default `http://localhost:8080`) |
| Mock/fixture mode | Non-map data is always demo data today (`lib/data/demo_data.dart`). For the Map tab: run `backend/maps` + `make seed`, then pass the printed ID: `--dart-define=DEMO_EVENT_ID=<id>` |

## Contract coverage (operations consumed)

| operationId | Status (`not started` / `on fixtures` / `on real API` / `verified e2e`) |
| --- | --- |
| maps: published venue (Firestore realtime) | on real API (via `eho_maps`) |
| echo: transcript (Firestore), `getCatchUp`, `ask`, `listQuestions`, `submitQuestion`, vote/unvote, `getSummary`, `translateTranscript` | verified e2e (transcript, catch-up, questions in the app; ask/translate/submit/unvote via curl; UI paths by widget tests) |
| maps: `getRoute`, `/o` editor | verified e2e (via `eho_maps`) |
| API-1…3, API-9…15 (join, agenda, Find, organizer; `docs/api-needs.md`) | on demo data (no backend owner) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 01:33 · INFO · for: feature:echo · echo#1 done: the Echo screen consumes Echo API 0.1.0 (+ Firestore transcript). Run: maps `make dev`+`make seed`, echo `make dev`+`make replay`, app with `--dart-define=DEMO_EVENT_ID=<seeded id>` (`ECHO_API_BASE_URL` default `http://localhost:8082`). Contract 0.2.0 `title`/`speaker` not used yet.
- 2026-10-11 01:32 · ACTION · for: feature:maps, feature:echo · New design for the app (`mobile/docs/design/`, v1 + v2). Requests: `mobile#8` (maps: route to the selected stage + app-provided sheet content), `mobile#9` (echo: structured summary, optional question grouping, Serbian answers). Both additive; the app keeps working without them.
- 2026-10-11 00:58 · ACTION · for: feature:maps · Request mobile#7: English map screens for the demo video (`product-ui-language` accepted). The app is switching to an English default locale.
- 2026-10-11 00:53 · INFO · for: feature:maps · maps#2 done (location permissions, while in use only). mobile#6 closed: the Map tab's meeting-spot "Show" now uses `highlightFeatureId` + `highlightLabel` ("Meeting: <name>").
- 2026-10-11 00:44 · INFO · for: feature:maps · maps#1 done: `API_BASE_URL` now reaches `eho_maps` (`mapsApiBaseUrlProvider` override), and the app mounts your `/o` routes (Profile → For organizers → Edit venue map). The app's tabs are now a `StatefulShellRoute.indexedStack`, so the Map tab (`MapViewerScreen`) stays alive offstage when the user switches tabs.
- 2026-10-11 00:20 · ACTION · for: feature:maps (@Vertiglo) · The app no longer mounts `mapsRoutes()`. `/e/{eventId}` is now the join/event entry; the map is the **Map tab** (`/e/{eventId}/map`, embeds `MapViewerScreen`); `/e/{eventId}/stand/{standId}` redirects to `/e/{eventId}/map/stand/{standId}`. `main.dart` no longer blocks on Firebase init (5 s timeout). See request `mobile#6`.
- 2026-10-11 00:20 · ACTION · for: backend, contracts (whoever builds the AI/event backend) · App skeleton runs the full demo flow on demo data. Endpoints it needs, with suggested shapes and priorities: [`mobile/docs/api-needs.md`](docs/api-needs.md) (`mobile#5`).
- 2026-10-10 23:30 · ACTION · for: feature:maps (@Vertiglo) · Feature scopes accepted (`docs/COORDINATION.md` §1a, hook updated). Please create `contracts/maps/STATUS.md`, move your open rows there, switch to `git config eho.scope feature:maps`, and release `backend` and `contracts` (Owner → TBD). `mobile` is now held by @Ilij4n. `mobile#1`–`#4` are all done (see *Inbound requests*).
- 2026-10-10 23:30 · ACTION · for: all · Agreed feature set and demo-video plan: `docs/PRODUCT.md`, `docs/MVP.md`. Decisions accepted: `product-hero-flow`, `team-captions-and-stt`, `team-auth`, `team-event-join`.
- 2026-10-10 21:47 · INFO · for: all · New Flutter package `mobile/maps` (`eho_maps`) holds all venue-map client code; `mobile/app` depends on it via `path: ../maps`. Map plan moved to `contracts/maps/PLAN.md`.
- 2026-10-10 21:40 · ACTION · for: all · @Vertiglo works **only on the venue map**. Holds mobile/backend/contracts temporarily so the map can be built; anyone who takes one of these modules for their own work: register, and @Vertiglo releases it and keeps only the map paths (`mobile/maps/`, `backend/maps/`, `contracts/maps/`). Proposed rule change "feature scopes": [`mobile/docs/proposal-feature-scopes.md`](../mobile/docs/proposal-feature-scopes.md).
- 2026-10-10 21:25 · INFO · for: all · Flutter app skeleton in `mobile/app/` runs on web against the local API and Firebase emulators. Run: `mobile/scripts/dev_all.sh`.
- 2026-10-10 21:12 · INFO · for: all · @Vertiglo holds mobile, organizer-web, backend and contracts. Building the venue map (floor plan, stands/rooms, routing, GPS + QR "you are here", organizer stats). Stack: Flutter app in `mobile/app/` (also the organizer UI), Go backend on Cloud Run, Firestore. See decisions mobile-stack, organizer-web-framework, backend-framework, backend-persistence, contracts-realtime-transport.
- 2026-10-10 · INFO · for: all · STATUS file created. Nothing implemented yet.

## Outbound requests (we need something from another module)

> Rows `mobile#1`–`#4` were opened by @Vertiglo while holding mobile; they're answered under *Inbound requests*. @Vertiglo's agent closes them in `contracts/maps/STATUS.md`.

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| mobile#1 | product | Venue map is agreed by the team as an MVP feature (human @Vertiglo, 2026-10-10): floor plan image with rooms/stands/POIs, server-side routing, live GPS dot with accuracy circle and QR/manual "you are here" fallback, organizer stats (search, views, route targets, QR scans; never GPS coordinates). Please update `docs/MVP.md` / `docs/PRODUCT.md` (currently "candidate, no real-time indoor positioning") and add a location section to `docs/DATA_PRIVACY.md`: position is sent to the backend only to compute a route, never stored, logged or shown to others. | open | 2026-10-10 |
| mobile#2 | integration | Record `team-auth`: Firebase Auth. Organizers use email/password, attendees anonymous sign-in; clients send `Authorization: Bearer <Firebase ID token>`; backend verifies and checks `ownerUid` for organizer operations. (Agreed by @Vertiglo's team, 2026-10-10.) | open | 2026-10-10 |
| mobile#4 | integration | Adopt **feature scopes**: register for a feature (`feature:<name>`) instead of whole modules. Full text and exact hook/rules changes: [`mobile/docs/proposal-feature-scopes.md`](docs/proposal-feature-scopes.md). | open | 2026-10-10 |
| mobile#3 | integration | Record `team-event-join`: plain HTTPS link to the Flutter web app, `https://<host>/e/{eventId}`; optional `?at={markerId}` (QR "you are here" marker), `/e/{eventId}/stand/{standId}` for a stand. Same paths work as app deep links. | open | 2026-10-10 |

| mobile#6 | feature:maps | (1) Accept the routing change above (Map tab embeds `MapViewerScreen`). (2) Optional, for the meeting-spot step: a way to highlight a place by feature name or ID with a custom label (today the app opens `/map/stand/{id}`). (3) Keep using `Theme.of(context)` for colors so the redesign applies to the map too. | closed | 2026-10-11 |
| mobile#9 | feature:echo | For the new design (`mobile/docs/design/EchoSummary.dc.html`, `EchoQA.dc.html`; README "v2 additions"): (1) **structured summary**, additive to `getSummary`: e.g. `takeaway` (1–2 sentences), `keyPoints[]`, `tradeoffs[]` of `{issue, fix, atSeconds}` (the rows link back to the transcript time) — keep `text` for old clients. (2) Optional: question grouping ("3 similar questions merged") as e.g. `mergedCount` on a question. (3) When translate is on, Ask/Catch up/Summary are requested with `language=sr`: please confirm answers come back in Serbian (Latin). | open | 2026-10-11 |
| mobile#8 | feature:maps | For the new design (`mobile/docs/design/MapDetail.dc.html`): when a stage/room is selected, (1) draw the route line from "You are here" (QR marker/GPS) to it, as "Prikaži put" already does, and (2) let the app supply the details-sheet content, e.g. `MapViewerScreen(featureSheetBuilder: (context, feature, route) => Widget?)` (null = your default sheet), so the app can show capacity, walk time, the session happening NOW there, **Start route** and **Open Echo**. Additive; the app keeps working without it. | open | 2026-10-11 |
| mobile#7 | feature:maps | `product-ui-language` is accepted: the app UI and demo video are **English**. Please make the map screens shown in the video English (viewer: search, details sheet, "Prikaži put", route card/banner, "Moja lokacija", "Server trenutno nije dostupan"; organizer login if shown) — e.g. complete `maps_en.arb` and follow the app's locale. The app will set `locale: Locale('en')` by default (board M-11). | open | 2026-10-11 |
| mobile#5 | backend, contracts | Backend endpoints for the non-map demo flow: `mobile/docs/api-needs.md` (API-1…API-15, priorities included). | open | 2026-10-11 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| echo#1 | feature:echo | Done (`138b7be`): `EchoApiRepository` — transcript from the Firestore listener, catch-up/ask/questions/submit/vote/summary/translate over HTTP with the anonymous ID token; demo fallback when `/healthz` fails or `USE_ECHO_API=false`. Translate targets `sr`. Verified e2e against `backend/echo` (offline assistant) on the seeded event. | done | 2026-10-11 |
| maps#2 | feature:maps | Added: Android `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`, iOS `NSLocationWhenInUseUsageDescription` (no background/Always). Commit `3cee092`. | done | 2026-10-11 |
| maps#1 | feature:maps | (a) already in `pubspec.lock`. (b) `main.dart` overrides `mapsApiBaseUrlProvider` with `AppConfig.apiBaseUrl`. (c) Profile → "For organizers" → "Edit venue map" opens `/o`; the app router mounts the `/o` routes of `mapsRoutes()` (not its `/e/:eventId`). | done | 2026-10-11 |
| mobile#4 | @Vertiglo (maps) | Feature scopes adopted: `AGENTS.md`, `docs/COORDINATION.md` §1a, `ONBOARDING.md`, `docs/OWNERSHIP.md`, `.githooks/pre-commit` | done | 2026-10-10 |
| mobile#3 | @Vertiglo (maps) | `docs/decisions/team-event-join.md` accepted | done | 2026-10-10 |
| mobile#2 | @Vertiglo (maps) | `docs/decisions/team-auth.md` accepted | done | 2026-10-10 |
| mobile#1 | @Vertiglo (maps) | Map is in the demo (`docs/MVP.md`, `product-hero-flow`); location rules added to `docs/DATA_PRIVACY.md` | done | 2026-10-10 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
