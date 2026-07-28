# Private agent-instruction distribution overlay (issue #40).
#
# One canonical instruction set, delivered to every agent surface as local
# plaintext files (never a URL to fetch). Two public layers live in the repo;
# the rest is a rage/age-encrypted private overlay decrypted only on local
# machines and exposed at a stable home path — never read into the Nix store.
#
# Canonical surface: ~/.agents/AGENTS.md. Claude-oriented tools reach the same
# files through ~/.claude/includes/ symlinks; Codex loads it via a managed
# ~/.codex/AGENTS.md symlink. See tools/agents/README.md.
{ config, ... }:
let
  agentsDir = "${config.home.homeDirectory}/.agents";
  # Out-of-store symlinks so the Claude includes track the live ~/.agents files
  # (and the *decrypted* overlay), not immutable store copies.
  oosLink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Public layers, tracked in the repo, deployed verbatim.
  home.file = {
    ".agents/AGENTS.md".source = ../../../tools/agents/AGENTS.md;
    ".agents/company-values.md".source = ../../../tools/agents/company-values.md;
    ".agents/personal-constitution.md".source = ../../../tools/agents/personal-constitution.md;

    # Claude include path: local imports, not a URL. Point at ~/.agents so
    # edits and the runtime decryption of the overlay flow through one place.
    ".claude/includes/agents-company-values.md".source = oosLink "${agentsDir}/company-values.md";
    ".claude/includes/agents-personal-constitution.md".source = oosLink "${agentsDir}/personal-constitution.md";
    ".claude/includes/agents-instructions.private.md".source = oosLink "${agentsDir}/instructions.private.md";

    # Codex entrypoint: Codex loads ~/.codex/AGENTS.md natively. Symlink it to
    # the canonical file so a fresh activation wires Codex without a manual
    # step. A pre-existing hand-edited file is adopted as .hm-backup (see
    # home-manager.backupFileExtension in flake.nix).
    ".codex/AGENTS.md".source = oosLink "${agentsDir}/AGENTS.md";
  };

  # Claude loads these layers through @includes/ import lines that now live in
  # the tracked ~/.claude/CLAUDE.md (tools/claude/CLAUDE.md, deployed by
  # ../claude-code.nix) rather than being appended at activation. The include
  # symlinks above are the resolution targets for those lines; the private
  # include may dangle until agenix decrypts the overlay, and Claude Code skips
  # unresolvable imports, so the public layers still load on a fresh machine.

  # Private overlay: agenix decrypts the ciphertext and exposes the plaintext at
  # this stable home path. Using a per-secret `path` keeps the decrypted file in
  # the agenix runtime dir (symlinked here) and out of the Nix store. Identity
  # and secretsDir are configured in ../git.nix; this only adds the secret.
  age.secrets.agent-instructions = {
    file = ../../../secrets/personal/agent-instructions.age;
    path = "${agentsDir}/instructions.private.md";
  };
}
