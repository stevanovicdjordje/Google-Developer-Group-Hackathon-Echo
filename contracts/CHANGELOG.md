# contracts — CHANGELOG

> **Writer:** contracts owner only. Every change to `openapi.yaml`, `examples/` or any other contract file gets an entry here, newest first.
> Versions follow `info.version` in `openapi.yaml`: minor bump = additive, major bump = breaking (while < 1.0.0, breaking changes bump the minor version and are marked **BREAKING**).

## Entry format

```markdown
## <version> — YYYY-MM-DD
- **Impact:** additive | breaking | fixture-only
- **Affected:** backend, mobile, organizer-web
- **Requested by:** <request ID, e.g. mobile#1> / decision <file>
- **Changes:**
  - ADDED `operationId` — <method path> — <one line>
  - CHANGED `operationId` — <what changed>
  - REMOVED `operationId`
- **Consumer action:** <what each affected module must do>
```

---

## 0.0.0 — 2026-10-10
- **Impact:** none
- **Affected:** none
- **Changes:** Initial empty OpenAPI 3.1 skeleton (`paths: {}`). No operations agreed.
- **Consumer action:** none
