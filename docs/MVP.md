# Eho — MVP: what we build for the demo video

> **Status: Agreed** by the team, 2026-10-10 (decision: [`decisions/product-hero-flow.md`](decisions/product-hero-flow.md)). The feature set itself is in [`PRODUCT.md`](PRODUCT.md).

## Demo strategy

- **The deliverable is a demo video of the happy path.** We build only what the video shows. Error states, edge cases and admin screens are out unless they're on camera.
- **What's on camera really runs.** Judges ask for "actual use, not a mockup", so the shown flow goes through the real app and backend, on **demo data** (one fake conference, ~20 fake attendees).
- **Hardcode only where a feature is genuinely hard and wouldn't otherwise make it.** Fake its *input* (e.g. a pre-recorded transcript), keep the rest real. Every hardcoded part is listed in the table below, so nobody is surprised.
- **Gemma must be real** wherever the video says "AI". It's the core judging requirement. If Gemma hosting is slow, precompute answers for the demo data, but the call path must exist.
- **Everything else is design only:** screens in the design, with a short note on how we'd implement it.

## The video storyline (happy path)

1. **Organizer** opens the organizer web, uploads a messy agenda PDF + speaker list → Gemma extracts stages, sessions and speakers → organizer glances at the result → **Publish** → gets the **join link + QR**.
2. **Attendee** scans the QR / opens the link → the event opens (in the browser if the app isn't installed) → **onboarding**: name, interests, what they're looking for, consent switches.
3. **Agenda** → picks a talk → **Map** shows the stage → taps through.
4. **Echo** during the talk: the transcript rolls in → attendee submits a **Q&A** question → **Asks** the AI about something the speaker said, and gets a grounded answer.
5. After the talk: **Summary** → "unlock" (mock paywall) → AI summary.
6. **Find**: recommendations ("3 people you should meet, and why") → a **prompt search** ("someone who has shipped on-device ML") → **Contact** a match.
7. **Profile → My events**: the event is listed there (plus a second, older demo event).

## Feature status

| Feature | For the video | Hardcoded / faked part | Gemma? |
| --- | --- | --- | --- |
| Organizer upload → AI extraction → publish → link/QR | **Build** | Files are prepared demo files. Extraction may be precomputed if Gemma is slow. | ✅ extraction |
| Join via link/QR (opens in browser) | **Build** | — | — |
| Attendee onboarding | **Build** | — | — |
| Agenda tab | **Build** | Data comes from the published demo event | — |
| Map tab (venue plan, stages, search) | **Build** (Vertiglo, `mobile/maps`) | Seeded venue | — |
| Echo: transcript | **Build, faked input** | A pre-recorded transcript is replayed as if live. Real live speech-to-text is a stretch. | — |
| Echo: Q&A | **Build** | — | optional: group similar questions |
| Echo: Ask the talk | **Build** | — | ✅ answers from the transcript |
| Talk summary (paid) | **Build** | Paywall is a mock "unlock" button, no real payment | ✅ summary |
| Find: recommendations | **Build** | ~20 fake attendee profiles | ✅ ranking + "why" |
| Find: prompt search | **Build** | Same fake profiles | ✅ (or EmbeddingGemma) |
| Contact a match | **Build, minimal** | A "contact request sent" state. No real messaging. | — |
| Profile tab + My events | **Build** | Second "past" event is seeded | — |
| Chat between matches | Design only | — | — |
| Meeting spot on the map (both opted in) | Design only | — | — |
| Opening the native app from a link (app links) | Design only | The browser path is enough for the video | — |
| Organizer dashboard / stats | Design only | — | — |
| Live translation / multilingual captions | Design only | — | — |
| Real payments | Design only | — | — |

## Not in the demo

Real payments, live speech-to-text, chat, live location of people, organizer analytics, multi-organizer accounts.
