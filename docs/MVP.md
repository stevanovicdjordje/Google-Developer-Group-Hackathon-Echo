# Eho — MVP: what we build for the demo video

> **Status: Agreed** by the team, 2026-10-10 (decision: [`decisions/product-hero-flow.md`](decisions/product-hero-flow.md)). The feature set itself is in [`PRODUCT.md`](PRODUCT.md).

## Demo strategy

- **The deliverable is a demo video of the happy path.** We build only what the video shows. Error states, edge cases and admin screens are out unless they're on camera.
- **What's on camera really runs.** Judges ask for "actual use, not a mockup", so the shown flow goes through the real app and backend, on **demo data** (one fake conference, ~20 fake attendees).
- **Build almost everything for real.** Mock only what is genuinely hard or needs heavy cross-module coordination (messaging, payments, live speech-to-text). Every mocked part is listed in the table below, so nobody is surprised.
- **AI: a model per feature.** Gemma (via the Gemini API) for translation; other models may be used for other features, whichever works best. Each feature calls its model through a backend adapter so it can be swapped. If a call is too slow on camera, precompute the answer for the demo data, but keep the real call path.

## The video storyline (happy path)

1. **Organizer** opens the organizer web, uploads a messy agenda PDF + speaker list → Gemma extracts stages, sessions and speakers → organizer glances at the result → **Publish** → gets the **join link + QR**.
2. **Attendee** scans the QR / opens the link → the event opens (in the browser if the app isn't installed) → **onboarding**: name, interests, what they're looking for, consent switches.
3. **Agenda** → picks a talk → **Map** shows the stage → taps through.
4. **Echo** during the talk: the transcript rolls in (and can be **translated** to the attendee's language) → attendee submits a **Q&A** question → **Asks** the AI about something the speaker said, and gets a grounded answer.
5. After the talk: **Summary** → "unlock" (mock paywall) → AI summary.
6. **Find**: recommendations ("3 people you should meet, and why") → a **prompt search** ("someone who has shipped on-device ML") → **Contact** a match → they accept → **Messages** screen → suggest a **meeting spot**, which shows on the Map.
7. **Profile → My events**: the event is listed there (plus a second, older demo event).

## Feature status

| Feature | For the video | Mocked / faked part | AI |
| --- | --- | --- | --- |
| Organizer upload → AI extraction → publish → link/QR | **Build** | Uses prepared demo files | ✅ extraction |
| Join via link/QR (opens in browser) | **Build** | — | — |
| Opening the installed app from a link (Android App Links) | **Build, last** | — | — |
| Attendee onboarding | **Build** | — | — |
| Agenda tab | **Build** | Data comes from the published demo event | — |
| Map tab (venue plan, stages, search) | **Build** (`feature:maps`, @Vertiglo) | Seeded venue | — |
| Meeting spot on the map | **Build** | — | — |
| Organizer stats | **Build** if time allows (`feature:maps` phase 7) | — | — |
| Echo: transcript | **Build, faked input** | A pre-recorded transcript is replayed as if live. Live speech-to-text is a stretch goal. | — |
| Echo: translation | **Build** | — | ✅ Gemma |
| Echo: Q&A | **Build** | — | optional: group similar questions |
| Echo: Ask the talk | **Build** | — | ✅ answers from the transcript |
| Talk summary (paid) | **Build** | **Mock** "unlock" button, no real payment | ✅ summary |
| Find: recommendations | **Build** | ~20 fake attendee profiles | ✅ ranking + "why" |
| Find: prompt search | **Build** | Same fake profiles | ✅ |
| Contact a match (request → accept) | **Build** | — | — |
| Messages screen | **Mock** | Static screen with a hardcoded conversation, shown on camera only | — |
| Profile tab + My events | **Build** | Second "past" event is seeded | — |

## Who builds what (2026-10-11)

| Area | Holder | Status |
| --- | --- | --- |
| App UI (all screens, design pass) | `mobile` · @Ilij4n | in progress |
| Venue map: viewer, editor, routing, GPS (`mobile/maps`, `backend/maps`) | `feature:maps` · @Vertiglo | in progress |
| Echo: transcript, translation, Q&A, Ask, summary (`backend/echo`, `contracts/echo`) | `feature:echo` · @MilosBG03 | in progress, wired into the app |
| **Events backend:** join, agenda, My events, organizer AI extraction + publish (API-1, 2, 3, 12, 13, 14) | **nobody yet** | the app runs these on demo data |
| **People backend:** Find recommendations + prompt search, contact requests, meeting spot (API-9, 10, 11, 15) | **nobody yet** | the app runs these on demo data |

Unowned rows: what the app needs is in `mobile/docs/api-needs.md`. Suggested scopes: `feature:events` and `feature:people` (`docs/COORDINATION.md` §1a).

## Not in the demo

Real payments, real messaging, live speech-to-text, live location of other people, multi-organizer accounts.
