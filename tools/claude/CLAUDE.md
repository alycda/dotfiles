<!--
  Global Claude Code instructions — MANAGED by alycda/dotfiles.

  Tracked at tools/claude/CLAUDE.md, deployed read-only to ~/.claude/CLAUDE.md by
  home-manager/modules/tools/claude-code.nix. Edit it HERE and run a switch; do
  not hand-edit ~/.claude/CLAUDE.md (it is a Nix store symlink). A pre-existing
  hand-edited file is adopted as ~/.claude/CLAUDE.md.hm-backup on first
  activation (home-manager.backupFileExtension) — fold anything you still want
  out of that backup into the layers, the private overlay, or this file.

  This file is the Claude-surface twin of ~/.agents/AGENTS.md. Both surfaces load
  the SAME canonical layers, so Claude Code, Claude Desktop (via
  `just agents-capsule`), and Codex (via ~/.codex/AGENTS.md) stay in one voice
  through the Anthropic→Codex migration. Replaces the old append-on-activation
  pattern (issue #40) with a fully declarative file.

  ── PUBLIC vs SECRET — the decision this file exists to make ──
  Everything in THIS file is committed to the public repo. So:
    • Portable, shareable instruction → put it in a LAYER
      (tools/agents/company-values.md or personal-constitution.md) so Codex AND
      the Desktop capsule inherit it too — not just Claude Code.
    • Sensitive / machine-specific / private → put it in the ENCRYPTED OVERLAY:
      `agenix -e secrets/personal/agent-instructions.age`
      It decrypts to ~/.agents/instructions.private.md and loads via the managed
      @includes import below (Claude only — never committed as plaintext).
    • Claude-Code-only mechanics that are safe to publish → the marked section
      at the bottom of this file.
  If in doubt, it goes in the overlay. Do not paste secrets here.
-->

# Global Claude Code Instructions

Canonical, cross-agent instructions live in the shared layers below — the same
set Codex reads from `~/.agents/AGENTS.md`. Keep substance in the layers or the
private overlay; keep this file a thin composition point.

## Canonical agent layers (shared with Codex)

@includes/agents-company-values.md
@includes/agents-personal-constitution.md

<!--
  Private overlay. Imported HERE (not in AGENTS.md) on purpose: Claude Code
  skips unresolvable imports, so on a fresh machine — before agenix has
  decrypted the overlay — this line dangles harmlessly and the public layers
  still load. Codex/GUI surfaces treat a missing import as fatal, which is why
  AGENTS.md leaves the private overlay out and this file carries it.
-->
@includes/agents-instructions.private.md

## Claude-surface rules

@rules/outbound-comment-gate.md

## Claude Code specifics (public)

<!--
  TODO(alyssa): triage your old ~/.claude/CLAUDE.md.hm-backup here.
    • Shareable across agents? → move it up into a layer (so Codex + Desktop
      capsule get it), not into this section.
    • Sensitive? → `agenix -e secrets/personal/agent-instructions.age`.
    • Genuinely Claude-Code-only AND safe to publish (e.g. slash-command habits,
      terminal-workflow quirks that don't apply to Codex)? → keep it right here.
  Leave this section empty until you've made those calls in review.
-->
