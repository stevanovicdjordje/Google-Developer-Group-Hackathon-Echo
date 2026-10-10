# Eho — Onboarding (teammates and their AI agents)

Read this once (~10 minutes). After that, the agent instructions in the repo carry the rest.

**How we work, in one paragraph:** each of us owns one or more modules (`docs/OWNERSHIP.md`). You open **your module** in your IDE and run your AI agent from the **repo root**, so it can read everything but only writes in your module. Agents never talk to each other directly. They coordinate through files pushed to `main`: every module keeps a `STATUS.md` (state, how to use it, announcements, requests), decisions live in `docs/decisions/`, and the API lives in `contracts/`. The full protocol is [`docs/COORDINATION.md`](docs/COORDINATION.md). Your agent follows it automatically.

---

## 1. One-time setup

1. **Accept the invite:** https://github.com/Ilij4n/eho/invitations
2. **Clone:**
   ```bash
   git clone git@github.com:Ilij4n/eho.git      # or https://github.com/Ilij4n/eho.git
   cd eho
   ```
3. **Know your workstream** (`docs/OWNERSHIP.md`): `mobile`, `backend`, `organizer-web`, `contracts` (= contracts + integration), `product`. You may hold several.
4. **Turn on the scope guard.** This pre-commit hook blocks any commit that touches files outside your scope, whether a human or an agent made it:
   ```bash
   git config core.hooksPath .githooks
   git config eho.scope backend          # your scope(s), comma-separated, e.g. "contracts,product"
   ```
5. **(Claude Code users) Add deny rules** so Claude can't edit other modules with its file tools. Create `.claude/settings.local.json` in the repo root (it's git-ignored, so it's personal). Example for **mobile**. For another module, swap names so the list covers every area except yours:
   ```json
   {
     "permissions": {
       "deny": [
         "Edit(/backend/**)",
         "Edit(/organizer-web/**)",
         "Edit(/contracts/**)",
         "Edit(/docs/*.md)",
         "Edit(/docs/decisions/backend-*)",
         "Edit(/docs/decisions/organizer-web-*)",
         "Edit(/docs/decisions/contracts-*)",
         "Edit(/docs/decisions/product-*)",
         "Edit(/docs/decisions/team-*)",
         "Edit(/.github/**)",
         "Edit(/.githooks/**)",
         "Edit(/*.md)",
         "Edit(/.gitignore)",
         "Edit(/.editorconfig)"
       ]
     }
   }
   ```
   If the file already exists (Claude saves approvals there), merge the `deny` list into it. These rules cover Claude's file tools and common shell file commands, but not arbitrary scripts. That's why the hook and diff review still matter.
6. **Open your module in your IDE**, e.g. `mobile/` in Android Studio or `backend/` in WebStorm/VS Code.

## 2. Starting an agent session

Launch the agent from the **repo root**, not from your module. The IDE's built-in terminal is fine:

```bash
cd "$(git rev-parse --show-toplevel)"
claude          # or: codex
```

Why the root: the agent can read the whole repo without extra permissions, it loads all the shared rules and the coordination protocol at launch (verified), and the deny rules above line up with the paths.

If you do start Claude Code **inside your module** (e.g. your IDE plugin insists):
- Claude loads the root `CLAUDE.md` and your module's rules, but treats the root file's imports (`AGENTS.md`, `docs/COORDINATION.md`) as *external*. In an interactive session it asks once whether to allow them. **Approve.** If they still aren't loaded, the module's `CLAUDE.md` tells the agent to read them itself (verified).
- Deny rules in `.claude/settings.local.json` resolve `/path` against the launch directory, so the example above won't line up. Rely on the scope guard hook instead.
- Keep the scope line in the kickoff prompt.

Then paste the **kickoff prompt**.

## 3. Kickoff prompt (copy, fill in the scope line)

```text
You are the Eho <WORKSTREAM> agent. The current directory is the root of the Eho monorepo.
My write scope is <SCOPE LINE FROM THE TABLE BELOW>. Everything else is read-only for you.

1. Read AGENTS.md, docs/COORDINATION.md, docs/OWNERSHIP.md, and the AGENTS.md and STATUS.md of my module.
2. Run the session-start sync from docs/COORDINATION.md §2 and give me the sync report.
3. Then wait for my task. While working: whenever a change affects other modules, follow the change
   impact map (docs/COORDINATION.md §3) — record it at its source of truth, announce it in our STATUS.md,
   and push that coordination commit immediately. If you need something from another module, open a
   request in our STATUS.md instead of editing their files. Tell me when I should ping a teammate.
```

| Workstream | Scope line |
| --- | --- |
| Mobile | `mobile/** + docs/decisions/mobile-*.md` |
| Backend | `backend/** + docs/decisions/backend-*.md` |
| Organizer web | `organizer-web/** + docs/decisions/organizer-web-*.md` |
| Contracts / integration | `contracts/** + docs/decisions/contracts-*.md + docs/decisions/team-*.md + root rules files, .github/, .githooks/, docs/COORDINATION.md, docs/OWNERSHIP.md, docs/INTEGRATION.md, docs/DECISIONS.md` |
| Product / demo | `docs/** except other workstreams' decision files and the integration-owned docs` |

## 4. Handy phrases during a session

| You say | The agent does |
| --- | --- |
| "sync" | Fetches, reviews what teammates pushed, pulls, gives a sync report (`COORDINATION.md` §2) |
| "we decided X" | Records it: a decision file if your workstream owns it, otherwise a request to the owner (§3) |
| "ask backend for Y" | Adds an outbound request to your `STATUS.md` and pushes it (§4) |
| "wrap up" | Updates `STATUS.md`, commits only your paths, pulls, pushes, reports changed files and real test status (§7) |

## 5. Rhythm and etiquette

- **Commit small, push often, to `main`.** Module paths don't overlap, so trunk-based development is the low-friction option. Use a PR only for breaking contract changes, rule changes, or when you want a review.
- **Sync** at the start, before each new task, and every couple of hours.
- **When your agent posts an `ACTION` or `BREAKING` announcement, ping the affected teammate in chat.** Git is pull-based; they won't see it until their next sync.
- Never `--force`, never `--no-verify`, never edit someone else's module "just to fix one thing". Open a request.
- Secrets go in `.env` (git-ignored). Commit only `.env.example` with placeholders.

## 6. Where things are

| I want to know… | Look at |
| --- | --- |
| What a module can do right now / how to run it | `<module>/STATUS.md` |
| What the API looks like | `contracts/openapi.yaml`, `contracts/CHANGELOG.md` |
| What's been decided | `docs/decisions/` (`grep -H '^- \*\*Status' docs/decisions/*.md`) |
| What to update after a change | `docs/COORDINATION.md` §3 |
| What we're building and why | `docs/PRODUCT.md`, `docs/MVP.md` |
| Who owns what | `docs/OWNERSHIP.md` |
