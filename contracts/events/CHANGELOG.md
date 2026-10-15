# contracts/events — CHANGELOG

Events feature contract. Same entry format as [`../CHANGELOG.md`](../CHANGELOG.md).

## 0.1.0 — 2026-10-11
- **Impact:** additive (new contract)
- **Affected:** backend/events (implements), mobile/app (consumes: `EventRepository`, `OrganizerRepository`)
- **Requested by:** mobile#17 (`mobile/docs/api-needs.md` API-1, 2, 3, 12, 13, 14)
- **Changes:**
  - ADDED `getPublicEvent`, `joinEvent`, `leaveEvent`, `listMyEvents`, `getAgenda`
  - ADDED `createDraft` (multipart upload → AI draft), `getDraft`, `updateDraft`, `publishDraft` (into the venue map's event ID, or a new event)
  - ADDED fixtures in `examples/` (demo agenda = the app's demo data), validator `scripts/validate_examples.py`
- **Consumer action:** mobile wires the repositories when ready; the app keeps demo data until then.
