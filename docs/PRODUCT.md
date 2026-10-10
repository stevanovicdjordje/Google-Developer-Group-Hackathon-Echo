# Eho — Product (draft)

> **Status: Draft.** This document describes the team's current *intent*. Nothing here is implemented, and nothing here has been validated with real users yet. Every product area is marked **Proposed** and **Unvalidated** until the team decides otherwise. Keep "we want it to" separate from "it does".

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

## Vision (working, non-binding)

Eho is a multi-event platform used by **attendees** and **organizers**. It gives everyone at an event a contextual AI layer, powered by Gemma, over that event's content: the agenda, venue, talks and people.

### What counts as an "event"

Primarily **conferences** (multi-track, talks, rooms, speakers). Meetups, fairs and other events are possible later. Whether Eho generalizes to them is an open question.

## Users

### Roles

1. **Attendee / visitor:** joins an event, uses the agenda and map, follows transcripts/captions, asks questions, and optionally networks.
2. **Organizer:** creates and configures an event, uploads information and files, assigns rooms, sessions and speakers, and may manage captions, questions and insights.

Speakers are a stakeholder in the challenge, but they are not a separate app role yet (open question).

### Personas — `hypothetical`

> These personas are **hypothetical** assumptions written for planning. They are **not** based on interviews. Replace or adjust them once `USER_RESEARCH.md` has real findings.

- **Hypothetical attendee: "first-time conference visitor."** Wants to find relevant talks quickly, doesn't know the venue, may not follow every talk in its language, and is hesitant to approach strangers.
- **Hypothetical attendee: "professional networker."** Comes to meet specific kinds of people and wants to find them without trawling a badge list.
- **Hypothetical organizer: "small team running a community conference."** Has the agenda in spreadsheets/PDFs, little time to build an app, and wants to know which sessions resonated and what people asked.

### Users vs. buyers (open question)

The working assumption is that attendees are the *users* and organizers (or event companies) are the *buyers*. This has not been validated. See Business below.

## User journeys (proposed)

1. **Organizer creates an event and imports files.** Signs in → creates an event → uploads agenda / speaker list / venue map / slides → reviews what was parsed → publishes → gets a join QR/link.
2. **Attendee joins and orients.** Scans QR / opens link → light onboarding (language, interests, optional goal) → sees the agenda and the venue map.
3. **Attendee follows a talk and asks.** Opens a session → follows the transcript/captions → asks a question to the speaker (Q&A) or "asks the talk" (an AI answer grounded in the transcript/slides).
4. **Attendee networks (opt-in).** Chooses to be visible → searches in natural language ("someone working on on-device ML") → sees matching opted-in people.
5. **Organizer sees interactions.** Dashboard of sessions, incoming/clustered questions and per-room content; possibly post-event insights.

## Product areas

| Area | Status | Notes / open questions |
| --- | --- | --- |
| Join via QR / link | Proposed · Unvalidated | Anonymous join vs. account? Event codes? |
| Organizer onboarding + file import | Proposed · Unvalidated | Which formats? How much parsing does Gemma do vs. manual review? Distinct from attendee onboarding. |
| Attendee onboarding | Proposed · Unvalidated | Interests, language, goal, optional networking profile; minimize data collected. |
| Agenda | Proposed · Unvalidated | Sessions, times, rooms, speakers, details. |
| Venue map | Proposed · Unvalidated | MVP candidate: static SVG/image with clickable rooms. No real-time indoor positioning. |
| Transcription / captions | Proposed · Unvalidated | STT + optional translation + Gemma context. High risk: latency, Serbian quality, audio input. |
| Live Q&A / "ask the talk" | Proposed · Unvalidated | Semantic clustering of questions, and/or answers grounded in the transcript. |
| Networking | Proposed · Unvalidated | Natural-language people search; explicit opt-in; cold-start problem; no location tracking. |
| Organizer dashboard | Proposed · Unvalidated | Sessions, questions, per-room content, possible metrics/reports. |

**Not all of these are MVP.** See `MVP.md` for the proposed demo slice and the selection criteria.

## Business (to be researched)

Nothing below is researched yet. These are questions to answer before the pitch:

- Who pays: organizers, venues, sponsors, attendees? Per-event, per-attendee, or subscription?
- Who are the competitors (event apps, conference platforms, captioning tools), and how does Eho differ?
- What does running it cost (Gemma inference, STT minutes, hosting), per event and per attendee?
- What would expansion beyond the local (Serbian/regional) market look like? Is multilingual support a differentiator?

## Known risks

- **Scope** is the biggest risk with ~24h and 4 people.
- **STT and live translation**: latency, terminology quality, Serbian/multilingual support, audio capture, streaming.
- **Gemma hosting** is not guaranteed: GPU availability, Cloud Run GPU / vLLM setup, cost, quotas.
- **Networking cold start** and privacy expectations.
- **Uploaded content and transcripts** may contain personal or confidential data. See `DATA_PRIVACY.md`.
- **Honesty:** we must not invent research, statistics, partners or feature status in docs or the pitch.
