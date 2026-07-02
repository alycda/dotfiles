# Claude config — capture map

Snapshot of the live Claude Code state on the work machine (captured 2026-07-01),
tracked here so a lost laptop doesn't mean lost config. Deployment wiring lives in
`home-manager/modules/tools/claude.nix`; this directory is the source of truth for
content.

## What's tracked where

| Repo path | Live path | Notes |
|---|---|---|
| `tools/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions. Candidate for the work/home split (see plan note). |
| `tools/claude/settings.json` | `~/.claude/settings.json` | Union of the previously-tracked file and live drift: all 7 plugins, both marketplaces, full permission allowlist, `ask` block, `skipAutoPermissionPrompt`. |
| `tools/claude/commands/` | `~/.claude/commands/` | Cycle-retro workflow (`cycle-retro`, `decision`, `deferred`, `friction`, `surprise`, `win`) + `sync-learning-to-hackmd`. `cycle-retro.md` embeds a Linear team UUID — an opaque identifier, unusable without Linear auth, kept for functionality. |
| `tools/claude/skills/` | `~/.claude/skills/` (plain dirs) | Claude-Code-native skills. `researcher` / `sprint-*` here are the **Claude-native forks** (e.g. researcher `0.8.0-claude`) of the Hermes originals in `tools/agents/skills/` — the two variants are siblings, not drift. |
| `tools/agents/skills/` | `~/.agents/skills/` + Hermes | Cross-tool skills: the Hermes-flavored researcher/sprint set (pre-existing) plus `cmux-*` and `here-now` (captured; these may be re-installable by cmux/here.now themselves — tracked as backup). |
| `tools/claude/work-dir.settings.local.json` | `~/Work/.claude/settings.local.json` | Tiny per-directory permission widening (read-only Linear). |
| `tools/claude/claude.json` | `~/.claude.json` (trimmed) | Durable config only: global MCP servers (hackmd, token redacted) + deduped per-project MCP servers. The live file's 70+ runtime-state keys (session metrics, account/machine IDs, full worktree directory map) are deliberately stripped. |

## Promoted from `~/Work/ditto-worktree/.claude` (2026-07-01)

Project-level config that turned out to be the best version on the machine,
promoted to user level (`~/.claude`) and captured here:

- **Guardrail permissions** → merged into `settings.json`: `ask` before
  `gh pr review`, `gh issue comment`, Linear `save_status_update` / `Linear_2`
  variants; `allow` for read-only `claude_ai_Linear` tools.
- **`clean-git-history`**, **`failure-doc`** skills → `tools/claude/skills/`.
- **Sprint skills branch/worktree ledger tracking** — the ditto-worktree copies
  were the newest lineage (matching the Hermes `ledger.py`); folded into the
  Claude-native forks here.
- **`sdk-integration-expert` agent** → promoted locally to `~/.claude/agents/`
  but NOT tracked here: it's built on internal architecture/codenames. It needs
  either sanitization or a Ditto-internal home before it can be versioned.

## Deliberately NOT tracked (and why)

- **`~/.claude.json` verbatim** — see `claude.json` above for the trimmed capture.
  The `HACKMD_API_TOKEN` lives in plaintext in the live file and in
  `~/Library/Application Support/Claude/claude_desktop_config.json`. To restore:
  re-add the hackmd MCP server and supply the token from a secret store
  (agenix — see the `claude/add-agenix-secrets-*` branch — or 1Password).
- **`~/.claude/agents/sdk-integration-expert.md`** — internal content, see above.
- **`~/.claude/.credentials.json`, `history.jsonl`, `projects/`, `sessions/`,
  `file-history/`, `shell-snapshots/`** — credentials and session state.
- **`~/.claude/projects/-Users-alyssaevans/memory/`** — auto-memory contains
  internal Ditto plan/cost details; not public-repo material. Back it up privately
  if it grows beyond the current single file.
- **`~/.claude/skills/flutter-*`** — symlinks into `~/.claude/.cache/flutter-skills/`,
  a clone of `github.com/flutter/skills`. Regenerate by recloning; don't vendor.
- **Plugin marketplaces/repos under `~/.claude/plugins/`** — fully described by
  `extraKnownMarketplaces` + `enabledPlugins` in `settings.json`; Claude Code
  re-fetches them on first run.

## Sanitization

Repo copies of skill exemplars had internal Linear ticket IDs replaced with
`<INTERNAL-TICKET-A..E>` / `PROJ-*` placeholders (matching the existing convention in
`sprint-planner/SKILL.md`). The live files under `~/.claude/skills/` retain the real
IDs, so repo and live copies intentionally differ by exactly those tokens.
`failure-doc/SKILL.md` additionally had career-leveling details trimmed in the repo
copy (live copy untouched).

## Restore on a fresh machine

1. `darwin-rebuild switch` / `home-manager switch` deploys `settings.json` and the
   skills per `claude.nix`. Note home-manager will refuse to clobber pre-existing
   plain files at those paths — move them aside first on a machine that already ran
   Claude Code.
2. Launch `claude` once — plugins and marketplaces install themselves from settings.
3. Re-add the hackmd MCP token (see above). Copy `CLAUDE.md` / `commands/` if not
   yet wired into `claude.nix` on your branch.

## Known hazard

`claude.nix` (as of the `agents/claude-hermes-config` branch) symlinks
`~/.claude/skills/researcher` and `sprint-*` to the **Hermes** variants in
`tools/agents/skills/`. On this machine those live paths are plain directories
holding the Claude-native forks — a `home-manager switch` would replace forks with
Hermes originals (or fail on the collision). Repoint those symlinks to
`tools/claude/skills/` before the next switch.
