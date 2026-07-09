# Agent instruction distribution overlay

A two-layer system for one canonical set of agent/chat instructions that can be
pushed across surfaces (Claude Code, Codex, desktop/mobile GUIs, API/CI
wrappers) **as local plaintext files, never as a URL an agent is told to fetch**.

This replaces the old "public HackMD note as the runtime source" pattern, which
had recurring failure modes: rate-limited fetches, models reasoning away
"read this URL first", re-fetching stable context, and exposing the shape of the
behavioral control surface publicly. HackMD can remain a read-mostly mirror for
sharing; it is no longer the canonical runtime source. Mirror links live here
(non-runtime docs), never inside the layer files themselves — the layers are
runtime prompt content and must not carry remote-source pointers:

- Personal constitution mirror: <https://hackmd.io/@alyda/BySssxZGGx>

See issue [#40](https://github.com/alycda/dotfiles/issues/40).

## The split

| Layer | File (repo) | Deployed to | Public? |
|-------|-------------|-------------|---------|
| Canonical entrypoint | `AGENTS.md` | `~/.agents/AGENTS.md` | yes |
| Company values | `company-values.md` | `~/.agents/company-values.md` | yes |
| Personal constitution | `personal-constitution.md` | `~/.agents/personal-constitution.md` | yes |
| Private overlay | `../../secrets/personal/agent-instructions.age` | `~/.agents/instructions.private.md` | **no — encrypted** |

- **Two public layers.** `company-values.md` (work context) and
  `personal-constitution.md` (durable personal principles) are sanitized and safe
  to publish. Nothing sensitive goes in them.
- **One encrypted overlay.** Everything else — the private, machine-specific, or
  sensitive instructions — lives in the rage/age-encrypted overlay. It is
  decrypted **only on local machines** to a stable home path and is never
  committed as plaintext, never read into the Nix store.

`AGENTS.md` is the canonical surface; later layers refine earlier ones, with the
private overlay authoritative on conflict.

## How it deploys (Home Manager / Nix)

`home-manager/modules/tools/agents.nix`:

- copies the three public files to `~/.agents/`,
- wires the encrypted overlay through agenix and exposes the **decrypted**
  plaintext at `~/.agents/instructions.private.md` via agenix's per-secret
  `path` — the plaintext lives in the agenix runtime dir, **not** the Nix store,
- creates Claude include symlinks under `~/.claude/includes/` pointing at the
  `~/.agents/` paths (out-of-store symlinks, so decryption/edits flow through one
  place),
- idempotently appends the `@includes/agents-*.md` imports to
  `~/.claude/CLAUDE.md` so Claude actually loads the layers,
- symlinks `~/.codex/AGENTS.md` to the canonical entrypoint so Codex loads it
  natively.

> **Store-safety invariant:** never `builtins.readFile` the overlay or generate a
> store path containing decrypted instructions. The plaintext only ever exists at
> the agenix runtime path and the symlinks that point at it.

## Creating / editing the private overlay

The committed `agent-instructions.age` ships a harmless placeholder so activation
works out of the box. Replace it with your real private instructions locally:

```sh
# edit in place — decrypts, opens $EDITOR, re-encrypts to the recipients in
# secrets/secrets.nix (never writes plaintext to disk)
agenix -e secrets/personal/agent-instructions.age
```

The recipient is the age public key already declared in `secrets/secrets.nix`.
Decryption on a machine requires the private identity at
`~/.age/personal-key.txt` (same identity used for `git-config.age`).

## Surface integration

- **Claude Code.** Managed — no manual step. Activation idempotently appends
  these local imports (never a URL) to `~/.claude/CLAUDE.md`, after the
  include symlinks exist (same pattern as the outbound-comment gate):

  ```md
  @includes/agents-company-values.md
  @includes/agents-personal-constitution.md
  @includes/agents-instructions.private.md
  ```

  On a fresh machine the private include may briefly dangle until agenix
  decrypts during activation — that is expected; Claude Code skips
  unresolvable imports and the public layers still load.

- **Codex / GPT-native.** Managed — the module symlinks `~/.codex/AGENTS.md`
  (Codex's native path) to `~/.agents/AGENTS.md`. A pre-existing hand-edited
  `~/.codex/AGENTS.md` is adopted as `AGENTS.md.hm-backup`
  (`home-manager.backupFileExtension`); fold anything you still need from it
  into the layers or the private overlay.

- **API / CI wrappers.** Concatenate the local file contents directly into the
  system prompt. Do **not** instruct the model to fetch HackMD from CI/API paths
  unless the task specifically needs external research.

- **GUI / mobile (no programmable insertion point).** Generate a paste capsule
  from the same source:

  ```sh
  just agents-capsule   # print the compiled capsule to stdout
  just agents-copy      # copy it to the clipboard (macOS pbcopy)
  ```

  The capsule carries a header with date and git short-hash so drift is visible.

## Restore flow on a new machine

1. Clone dotfiles and ensure the age identity exists at `~/.age/personal-key.txt`.
2. Run a home-manager switch. Public layers deploy immediately; the overlay
   decrypts to `~/.agents/instructions.private.md`.
3. Verify: `ls -l ~/.agents ~/.claude/includes ~/.codex/AGENTS.md`,
   `grep agents- ~/.claude/CLAUDE.md`, and `just agents-capsule`.

## Non-goals

- Do not make public HackMD the canonical instruction source.
- Do not commit decrypted private instructions.
- Do not rely on model obedience to fetch or cache remote context.
- Do not over-centralize tool-specific behavior that belongs in Claude skills,
  Hermes profiles, or Codex-specific instructions.

## Follow-up (not in this change)

The plugin-distribution catalog discussed in issue #40's comments (declaring
desired plugin state under `tools/agents/plugins/` rather than committing
`.claude/plugins` caches) is a separate concern and intentionally left for a
later increment.
