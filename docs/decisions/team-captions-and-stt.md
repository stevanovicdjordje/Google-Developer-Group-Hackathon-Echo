# Live captions in/out of scope; STT provider

- **ID:** `team-captions-and-stt`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

High-risk area: latency, Serbian/multilingual quality, audio capture, streaming.

## Options

- Out of scope for the demo
- Pre-recorded audio → transcript
- Live STT (Google Cloud Speech-to-Text or other)

## Decision

**For the demo, no live speech-to-text.** Echo's transcript is a **pre-recorded transcript replayed as if live**. Ask the talk, Q&A and summaries work on that transcript for real. Live STT (e.g. Google Cloud Speech-to-Text) stays a stretch goal behind the existing STT adapter idea.

Agreed by the team (relayed by @Ilij4n), 2026-10-10.

## Consequences / follow-ups

- Update `docs/MVP.md`; if in scope, triggers `contracts-realtime-transport.md`.
