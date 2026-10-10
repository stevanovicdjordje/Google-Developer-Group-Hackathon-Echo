# Eho — Data and privacy (draft)

> **Status: Draft. No compliance is claimed.** A **GDPR review is needed** before any real event or real attendee data is used. This document sets working principles for the hackathon.

## Data categories and sensitivity

| Data | Examples | Sensitivity | Notes |
| --- | --- | --- | --- |
| Organizer uploads | Agenda, speaker list and bios, venue map, slides | Low–Medium | Bios and slides may contain personal or confidential info; private by default. |
| Transcripts / captions | Speech-to-text of talks | Medium–High | May include personal remarks or unpublished content; requires speaker/organizer consent to record and process. |
| Audience questions | Q&A submissions | Medium | May be personal; decide whether they are anonymous by default. |
| Attendee profile | Language, interests, goals | Medium | Collect the minimum needed. |
| Networking profile | Name, role, skills, what they're looking for | High | **Opt-in only**; visible only to other opted-in attendees of the same event. |
| Auth data | Accounts, tokens | High | Handled by the auth provider (TBD); never logged. |

## Principles

- **Opt-in for networking.** Attendees are not visible to others unless they explicitly choose to be, and they can withdraw at any time.
- **Basic access control.** Server-side role checks: attendees see their own event's content; organizers see their own events only; networking data is visible only to opted-in peers.
- **Data minimization.** Only collect what a feature actually uses.
- **Minimal retention.** Define how long transcripts, questions and profiles are kept after an event (TBD). The default intent is short retention.
- **Consent.** Speakers/organizers consent to recording and transcription; attendees consent to profile use.
- **Deletion.** Users can delete their profile and networking data; organizers can delete an event and its uploads.
- **No hidden profiling or tracking.** No heatmaps, indoor location tracking or automatic profiling of attendees without explicit consent *and* a clear justification. None of this is planned.
- **AI processing.** Be transparent when content is processed by Gemma or STT. Don't send more personal data to models than a feature needs. Treat model output as untrusted.

## Hackathon practice

- Use **fake or explicitly permissioned** demo data.
- No real personal data in `contracts/examples/` or anywhere in git.
- Never commit secrets: `.env`, keys and credentials are git-ignored.

## Open questions

- Where is data stored (region), and with which provider?
- Is Q&A anonymous by default?
- Retention periods per data type.
- Who is the data controller in a real deployment (organizer vs. Eho)?
