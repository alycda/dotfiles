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
{ config, lib, ... }:
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
    ".agents/personal-constitution-distilled.md".source = ../../../tools/agents/personal-constitution-distilled.md;

    # Claude include path: local imports, not a URL. Point at ~/.agents so
    # edits and the runtime decryption of the overlay flow through one place.
    # Claude always-loads the *distilled* constitution; the full version is
    # on-demand via the constitution-critic subagent below.
    ".claude/includes/agents-company-values.md".source = oosLink "${agentsDir}/company-values.md";
    ".claude/includes/agents-personal-constitution-distilled.md".source = oosLink "${agentsDir}/personal-constitution-distilled.md";
    ".claude/includes/agents-instructions.private.md".source = oosLink "${agentsDir}/instructions.private.md";

    # Constitution critic subagent: the full constitution as an on-demand
    # rubric (every article carries a test and a failure signal) instead of
    # ~7.5KB of always-loaded context. The persona (frontmatter + enforcer
    # instructions) is canonical in tools/agents/constitution-critic.md; the
    # judged material is appended from the public layers — store-safe; never
    # reads the private overlay.
    ".claude/agents/constitution-critic.md".text =
      builtins.readFile ../../../tools/agents/constitution-critic.md
      + builtins.readFile ../../../tools/agents/personal-constitution.md
      + "\n"
      + builtins.readFile ../../../tools/agents/company-values.md;

    # Codex entrypoint: Codex loads ~/.codex/AGENTS.md natively. Symlink it to
    # the canonical file so a fresh activation wires Codex without a manual
    # step. A pre-existing hand-edited file is adopted as .hm-backup (see
    # home-manager.backupFileExtension in flake.nix).
    ".codex/AGENTS.md".source = oosLink "${agentsDir}/AGENTS.md";
  };

  # Claude actually loads the layers through these imports. Same idempotent
  # append pattern (and same ordering rationale) as claudeOutboundCommentGate
  # in ../claude-code.nix: only append after linkGeneration so the include
  # symlinks the lines point at already exist. The private include may dangle
  # until agenix decrypts the overlay; Claude Code skips unresolvable imports,
  # so the public layers still load.
  home.activation.claudeAgentsImports = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    claudeMd="$HOME/.claude/CLAUDE.md"
    run mkdir -p "$HOME/.claude"
    # The full constitution moved behind the constitution-critic subagent;
    # drop the stale always-loaded import a previous generation appended.
    staleLine="@includes/agents-personal-constitution.md"
    if [ -f "$claudeMd" ] && grep -qxF "$staleLine" "$claudeMd"; then
      run sh -c 'grep -vxF "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' _ "$staleLine" "$claudeMd"
    fi
    for importLine in \
      "@includes/agents-company-values.md" \
      "@includes/agents-personal-constitution-distilled.md" \
      "@includes/agents-instructions.private.md"; do
      if [ ! -f "$claudeMd" ] || ! grep -qxF "$importLine" "$claudeMd"; then
        run sh -c 'printf "\n%s\n" "$1" >> "$2"' _ "$importLine" "$claudeMd"
      fi
    done
  '';

  # Private overlay: agenix decrypts the ciphertext and exposes the plaintext at
  # this stable home path. Using a per-secret `path` keeps the decrypted file in
  # the agenix runtime dir (symlinked here) and out of the Nix store. Identity
  # and secretsDir are configured in ../git.nix; this only adds the secret.
  age.secrets.agent-instructions = {
    file = ../../../secrets/personal/agent-instructions.age;
    path = "${agentsDir}/instructions.private.md";
  };
}
