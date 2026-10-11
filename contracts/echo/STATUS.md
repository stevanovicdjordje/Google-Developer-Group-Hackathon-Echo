# feature:echo — STATUS

> **Single writer:** the `feature:echo` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 09:24 · **Owner:** @MilosBG03 · **Scopes held:** feature:echo

## Current state

**Back with @MilosBG03 (2026-10-11 09:24)** per `team-echo-holder`. The changes @Ilij4n's agents made meanwhile (per-feature models, contract 0.3.1) are kept as they are. `feature:find` stays with @Vertiglo (agreed per `team-find-holder`); this holder no longer claims it.
Checked on return with a real key against the emulators (demo event `devfest`, 68-line keynote): all Echo tests pass; with `AI_MODEL=gemini-3-flash-preview` + Gemma translation, Ask 1.7–3.4 s, Catch up 2.6 s, Summary 2.5 s, 50-line translation backlog 12 s; with Gemma only (no `AI_MODEL`), Ask 0.9–2.1 s, Catch up 3 s, Summary 4.9 s. Both answer in Serbian, both say "The speaker hasn't covered that yet." off-topic. The summary's trade-off rows match the design (Battery 00:44, Model size 00:55, Hard questions 01:06) more closely on Gemma; on Gemini the last rows were "Install rate" and "Memory".

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
| AI latency | Measured on the 68-line keynote: Ask 1–3 s, Catch up ~2 s, Summary 4–6 s, one new line translated ~1 s, a 50-line backlog 11–13 s (when the user switches translation on mid-talk, translate from the current line rather than from 0). Model calls time out after 20 s (`502 ai_unavailable`, safe to retry). Answers are cached for everyone, so only the first caller waits. Show a loading state. |
| Limits | `429 rate_limited` + `Retry-After` after 30 uncached AI calls or 10 questions per user per minute |
| Env (server) | `GEMINI_API_KEY` (empty = offline assistant, answers quote the transcript, `model: "offline"`), `GEMMA_MODEL`; see `backend/echo/.env.example` |
| Demo talk | Session `s1`, "On-device AI: when the model lives in your pocket", Mara Ilić, Glavna sala: 68 lines, 6:52 (≈3:26 at the default 2× replay). Lines 0–15 and their times match the app's demo data and the design (00:44 battery 12%, 00:50 batching). Ask answers end with when it was said ("Mara mentions it at 00:50."). |
| Structured summary (0.3.0) | `getSummary` → `summary {takeaway, keyPoints[], tradeoffs[{topic, issue, fix, atSeconds}]}` for `EchoSummary`; `atSeconds` is always the start of a real transcript line (00:44 battery, 00:55 model size, 01:06 hard questions on the demo talk). 5–8 s uncached. |
| Question grouping (0.3.0) | `submitQuestion` answers `200` + `merged: true` when Gemma finds the same question already asked (any wording or language, e.g. "Koji model koristite za hibridni ruter?" → "Which model did you use for the hybrid router?"); `mergedCount` on every question drives "N similar questions merged". Adds ~1 s to submit; if the AI fails the question is posted as new. |
| Contract | [`openapi.yaml`](openapi.yaml) 0.3.0, [`realtime.md`](realtime.md), [`CHANGELOG.md`](CHANGELOG.md) |

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
| `askTalk`, `getCatchUp`, `getSummary` (incl. `summary`), `translateTranscript` | implemented (handler tests, e2e on emulators with the offline assistant **and with real Gemma**) | wired (`138b7be`); structured summary in progress (M-21) |
| `listQuestions`, `submitQuestion` (incl. merging), `voteQuestion`, `unvoteQuestion` | implemented (handler tests, Firestore emulator test, e2e with real Gemma) | wired (`138b7be`); merged questions in progress (M-21) |
| Transcript in Firestore (`realtime.md`) | written by `cmd/replay`; rules verified on the emulator (attendee read ok, write 403) | wired (`138b7be`), verified e2e by mobile |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 09:24 · INFO · for: all · @MilosBG03 is back and holds `feature:echo` again (`team-echo-holder`); thanks to @Ilij4n's agents for maintaining it. Your per-feature model change stays. `feature:find` stays with @Vertiglo; @MilosBG03 agrees (`team-find-holder`: "he and @Vertiglo agree who continues"). No API change.
- 2026-10-11 03:40 · INFO · for: all · **Per-feature models** (maintained by @Ilij4n's agent while @MilosBG03 is away, `team-echo-holder`): Ask, Catch up, Summary and question grouping now run on `AI_MODEL` (`gemini-3.8-flash`); Translate stays on Gemma (`GEMMA_MODEL`). Contract 0.3.1 adds `translationModel` on `/healthz`. See `feature-echo-ai` (revised) for the measurements. Restart the Echo service to pick it up.
- 2026-10-11 02:30 · ACTION · for: mobile · `mobile#9` done, Echo contract 0.3.0 (additive): structured `summary` on `getSummary` and question grouping (`mergedCount`, `submitQuestion` → `200` + `merged: true`). Treat `200` from `submitQuestion` as success. Serbian answers confirmed. See `CHANGELOG.md` and the two rows above.
- 2026-10-11 01:40 · INFO · for: mobile · Echo contract 0.2.0 (additive): the session doc in Firestore has optional `title` and `speaker`. The demo keynote `s1` is now 6:52 / 68 lines; the first 16 lines are unchanged, so the design's "Ask about this" example (00:44 / 00:50) works, and Ask now ends with "Mara mentions it at 00:50." No change needed in the app.
- 2026-10-11 01:20 · INFO · for: all · Echo runs on real Gemma now (`gemma-4-26b-a4b-it`, thinking off): Ask ~1 s, Summary ~3–4 s. No API change. Note for anyone else calling Gemma 4 on the Gemini API: send `generationConfig.thinkingConfig.thinkingLevel: "minimal"` and drop parts with `thought: true`, or answers take 10+ s and can come back as reasoning text.
- 2026-10-11 00:44 · ACTION · for: mobile · Echo API 0.1.0 is implemented in `backend/echo` (port 8082) and the transcript replays into Firestore. The table above maps each `EchoRepository` method to it. See request `echo#1`.
- 2026-10-11 00:44 · INFO · for: all · Echo uses Gemma via the Gemini API for Ask, Catch up, Summary and Translation (`feature-echo-ai`). It needs `GEMINI_API_KEY` on the Echo service only; without it the service still runs (offline assistant).
- 2026-10-11 00:30 · INFO · for: all · `feature:echo` registered (@MilosBG03). It takes the Echo part of `mobile#5` (API-4 transcript, API-5 catch-up, API-6 ask, API-7 Q&A, API-8 summary, translation). The rest of `mobile#5` (join, agenda, Find, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| echo#1 | mobile | Wire `EchoRepository` to the Echo API (mapping table above): an HTTP implementation with its own base URL (default `http://localhost:8082`, e.g. `--dart-define=ECHO_API_BASE_URL`), the transcript from the Firestore listener in `realtime.md`, and translation through `translateTranscript` instead of the precomputed `translated` text. Keep the demo implementation as the fallback if you like. Session `s1` (the keynote) is the one with a replayed transcript. | closed (done in mobile `138b7be`, design `0a1a027`) | 2026-10-11 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#9 | mobile | (1) Structured summary: `summary {takeaway, keyPoints[], tradeoffs[{topic, issue, fix, atSeconds}]}` on `getSummary`, `text` stays. (2) Question grouping: a same-meaning question is merged into the existing one (`mergedCount`, `merged`). (3) Confirmed: Ask, Catch up and Summary with `language=sr` answer in Serbian Latin. Contract 0.3.0, verified on real Gemma. | done | 2026-10-11 |
| mobile#5 (API-4…API-8, translation) | mobile | Contract `contracts/echo` 0.1.0 + service `backend/echo`. Differences from the sketch are listed in `CHANGELOG.md`. | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
