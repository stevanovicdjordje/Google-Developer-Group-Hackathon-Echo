# Organizer import formats

- **ID:** `team-import-formats`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** organizer-web, backend
- **Created:** 2026-10-10 · **Decided:** 2026-10-11

## Context

Organizers upload agenda, speakers, map and slides. Formats, validation and parsing are undecided.

## Options

- CSV / spreadsheet
- PDF + Gemma-assisted extraction
- Manual entry as fallback

## Decision

**Organizers upload unstructured files; AI extracts the event; the organizer reviews before publishing.** Accepted as implemented by `feature:events` 0.1.0 (@Vertiglo, `feature-events-ai`):
- Formats: **PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX**.
- Limits: ≤ 10 files, ≤ 10 MiB each, ≤ 20 MiB total.
- AI extraction (Gemini, per `docs/MVP.md`) produces stages, sessions and speakers; spreadsheets (XLSX/CSV) can also be parsed without AI.
- Nothing is published until the organizer reviews the draft (review screen in the app).

Recorded by @Ilij4n (integration) on request `events#1`.

## Consequences / follow-ups

- Defines the upload operation in the contract and the backend's validation rules.
