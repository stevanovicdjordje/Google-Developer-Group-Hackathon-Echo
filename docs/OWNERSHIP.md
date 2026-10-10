# Eho — Ownership

## Team (GitHub)

| Handle | Repo access |
| --- | --- |
| `Ilij4n` | Admin (repo owner) |
| `stevanovicdjordje` | Write (accepted) |
| `Vertiglo` | Write (accepted) |
| TBD (4th member) | Not invited yet |

## Who holds which workstream

Holders **register themselves**: on their first session, each agent writes its human's handle and scopes on the `Owner` line of its module's `STATUS.md` (`docs/COORDINATION.md` §2). This table therefore doesn't track live owners. To see them:

```bash
grep -H '^\*\*Last updated' */STATUS.md contracts/*/STATUS.md
```

| Workstream (scope) | Owned paths | Publishes in | Fallback holder if nobody registered |
| --- | --- | --- | --- |
| `mobile` | `mobile/**`, `docs/decisions/mobile-*` | `mobile/STATUS.md` | — |
| `backend` | `backend/**`, `docs/decisions/backend-*` | `backend/STATUS.md` | — |
| `organizer-web` | `organizer-web/**`, `docs/decisions/organizer-web-*` | `organizer-web/STATUS.md` | — |
| `contracts` | `contracts/**`, `docs/decisions/contracts-*` | `contracts/STATUS.md`, `contracts/CHANGELOG.md` | Backend agent |
| `integration` | Root files, `.github/`, `.githooks/`, `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md`, `docs/decisions/team-*` | Holder's own `STATUS.md` | Repo owner's agent (`Ilij4n`) |
| `product` | Other `docs/**`, `docs/decisions/product-*` | `docs/MVP.md`, `docs/TASKS.md` | Repo owner's agent (`Ilij4n`) |
| `feature:<name>` | `<module>/<name>/**` in every module, `docs/decisions/feature-<name>-*` | `contracts/<name>/STATUS.md` | — (see `docs/COORDINATION.md` §1a) |

Once owners are stable, the integration holder may add `.github/CODEOWNERS` from the registered handles.

## Rules for shared changes

1. Write only in the scopes you hold. Everything else is read-only.
2. Need something elsewhere? The agent opens a request (`docs/COORDINATION.md` §5). The other agent handles it at its next sync, with no human involved unless §0 says so.
3. Contract changes go through the contracts holder, following `contracts/AGENTS.md`.
4. `team-*` decisions are high-level. Humans make them, and the integration holder records them.

## Escalation

1. Agents settle it themselves with the tie-break rules (`docs/COORDINATION.md` §5).
2. If that fails, each agent asks its human with a 🧭 that lays out both options.
3. The humans decide, and the outcome is recorded in `docs/decisions/`.
