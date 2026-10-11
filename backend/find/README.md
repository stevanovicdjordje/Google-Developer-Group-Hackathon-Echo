# Find service (`backend/find`)

People to meet at an event: profiles with consent switches, AI-ranked
recommendations and prompt search, contact requests and an agreed meeting spot
on the venue map. Implements [`contracts/find/openapi.yaml`](../../contracts/find/openapi.yaml)
(0.1.0). Go, Firebase Auth ID tokens, Firestore, a Gemini model through the Gemini API
([`feature-find-ai`](../../docs/decisions/feature-find-ai.md)).

## Run

The Firebase emulators and the published demo event come from `backend/maps`
(`make dev`, `make seed` there).

```bash
make dev     # API on :8083 against the emulators (scripts/dev.sh, reads .env)
make seed    # 20 demo attendees present at "DevFest Belgrade 2026" (EVENT=<id> for another)
make test    # unit + handler tests
make test-emulator   # also the Firestore store test (emulator on 127.0.0.1:8081)
```

Seeded attendees (`demo-attendee-01`…`20`, `demo: true`) accept contact
requests at once, so the whole flow works in the demo.

## Environment

| Var | Default | |
| --- | --- | --- |
| `PORT` | `8083` | |
| `FIREBASE_PROJECT_ID` | (required) | `demo-eho` locally |
| `ALLOWED_ORIGINS` | `http://localhost:*,http://127.0.0.1:*` | CORS; `:*` = any port |
| `GEMINI_API_KEY` | empty | empty = offline overlap ranking (`model: offline`) |
| `AI_MODEL` | `gemini-3-flash-preview` | any Gemini API model; `gemma-*` also works |
| `AI_THINKING` | `low` (`minimal` for `gemma-*`) | Gemini 3 calls get +1024 output tokens for thinking |
| `AI_TIMEOUT_SECONDS` | `8` | one model call, retries included; then offline ranking |
| `LOG_LEVEL` | `info` | |

Recommendations and search share a per-user token bucket (burst 20, 20/min)
→ `429 rate_limited` with `Retry-After`. Any model failure or invalid output
falls back to offline ranking for that request (`model: offline`), so the
demo never waits more than ~8 s.

## Data (Firestore, Admin SDK only; rules deny clients)

```
profiles/{uid}                          name, headline, interests[], lookingFor, visibleInFind,
                                        allowContact, shareMeetingSpot, updatedAt,
                                        personId (random, public), events[], demo
events/{eventId}/people/{uid}           personId, joinedAt   (presence)
events/{eventId}/contacts/{uidA_uidB}   a, b, from, state (requested|accepted), createdAt,
                                        meetingSpot {place, setBy, updatedAt}
```

Reads `events/{eventId}` (`publishedVersion > 0`) and the published map
features (`events/{eventId}/published/map/features`, `name`) for meeting spots.

## Privacy

- Everything is opt-in. Only people with `visibleInFind` who are present at the
  event are listed; everyone else answers `404` for person operations.
- Clients only ever see `personId`, never user IDs or consent switches of others.
- The model gets only candidates' headline, interests and lookingFor (and the
  caller's, for recommendations), labelled `c1`, `c2`…: never names or IDs.
  Model output is validated (known indices only, plain-text `why` ≤ 240 chars).
- No profile text, prompts or request bodies are logged.
- `DELETE /v1/me/profile` removes the profile, all presence docs and the
  caller's contacts at those events.

## Deploy

`make deploy PROJECT=<id> [REGION=europe-west1]` (Cloud Run, after `backend/maps`' deploy for the rules);
see `backend/events/README.md` → Deploy.
