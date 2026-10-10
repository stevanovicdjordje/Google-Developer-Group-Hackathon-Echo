# feature:echo — STATUS

> **Single writer:** the `feature:echo` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 01:20 · **Owner:** @MilosBG03 · **Scopes held:** feature:echo

## Current state

Echo, the talk companion: the server side of the transcript (pre-recorded, replayed as if live per `team-captions-and-stt`), translation, Ask AI, Catch up, full summary and audience Q&A.
Paths: `backend/echo/` (Go service, port 8082), `contracts/echo/` (this folder), `docs/decisions/feature-echo-*`. The Echo screens stay in the app shell (`mobile/app/lib/features/echo`, held by `mobile`); request `echo#1` asks mobile to wire them to this API.

**Done (2026-10-11):** contract 0.1.0 and the whole service: replay of the demo keynote into Firestore, all 8 operations, Gemma adapter (Gemini API) + offline assistant, caching, rate limits.
Verified: `go test` (handlers, prompts/output validation, Gemini client against a fake server, Firestore store against the emulator); end to end on the emulators (map seed → replay → anonymous attendee): every response validates against `openapi.yaml`, the attendee can read `lines` from Firestore and gets `403` on private Echo data and on writes.
**Real Gemma verified (2026-10-11):** `gemma-4-26b-a4b-it` on the demo keynote, all AI operations, English and Serbian (Latin and Cyrillic): grounded answers, "not covered yet" for off-topic and prompt-injection questions, responses valid against the contract. AI model decision: [`feature-echo-ai`](../../docs/decisions/feature-echo-ai.md).

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | `cd backend/maps && make dev` + `make seed` (emulators, demo event), then `cd backend/echo && make dev` (API on `http://localhost:8082`) and `make replay` (plays the keynote into session `s1` of the demo event, 2× speed) |
| Auth | Same as the map: `Authorization: Bearer <Firebase ID token>`, anonymous attendees are fine. The event must be published. |
| Transcript | Firestore listener on `events/{eventId}/published/echo/sessions/{sessionId}/lines` ordered by `index`; session status in the parent doc. See [`realtime.md`](realtime.md). |
| AI latency | Measured: Ask ~1 s, Catch up ~3 s, Summary 3–4 s, one new transcript line translated ~1 s. Model calls time out after 20 s (`502 ai_unavailable`, safe to retry). Answers are cached for everyone, so only the first caller waits. Show a loading state. |
| Limits | `429 rate_limited` + `Retry-After` after 30 uncached AI calls or 10 questions per user per minute |
| Env (server) | `GEMINI_API_KEY` (empty = offline assistant, answers quote the transcript, `model: "offline"`), `GEMMA_MODEL`; see `backend/echo/.env.example` |
| Contract | [`openapi.yaml`](openapi.yaml) 0.1.0, [`realtime.md`](realtime.md), [`CHANGELOG.md`](CHANGELOG.md) |

### `EchoRepository` → API (for the mobile agent)

| App method | API |
| --- | --- |
| `transcript` | Firestore listener (above). `TranscriptLine.translated` ← `translateTranscript` |
| `catchUp` | `GET …/sessions/{s}/catch-up?language=` → `.text` |
| `ask` | `POST …/sessions/{s}/ask {question, language}` → `.text` |
| `questions` | `GET …/sessions/{s}/questions` → `.questions[]` (`id, text, votes, mine, voted`) |
| `submitQuestion` | `POST …/sessions/{s}/questions {text}` → `201` question |
| (vote button) | `PUT` / `DELETE …/questions/{q}/vote` |
| `fullSummary` | `GET …/sessions/{s}/summary?language=` → `.text` (`•` bullet lines) |
| (🌐 translate) | `POST …/sessions/{s}/translate {language, fromIndex}` → `lines[{index, text}]`, `nextIndex` |

## Contract coverage

| Operation | Server (`backend/echo`) | App |
| --- | --- | --- |
| `echoHealthz` | implemented | — |
| `askTalk`, `getCatchUp`, `getSummary`, `translateTranscript` | implemented (handler tests, e2e on emulators with the offline assistant **and with real Gemma**) | not wired (demo data) |
| `listQuestions`, `submitQuestion`, `voteQuestion`, `unvoteQuestion` | implemented (handler tests, Firestore emulator test, e2e) | not wired (demo data) |
| Transcript in Firestore (`realtime.md`) | written by `cmd/replay`; rules verified on the emulator (attendee read ok, write 403) | not wired (demo data) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 01:20 · INFO · for: all · Echo runs on real Gemma now (`gemma-4-26b-a4b-it`, thinking off): Ask ~1 s, Summary ~3–4 s. No API change. Note for anyone else calling Gemma 4 on the Gemini API: send `generationConfig.thinkingConfig.thinkingLevel: "minimal"` and drop parts with `thought: true`, or answers take 10+ s and can come back as reasoning text.
- 2026-10-11 00:44 · ACTION · for: mobile · Echo API 0.1.0 is implemented in `backend/echo` (port 8082) and the transcript replays into Firestore. The table above maps each `EchoRepository` method to it. See request `echo#1`.
- 2026-10-11 00:44 · INFO · for: all · Echo uses Gemma via the Gemini API for Ask, Catch up, Summary and Translation (`feature-echo-ai`). It needs `GEMINI_API_KEY` on the Echo service only; without it the service still runs (offline assistant).
- 2026-10-11 00:30 · INFO · for: all · `feature:echo` registered (@MilosBG03). It takes the Echo part of `mobile#5` (API-4 transcript, API-5 catch-up, API-6 ask, API-7 Q&A, API-8 summary, translation). The rest of `mobile#5` (join, agenda, Find, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| echo#1 | mobile | Wire `EchoRepository` to the Echo API (mapping table above): an HTTP implementation with its own base URL (default `http://localhost:8082`, e.g. `--dart-define=ECHO_API_BASE_URL`), the transcript from the Firestore listener in `realtime.md`, and translation through `translateTranscript` instead of the precomputed `translated` text. Keep the demo implementation as the fallback if you like. Session `s1` (the keynote) is the one with a replayed transcript. | open | 2026-10-11 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#5 (API-4…API-8, translation) | mobile | Contract `contracts/echo` 0.1.0 + service `backend/echo`. Differences from the sketch are listed in `CHANGELOG.md`. | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
