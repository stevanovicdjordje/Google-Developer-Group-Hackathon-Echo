# Live speech-to-text for the live demo

- **ID:** `team-live-stt`
- **Status:** accepted
- **Writer:** Integration holder · @Ilij4n
- **Affects:** feature:echo, mobile, the live demo
- **Created:** 2026-10-11 · **Decided:** 2026-10-11 (by @Ilij4n)
- **Supersedes in part:** `team-captions-and-stt` (live STT moves from stretch goal to in scope; the replay stays as the fallback)

## Context

The team wants a **live demo**: a presenter speaks into a phone (Wi-Fi only, no SIM), and the jury on the attendee side sees the live transcript, translates it, asks the AI and sends questions to the presenter. Everything after "speech becomes text" already works (Firestore-streamed lines, Ask, Catch-up, Summary, Translate, Q&A). What's missing: speech-to-text, a way to append lines from outside the replay CLI, and Wi-Fi builds.

## Decision

1. **Speech-to-text runs on the speaker's phone**, using the platform's built-in recognizer (Android `SpeechRecognizer` / iOS Speech via a Flutter plugin). Finished utterances are sent as transcript lines. Why: no new accounts or keys, about 1 s latency, free. Gemma/Whisper/Gemini Live were considered too slow or too much work for the time left. They can come later behind the same line-ingest endpoint.
2. **Echo gets a live-ingest API** (feature:echo, request `mobile#24`): start a live session, append lines, end it. It's authenticated as the organizer and writes through the existing `ResetTranscript` / `AppendLine` store, so every attendee feature works unchanged.
3. **The app gets a "Speaker mode"** (mobile): mic → STT → lines, with a level/partial-text view, plus the session's top Q&A questions for the presenter.
4. **Wi-Fi builds:** the phones reach the Mac over the LAN (own hotspot/router recommended; venue Wi-Fi often isolates clients).
5. **Fallback:** the replay (`cd backend/echo && make replay EVENT=devfest`) stays one command away. The safe point is git tag `safe/pre-live-stt`.

## Consequences / follow-ups

- feature:echo: the live-ingest endpoints + contract (CHANGELOG, minor version).
- mobile: Speaker mode, the STT plugin, microphone permissions, a Wi-Fi build profile.
- `docs/MVP.md`: the Echo transcript row says live STT with the replay as fallback.
- Privacy: the presenter's speech is turned into text and stored as the session transcript (as the replayed one already is). No audio is stored or sent to our servers.
