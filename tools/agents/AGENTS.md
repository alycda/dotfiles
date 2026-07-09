# Agent Instructions (canonical entrypoint)

Canonical, cross-agent instruction surface. Codex/GPT-native tools read
`AGENTS.md` directly; Claude-oriented tools reach the same content through a
`CLAUDE.md` shim (`@AGENTS.md`) or through `~/.claude/includes/` symlinks. Keep
substantive instructions in the layers below, not inline here — this file is the
composition point, not the content.

## Layers (lowest to highest precedence)

1. **Company values** — public, work-context baseline.
2. **Personal constitution** — public, durable personal principles.
3. **Private overlay** — rage/age-encrypted, decrypted only on local machines,
   never committed as plaintext and never read into the Nix store.

Later layers refine earlier ones. The private overlay is authoritative where it
conflicts with the public layers.

## Composition

For Claude surfaces (which expand `@path` imports relative to this file):

@company-values.md
@personal-constitution.md
@instructions.private.md

On a fresh machine the private overlay may be absent (identity not yet present).
That is expected — proceed with the public layers rather than fetching anything
remote. See `README.md` for the deploy, decrypt, and capsule flows.
