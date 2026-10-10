# backend/echo — Echo service

The server side of **Echo**, the talk companion (`feature:echo`, status in
[`contracts/echo/STATUS.md`](../../contracts/echo/STATUS.md)). Contract:
[`contracts/echo/openapi.yaml`](../../contracts/echo/openapi.yaml) + [`realtime.md`](../../contracts/echo/realtime.md).

- **Transcript:** a pre-recorded transcript is replayed as if live (`cmd/replay`) into
  `events/{eventId}/published/echo/sessions/{sessionId}/lines`. The app reads it with a Firestore listener; the
  existing rules (`backend/maps/firebase/firestore.rules`) already allow that for published events.
- **AI** (Ask, Catch up, Summary, Translation) works on the lines revealed so far. Gemma through the Gemini API
  ([`docs/decisions/feature-echo-ai.md`](../../docs/decisions/feature-echo-ai.md)). Without `GEMINI_API_KEY` the
  service uses an **offline** assistant that quotes the transcript, so everything runs without a key.
- **Q&A:** questions and votes, private to the service (authors are never revealed).

Go (net/http, slog), Firebase Admin SDK, Firestore. Same conventions as `backend/maps`.

## Run locally

Needs Go 1.27 and the Firebase CLI (Java 21 for the emulators).

```bash
cd backend/maps && make dev          # terminal 1: emulators + map API on :8080
cd backend/maps && make seed         # once: the published demo event
cd backend/echo && make dev          # terminal 2: Echo API on :8082 (reads backend/echo/.env if present)
cd backend/echo && make replay       # terminal 3: replays the keynote into session s1 of the demo event
```

`make replay SPEED=1` plays at recorded pace; `EVENT=<id>` targets another event; `go run ./cmd/replay -instant`
writes every line at once. A replay first deletes the old lines of that session.

To use Gemma: copy `.env.example` to `.env` and set `GEMINI_API_KEY`.

## Layout

| Path | What |
| --- | --- |
| `cmd/api` | HTTP server |
| `cmd/replay` | Transcript replay into Firestore |
| `demo/keynote.json` | The demo keynote transcript (session `s1`, same text as the app's demo data) |
| `internal/assist` | Prompts, Gemini/Gemma adapter, offline assistant, output validation |
| `internal/httpapi` | Routes, auth, rate limits, caching |
| `internal/store` | Firestore + in-memory store |

## AI behavior (for clients)

| Item | Value |
| --- | --- |
| Timeout | 20 s per model call (`AI_TIMEOUT_SECONDS`) → `502 ai_unavailable` |
| Caching | Per session, language and number of revealed lines (Ask also per question). The first caller pays the latency, everyone after gets the cached answer. |
| Rate limits | 30 AI cache misses and 10 questions per user per minute → `429 rate_limited` + `Retry-After` |
| Output | Plain text, `•` bullets in the summary, at most 4000 characters |

## Tests

```bash
make test             # unit + handler tests (in-memory store, fake model)
make test-emulator    # also the Firestore store test (emulator on 127.0.0.1:8081)
```
