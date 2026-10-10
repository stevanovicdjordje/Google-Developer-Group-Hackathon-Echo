# backend/ — Eho API and AI services

> **Setup status: Not initialized yet — the module owner will initialize it.** There is no `package.json`, framework or source code here yet.

## Purpose

The single API that both the attendee app (`mobile/`) and the organizer web app (`organizer-web/`) talk to. It owns persistence, authorization, event content, and all AI provider integrations.

## Responsibilities (candidate)

- Implement the API agreed in [`../contracts/openapi.yaml`](../contracts/openapi.yaml), with request/response validation.
- Authentication and **role enforcement** (attendee vs. organizer). This is enforced server-side, never only in the clients.
- Event, agenda, room, session and speaker data.
- Organizer file import: accepted types, size limits, access checks, parsing. Formats are TBD.
- **Gemma adapter:** an isolated provider interface for LLM calls (Q&A, "ask the talk", summarization, question clustering — candidates).
- **STT adapter:** an isolated speech-to-text interface, kept separate from Gemma processing.
- Embeddings / retrieval (EmbeddingGemma is a candidate; the index/DB is TBD).

## Data and API it relies on

- Persistence: TBD (Firestore is a candidate, not decided).
- Gemma inference endpoint: TBD (local, self-hosted GPU, Cloud Run GPU / vLLM, or a Google-hosted endpoint). Nothing is provisioned.
- STT provider: TBD (Google Cloud Speech-to-Text is a candidate).

## AI integrations

All AI calls go through this module. Keep each provider behind an adapter so the hosting choice can change without touching the API. Treat model output as **untrusted**: validate it, and never let it produce SQL, call privileged functions, or bypass authorization.

## Open questions

- Language/framework: TypeScript/Node.js is a candidate; Fastify/NestJS/Express/other is TBD.
- Where Gemma runs, which model size, and what latency/cost is acceptable for the demo.
- Live captions: streaming transport, latency, and Serbian/multilingual quality. Or is it out of scope?
- Auth provider (Firebase Auth or other) and how an attendee joins (event code vs. account).
- Upload storage and the file formats we accept from organizers.
- Hosting for the demo (Cloud Run is a candidate; no billing has been set up).

## Setup

`Not initialized yet — module owner will initialize.` When initialized, document here: the runtime version, install/run commands, the `.env.example` variables (placeholders only), how to run a smoke test, and how to validate against `contracts/`.
