# contracts/echo — CHANGELOG

Echo feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

## 0.1.0 (fixtures) — 2026-10-11
- **Impact:** fixture-only
- **Changes:** `model` in the examples is now `gemma-4-26b-a4b-it`, the model the service actually uses.

## 0.1.0 — 2026-10-11
- **Impact:** additive (new feature contract)
- **Affected:** backend/echo (implements), mobile (consumes through `EchoRepository`)
- **Requested by:** `mobile#5` (API-4 … API-8 and translation in `mobile/docs/api-needs.md`)
- **Changes:**
  - ADDED `echoHealthz`, `askTalk`, `getCatchUp`, `getSummary`, `translateTranscript`
  - ADDED `listQuestions`, `submitQuestion`, `voteQuestion`, `unvoteQuestion`
  - ADDED `realtime.md`: the transcript in Firestore (`events/{eventId}/published/echo/sessions/{sessionId}/lines`)
- **Differences from the `api-needs.md` sketch:** AI responses are `{text, model, basedOnLines}` (the app reads
  `text`); `ask` takes an optional `language`; votes are `PUT`/`DELETE …/vote` (idempotent); a question also has
  `voted` and `createdAt`; translation is `POST …/translate {language, fromIndex}` instead of a field on each line.
- **Consumer action:** mobile can implement `EchoRepository` over this API (see `contracts/echo/STATUS.md`).
