# Echo — realtime transcript (Firestore, read-only for clients)

Transport: Firestore snapshot listeners (`contracts-realtime-transport`). The transcript lives under the event's
`published/` subtree, so the existing rules already let any signed-in user read it once the event is published, and
nobody but the backend can write it. Everything else Echo stores (questions, votes, AI cache) is private and only
reachable through [`openapi.yaml`](openapi.yaml).

The transcript is **pre-recorded and replayed as if live** (`team-captions-and-stt`): `backend/echo` (`make replay`)
writes the lines one by one at their recorded pace.

## Paths

| Path | Who can read | Shape |
| --- | --- | --- |
| `events/{eventId}/published/echo/sessions/{sessionId}` | signed-in, published events | `EchoSession` |
| `events/{eventId}/published/echo/sessions/{sessionId}/lines/{index}` | same | `TranscriptLine` (doc ID = `index`, zero-padded to 5 digits: `00000`, `00001`, …) |

```
EchoSession     { status: "live" | "ended", lineCount: int, language: "en", startedAt: timestamp, updatedAt: timestamp }
TranscriptLine  { index: int, atSeconds: int, text: string }
```

- `index` starts at 0 and has no gaps. `atSeconds` is the offset from the start of the talk (recorded time, not
  replay time).
- `language` is the language the talk is given in. Translations come from `translateTranscript`.
- `status` is `live` while lines are still being added and `ended` after the last one. No session doc means the talk
  has no transcript (yet).
- A new replay of the same session deletes the old lines first, then sets `lineCount` back to 0.

## Client rules

- Listen to `lines` ordered by `index`. Don't rely on `lineCount` to know what to render; it is for progress only.
- To translate, call `translateTranscript` with `fromIndex` = the first line you have no translation for.
- Mapping to the app model: `TranscriptLine.atSeconds` and `text` are the same fields as in
  `mobile/app/lib/data/models.dart`; `translated` comes from `translateTranscript`.
