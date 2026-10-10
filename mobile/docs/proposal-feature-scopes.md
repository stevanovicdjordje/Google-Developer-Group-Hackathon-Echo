# Proposal: feature scopes ("register for what you work on")

- **ID:** `mobile#4` (request to the integration holder, @Ilij4n's agent)
- **From:** @Vertiglo (venue map), 2026-10-10
- **Status:** proposed. Only the integration holder may apply it (it changes `AGENTS.md`, `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `ONBOARDING.md`, `.githooks/pre-commit`).

## Problem

Scopes are per module (`mobile`, `backend`, …). A feature such as the venue map spans the app, the server and the contract. To build it, one person has to hold several whole modules, which makes them the holder (and request recipient) for everything else in those modules (Gemma, captions, …) and blocks teammates who want those modules.

## Proposal

A teammate registers for **what they actually work on**: a module (as today) **or a feature**, `feature:<name>` (lowercase, e.g. `feature:maps`).

A feature holder may write these paths, and only these, in every module:

| Area | Feature paths |
| --- | --- |
| Feature home (STATUS, plan, notes) | `features/<name>/**` |
| Flutter app | `mobile/app/lib/features/<name>/**`, `mobile/app/test/features/<name>/**`, `mobile/app/assets/<name>/**` |
| Organizer web | `organizer-web/features/<name>/**` |
| Backend | `backend/<name>/**` (an independent service/module) |
| Contract | `contracts/features/<name>/**` (the feature's OpenAPI file, fixtures, realtime/deep-link docs, CHANGELOG) |
| Decisions | `docs/decisions/feature-<name>-*.md` |

Rules:

1. **Registration:** the agent sets `**Owner:** @<handle> · **Scopes held:** feature:<name>` in `features/<name>/STATUS.md` (same format as module STATUS files) and runs `git config eho.scope feature:<name>` (comma-combinable with module scopes).
2. **Module shells stay with the module holder:** files outside the feature paths (`pubspec.yaml`, `main.dart`, the app router, the root `contracts/openapi.yaml`, Firebase rules, CI) belong to the module. The feature holder asks via a request in `features/<name>/STATUS.md`.
3. **Unheld module → don't block:** if the module has no registered holder, the feature holder may make the **minimal additive** change it needs in that module's shell (a dependency, a route, a rules block), and must announce it as `ACTION` so the future module holder sees it.
4. **Features never edit each other's paths.** Shared code between features is a request to the module holder.
5. Everything else (sync, announcements, requests, contracts procedure) works as for modules; feature contract changes follow `contracts/AGENTS.md` with the feature holder acting as the contracts holder **for `contracts/features/<name>/` only**.

## Exact changes for the integration holder

### `.githooks/pre-commit`

Accept `feature:*` in the scope check and add a case to `allowed()`:

```sh
for s in $scopes; do
  case "$s" in
    all|mobile|backend|organizer-web|contracts|integration|product) ;;
    feature:[a-z0-9]*) ;;
    *) echo "eho scope guard: unknown scope '$s' in git config eho.scope" >&2; exit 1 ;;
  esac
done
```

```sh
    feature:*)
      f=${2#feature:}
      case "$1" in
        features/"$f"/*|backend/"$f"/*|contracts/features/"$f"/*|organizer-web/features/"$f"/*) return 0 ;;
        mobile/app/lib/features/"$f"/*|mobile/app/test/features/"$f"/*|mobile/app/assets/"$f"/*) return 0 ;;
        docs/decisions/feature-"$f"-*) return 0 ;;
      esac ;;
```

(Rule 3's shell edits in an unheld module are made with that module's scope added temporarily to `eho.scope` and announced; the agent records it in the feature STATUS.)

### `AGENTS.md` → scope table, add a row

`| feature:<name> | features/<name>/**, mobile/app/{lib,test}/features/<name>/**, mobile/app/assets/<name>/**, organizer-web/features/<name>/**, backend/<name>/**, contracts/features/<name>/**, docs/decisions/feature-<name>-*.md | — |`

and under it: "Register for what you work on: a module, or a feature (`feature:<name>`), see `docs/COORDINATION.md` §1a."

### `docs/COORDINATION.md`

- New §1a "Feature scopes" with the rules above.
- §2 step 2: "Work out your scopes: the module **or feature** your human named …"; step 3: "register in your primary module's or feature's `STATUS.md`"; step 5: deny rules for a feature holder deny every area except the feature paths.
- §3 sync: also read `features/*/STATUS.md`.

### `ONBOARDING.md` kickoff prompt

`I'm working on: <mobile | backend | organizer-web | product | feature:<name>>.` with an example: "`feature:maps` — only the venue map, in the app, the server and the contract."

### `docs/OWNERSHIP.md`

Add the `feature:<name>` row to the workstream table, and `grep -H '^\*\*Last updated' */STATUS.md features/*/STATUS.md` as the way to see holders.

## Migration for the venue map once accepted

- Move `mobile/docs/map-plan.md` → `features/maps/plan.md`, create `features/maps/STATUS.md`.
- Flutter map code is already in `mobile/app/lib/features/maps/`, backend in `backend/maps/`, contract in `contracts/features/maps/`.
- @Vertiglo releases the `mobile`, `backend` and `contracts` module scopes (Owner → TBD) and keeps only `feature:maps`.
