# Eho — Product

> **Status:** the feature set below was **agreed by the team** on 2026-10-10. It has **not been validated with real users** yet (see `USER_RESEARCH.md`). What is actually built is tracked in each module's `STATUS.md`, not here. Keep "we want it to" separate from "it does".

## Challenge

**"Reimagine the Event Experience with Gemma"** (GDG Belgrade hackathon).

Core question: *How can AI improve events for attendees, speakers and organizers?*

Expected: a meaningful use of Google **Gemma** models, plus other Google technologies where they genuinely add value.

### Judging criteria

From the organizers' grading PDF. Four areas with five questions each:

**Problem**
1. Is the problem clearly defined?
2. Is the defined problem relevant to the competition?
3. User feedback: (a) Did the team conduct research involving real users? (b) Did the team take the findings into account and adapt the application accordingly?
4. Did the team adequately address the identified problems?
5. What is the potential for expansion beyond the local market?

**Technology**
1. Are the architecture and high-level components defined? What Google technologies are used?
2. Have all components been implemented?
3. Has at least one problem encountered during implementation been highlighted, along with how it was resolved?
4. Did the team present actual use of the application (not a mockup)?
5. How scalable is the solution in its current state?

**Business**
1. Are target personae and market need clearly defined?
2. Did the team research the market and competition?
3. Is there a sustainable monetization model and realistic revenue?
4. What are the cost and resources needed for development?
5. Who are the users? Who are the buyers?

**Delivery**
1. Is the presentation visually consistent?
2. Does the presentation contain all the necessary information? Is it overcrowded?
3. Does the pitch contain all the necessary information?
4. How engaging was the pitch?
5. Was the complete pitch delivered in time?

Implications for us: we need real user research (`USER_RESEARCH.md`), a **working** demo, one clearly explained technical problem and its fix, defined users vs. buyers, and a story about how Eho could work beyond the local market.

## Vision (agreed by the team, 2026-10-10)

Eho is a multi-event app for **attendees** and **organizers**. An organizer drops in their messy event files, and AI (Gemma) turns them into an event with a join link. Attendees join through that link and get an AI layer over the event: the agenda, the venue, the talks and the people worth meeting.

Primarily **conferences** (talks, stages, speakers). Other event types may come later.

## Users

1. **Attendee:** joins events via a link/QR, follows the agenda and map, uses Echo during talks, finds people to meet.
2. **Organizer:** uploads event files, reviews what the AI extracted, publishes, and shares the join link.

Speakers are a stakeholder but not a separate role yet.

### Personas — `hypothetical`

> These personas are **hypothetical** assumptions written for planning. They are **not** based on interviews. Replace or adjust them once `USER_RESEARCH.md` has real findings.

- **Hypothetical attendee: "first-time conference visitor."** Wants to find relevant talks quickly, doesn't know the venue, may not follow every talk, and is hesitant to approach strangers.
- **Hypothetical attendee: "professional networker."** Comes to meet specific kinds of people and wants to find them without trawling a badge list.
- **Hypothetical organizer: "small team running a community conference."** Has the agenda in spreadsheets/PDFs, little time to build an app, and wants to know what people asked.

## The app (agreed feature set)

### Attendee app: tabs

| Tab | What it does |
| --- | --- |
| **Agenda** | Sessions per stage and time, speakers, session details. From a session you open its Echo screen. |
| **Map** | The venue plan: stages, rooms, stands, search, details (Vertiglo's venue map). Also shows the meeting spot you agreed on with a match, never anyone's live position. |
| **Find** | People to meet. Two ways: **recommendations** (the AI ranks opted-in attendees by your interests), and a **prompt search** ("someone who has shipped on-device ML"), where the AI returns attendees who fit. Each result says *why* it matched and has a **Contact** button. |
| **Profile** | Your interests and what you're looking for (used by Find), your visibility/consent switches, and **My events**. |

### Cross-cutting features

| Feature | What it does |
| --- | --- |
| **Echo** (per session) | Live transcript of the talk (translatable into your language), **Q&A** (submit questions to the speaker), and **Ask**: ask the AI about the talk and get an answer grounded in the transcript. |
| **Talk summary** (paid) | After a talk, an AI summary of what was said. Planned as a **premium feature** (the monetization hook). For the demo the paywall can be a mock "unlock" button. |
| **Join via link / QR** | Opens the event. The link is a normal web address, so it works in the browser when the app isn't installed. |
| **Attendee onboarding** | First time: name, interests, what you're looking for, and consent (be visible in Find, allow contact). |
| **My events** | All events you joined via links. Switch between them, leave one. |
| **Contact a match** | Send a contact request; once accepted, a **Messages** screen and the option to agree on a **meeting spot** shown on the Map. Both sides must have opted in. |
| **Organizer web** | Upload unstructured files (PDF, docs, spreadsheets, images of the agenda) → the AI extracts sessions, speakers, stages → the organizer reviews/edits → publish → gets the **signup link + QR**. |

### Status of each feature in the demo

See [`MVP.md`](MVP.md): almost everything is **built for the video** on demo data. Only messaging, payments and live speech-to-text are mocked.

## Business (to be researched)

Nothing below is researched yet. These are questions to answer before the pitch:

- **Working assumption (not validated):** organizers pay to run an event on Eho; attendees can pay for **talk summaries** (premium). Both need checking with real users.
- Who pays: organizers, venues, sponsors, attendees? Per-event, per-attendee, or subscription?
- Who are the competitors (event apps, conference platforms, captioning tools), and how does Eho differ?
- What does running it cost (Gemma inference, STT minutes, hosting), per event and per attendee?
- What would expansion beyond the local (Serbian/regional) market look like? Is multilingual support a differentiator?

## Known risks

- **Scope** is the biggest risk with ~24h and 4 people.
- **STT and live translation**: latency, terminology quality, Serbian/multilingual support, audio capture, streaming.
- **Gemma hosting** is not guaranteed: GPU availability, Cloud Run GPU / vLLM setup, cost, quotas.
- **Networking cold start** and privacy expectations: Find only works if enough people opt in.
- **Uploaded content and transcripts** may contain personal or confidential data. See `DATA_PRIVACY.md`.
- **Honesty:** we must not invent research, statistics, partners or feature status in docs or the pitch.
