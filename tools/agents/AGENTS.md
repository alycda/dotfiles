# Agent Instructions (canonical entrypoint)

Canonical, cross-agent instruction surface. Codex/GPT-native tools read this
file directly (deployed at `~/.agents/AGENTS.md`, symlinked from
`~/.codex/AGENTS.md`); Claude-oriented tools load their (fuller) layers through
managed `@includes/` imports in `~/.claude/CLAUDE.md`. Keep substantive
instructions in the layers below, not inline here — this file is the
composition point, not the content.

This entrypoint is deliberately **context-frugal**: the surfaces that read it
(Codex, Hermes, small-window models) have far less context headroom than
Claude, so the default composition is the distilled persona core, not the full
constitution. Capability first; the full persona is one file-read away.

## Layers (lowest to highest precedence)

1. **Company values** — public, work-context baseline.
2. **Persona core** — public, distilled communication/working style plus the
   constitution's values as one-liners.
3. **Private overlay** — rage/age-encrypted, decrypted only on local machines,
   never committed as plaintext and never read into the Nix store.

Later layers refine earlier ones. The private overlay is authoritative where it
conflicts with the public layers.

## Composition

Public layers (home-anchored paths, so they resolve no matter where this file
is read from — `~/.agents/`, `~/.codex/`, or a paste):

@~/.agents/company-values.md
@~/.agents/persona-core.md

Surfaces that don't expand `@` imports: read those two local files, in that
order.

**On-demand: full personal constitution.** The complete constitution lives at
`~/.agents/personal-constitution.md`. Do **not** load it by default — read it
only when the task is persona-deep: reviewing my writing or talks, drafting
personal docs, or making judgment calls the one-liners in the persona core
can't settle.

**Private overlay.** When `~/.agents/instructions.private.md` exists, load it
too; it is authoritative where it conflicts with the public layers. Claude
surfaces get it via a managed import in `~/.claude/CLAUDE.md`, so it is
deliberately **not** imported here — on a fresh machine (age identity not yet
restored) the file is absent, and this public entrypoint must still load
cleanly on surfaces that treat missing imports as fatal. If the overlay is
absent: proceed with the public layers; never fetch anything remote to
substitute for it. See `README.md` for the deploy, decrypt, and capsule flows.
