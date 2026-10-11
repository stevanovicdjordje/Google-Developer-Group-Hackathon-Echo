# Events: AI extraction of organizer uploads

- **ID:** `feature-events-ai`
- **Status:** accepted
- **Writer:** `feature:events` holder · @Vertiglo
- **Affects:** feature:events (backend/events); the app's organizer flow (latency, `model` field, accepted files)
- **Created:** 2026-10-11 · **Decided:** 2026-10-11 (requested by mobile in `mobile#17`)

## Context

Organizers upload whatever they have (agenda PDF, speaker spreadsheet, flyer photo) and the app shows an
extracted event to review and publish ("Build with AI", API-12/13). `mobile#17` asked for Gemini via `AI_MODEL`,
Gemma only for translation (`team-gemma-core`), and an honest `model` field. Upload formats are a team topic
(`team-import-formats`, still open); this decision covers how Events reads them.

## Decision

- **Model:** a Gemini model on the Gemini API, `AI_MODEL` (default `gemini-3-flash-preview`, thinking `low`), the
  same key as Echo and Find. PDFs and images go as inline data (the model reads them natively); XLSX, DOCX and text
  are converted to text on the server. JSON mode with a response schema.
- **Files:** PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX, detected by content; ≤10 files, 10 MiB each, 20 MiB
  together; not stored after extraction. Proposed to integration for `team-import-formats` (`events#1`).
- **No model / model fails:** spreadsheets and CSV with a header row are read deterministically (`model: offline`);
  anything else answers `503 ai_unavailable`. One extraction is cut at 60 s.
- **Untrusted output** (rule 12): schema-shaped JSON only, then cleaned and capped, times/dates normalised and
  checked; the organizer reviews and edits the draft, and only an explicit publish makes it public. Issues
  (missing stage/time, overlaps) are shown, never auto-fixed by the model.

## Consequences / follow-ups

- Extraction quality and latency with the real key are not measured yet (no key on @Vertiglo's machine).
- For the demo video, the files can be prepared so the extraction is known to work; the call path stays real.
