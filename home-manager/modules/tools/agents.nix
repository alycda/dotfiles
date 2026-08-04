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
  # Critic subagents: persona (frontmatter + enforcer instructions) canonical
  # in tools/agents/, judged-against material appended beneath as layers.
  # On-demand rubrics instead of always-loaded context — store-safe; only
  # public files, never the private overlay.
  mkCritic = persona: layers:
    lib.concatStringsSep "\n" (map builtins.readFile ([ persona ] ++ layers));
in
{
  # Public layers, tracked in the repo, deployed verbatim.
  home.file = {
    ".agents/AGENTS.md".source = ../../../tools/agents/AGENTS.md;
    ".agents/company-values.md".source = ../../../tools/agents/company-values.md;
    ".agents/personal-constitution.md".source = ../../../tools/agents/personal-constitution.md;
    ".agents/preferred-tooling.md".source = ../../../tools/agents/preferred-tooling.md;
    ".agents/personal-constitution-distilled.md".source = ../../../tools/agents/personal-constitution-distilled.md;

    # Claude include path: local imports, not a URL. Point at ~/.agents so
    # edits and the runtime decryption of the overlay flow through one place.
    # Claude always-loads the *distilled* constitution; the full version is
    # on-demand via the constitution-critic subagent below.
    ".claude/includes/agents-company-values.md".source = oosLink "${agentsDir}/company-values.md";
    ".claude/includes/agents-preferred-tooling.md".source = oosLink "${agentsDir}/preferred-tooling.md";
    ".claude/includes/agents-personal-constitution-distilled.md".source = oosLink "${agentsDir}/personal-constitution-distilled.md";
    ".claude/includes/agents-instructions.private.md".source = oosLink "${agentsDir}/instructions.private.md";

    # constitution-critic: the full constitution (every article carries a
    # test and a failure signal) as a judging rubric.
    ".claude/agents/constitution-critic.md".text =
      mkCritic ../../../tools/agents/constitution-critic.md [
        ../../../tools/agents/personal-constitution.md
        ../../../tools/agents/company-values.md
      ];

    # code-critic: engineering rubrics (TigerStyle, NASA Power of Ten, Test
    # Desiderata) for judging code, designs, and tests.
    ".claude/agents/code-critic.md".text =
      mkCritic ../../../tools/agents/code-critic.md [
        ../../../tools/agents/rubrics/tiger-style.md
        ../../../tools/agents/rubrics/power-of-ten.md
        ../../../tools/agents/rubrics/test-desiderata.md
      ];

    # factory-critic: StrongDM Software Factory method for judging process
    # (seed / validation harness / feedback loop), not code quality.
    ".claude/agents/factory-critic.md".text =
      mkCritic ../../../tools/agents/factory-critic.md [
        ../../../tools/agents/rubrics/strongdm-principles.md
        ../../../tools/agents/rubrics/strongdm-techniques.md
        ../../../tools/agents/rubrics/strongdm-products.md
      ];

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
      "@includes/agents-preferred-tooling.md" \
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
