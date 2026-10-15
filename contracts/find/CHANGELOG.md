# contracts/find — CHANGELOG

Find feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

## 0.2.0 — 2026-10-11
- **Impact:** additive
- **Affected:** backend/find (implements), mobile (may send/read)
- **Requested by:** `mobile#13` (1)
- **Changes:**
  - ADDED optional `time` ("HH:mm", 24 h) on `MeetingSpotRequest` and `MeetingSpot`
- **Consumer action:** optional: send the meeting time with `putMeetingSpot` instead of keeping it on the device.

## 0.1.1 — 2026-10-11
- **Impact:** fixture-only
- **Affected:** mobile (reads examples)
- **Changes:**
  - ADDED `examples/profile-input.json` as the `putMyProfile` request example (the old one carried `updatedAt`);
    `examples/profile.json` is now its response example
  - Documented that unknown request fields (e.g. `updatedAt` sent back) are ignored
- **Consumer action:** none.

## 0.1.0 — 2026-10-11
- **Impact:** additive (new contract)
- **Affected:** backend/find (implements), mobile (consumes)
- **Requested by:** `mobile#5` (API-9, API-10, API-11, API-15, profile part of API-14), `mobile#12`
- **Changes:**
  - ADDED profile with consent switches: `getMyProfile`, `putMyProfile`, `deleteMyProfile`
  - ADDED event presence: `joinFind`, `leaveFind` (a profile is listed at an event only while present and `visibleInFind`)
  - ADDED AI people matching: `getRecommendations` (API-9, from the saved profile), `searchPeople` (API-10)
  - ADDED `getPerson` with `allowContact` and `contactState`
  - ADDED contacts: `listContacts`, `requestContact` (API-11), `acceptContact`
  - ADDED meeting spot: `putMeetingSpot` (API-15, a feature name on the published venue map), `deleteMeetingSpot`
- **Consumer action:** save the profile with `putMyProfile`, call `joinFind` when the attendee opens an event, then
  switch `FindRepository` to these operations. Differences from the suggestion in `api-needs.md`: recommendations use
  the **saved** profile (no profile in the request), results are wrapped as `{matches, model}`, and the server
  auto-accepts contact requests to seeded demo attendees (no client-side auto-accept needed).
