# mobile/AGENTS.md

Scoped rules for agents working on the attendee app. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable:** `mobile/**` (including `mobile/STATUS.md`) and `docs/decisions/mobile-*.md`
- **Read-only:** everything else (`../contracts/**`, `../docs/**`, `../backend/**`, `../organizer-web/**`, root files)

First line of every session: `My write scope is mobile/** + docs/decisions/mobile-*.md`.

## What other modules expect from you (keep it current in `STATUS.md`)

- **Stack** and how a teammate builds/installs a demo build.
- **Join link / deep-link** handling, once `team-event-join` is decided.
- **Contract coverage:** which operations you consume, and whether you're on fixtures, the real API, or verified end-to-end.
- **Outbound requests** for any endpoint/field you need (to `contracts`) or backend behavior (to `backend`).

## What to watch at each sync

- `contracts/CHANGELOG.md` and `contracts/STATUS.md`: new or changed operations you consume.
- `backend/STATUS.md` → *How to consume*: base URL, dev auth, AI latency/timeouts.
- `organizer-web/STATUS.md`: join QR/link format it generates.
- Decisions: `team-event-join`, `team-auth`, `product-hero-flow`, `contracts-realtime-transport`, `team-captions-and-stt`.

## Module rules

1. **Stack: Flutter** (`docs/decisions/mobile-stack.md`, accepted). App shell in `mobile/app/`, feature packages in `mobile/<feature>/`.
2. **Mock-first.** UI must run on fixtures (`../contracts/examples/`) or local mocks while the backend isn't ready. Don't block on the backend.
3. **The contract is the boundary.** Consume only what `../contracts/openapi.yaml` defines. Need more? Open an outbound request. Don't invent backend behavior.
4. **No direct AI provider calls and no provider keys in the app**, unless an accepted decision says otherwise.
5. **Privacy:** networking visibility is opt-in; no precise location; don't log personal data (`../docs/DATA_PRIVACY.md`).
6. **One theme.** Colors, fonts and spacing come from `mobile/app/lib/core/theme.dart` via `Theme.of(context)`. Don't hardcode colors or text styles in screens, so the design pass is a theme change (exception: the white background behind QR codes).
7. **Data behind interfaces.** Screens read data only through the repositories in `mobile/app/lib/data/`. Demo data stays in `demo_data.dart`; swapping to a real endpoint is a provider change (`mobile/docs/api-needs.md`).
8. **Feature folders** (`mobile/maps/`, …) belong to their feature holders. Don't edit them; send a request.
9. **Workflow:** mobile work runs through an orchestrator session plus worker subagents (`mobile/docs/WORKFLOW.md`, agents in `.claude/agents/mobile-*.md`). The task board is `mobile/docs/BOARD.md`.
10. Stage with `git add -- mobile/ docs/decisions/mobile-*.md`.
