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
{ config, lib, pkgs, ... }:
let
  agentsDir = "${config.home.homeDirectory}/.agents";
  # Out-of-store symlinks so the Claude includes track the live ~/.agents files
  # (and the *decrypted* overlay), not immutable store copies.
  oosLink = config.lib.file.mkOutOfStoreSymlink;

  # The managed import block for ~/.claude/CLAUDE.md, in precedence order:
  # entrypoint first (it carries the composition contract), private overlay last
  # (authoritative on conflict). Claude Code concatenates imports where they
  # appear, so this ordering is the precedence, not decoration.
  #
  # agents-company-values.md is deliberately absent: AGENTS.md already imports
  # ~/.agents/company-values.md by absolute path, so listing it here would load
  # the layer twice. The include symlink stays for the capsule and for anyone
  # importing the layer directly.
  #
  # Block-level HTML comments are stripped before Claude Code injects the file
  # into context, so the markers cost no tokens.
  claudeImportBlock = pkgs.writeText "claude-agents-imports.md" ''
    <!-- BEGIN managed: agents overlay -->
    <!-- Regenerated on every home-manager activation.
         Source: home-manager/modules/tools/agents.nix. Edits here are lost. -->
    @includes/agents-entrypoint.md
    @includes/agents-preferred-tooling.md
    @includes/agents-personal-constitution-distilled.md
    @includes/agents-instructions.private.md
    <!-- END managed: agents overlay -->
  '';

  # Rewrite the managed block in place rather than appending import lines.
  #
  # Appending could not express precedence (a new layer always landed last) and
  # needed a bespoke grep-vxF removal for every line a past generation had
  # appended - the block is regenerated wholesale instead, so adding, removing,
  # or reordering a layer is a one-line edit above with no migration.
  #
  # ~/.claude/CLAUDE.md stays hand-edited: everything outside the markers is
  # preserved verbatim. Only the block and known legacy bare import lines are
  # touched.
  claudeMdSync = pkgs.writeShellScript "claude-md-sync-agents" ''
    set -eu

    md=$1
    block=$2

    mkdir -p "$(dirname "$md")"
    [ -f "$md" ] || : > "$md"

    tmp=$md.hm-sync.$$
    trap 'rm -f "$tmp"' EXIT

    # Strip the previous managed block, plus any bare import line an
    # append-era generation left behind. Everything else is hand-edited.
    awk '
      /^<!-- BEGIN managed: agents overlay/ { inblock = 1; next }
      /^<!-- END managed: agents overlay/   { inblock = 0; next }
      inblock { next }
      $0 == "@includes/agents-entrypoint.md"                      { next }
      $0 == "@includes/agents-company-values.md"                  { next }
      $0 == "@includes/agents-preferred-tooling.md"               { next }
      $0 == "@includes/agents-personal-constitution.md"           { next }
      $0 == "@includes/agents-personal-constitution-distilled.md" { next }
      $0 == "@includes/agents-instructions.private.md"            { next }
      $0 == "@rules/outbound-comment-gate.md"                     { next }
      { print }
    ' "$md" > "$tmp"

    # Drop leading blank lines so the block lands at line 1 and the file does
    # not grow one blank line per activation.
    { cat "$block"; echo; sed "/./,\$!d" "$tmp"; } > "$md.new"
    mv "$md.new" "$md"
  '';
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
    #
    # The entrypoint include is what makes Claude Code read AGENTS.md at all.
    # Claude Code reads CLAUDE.md and has no AGENTS.md fallback, so without
    # this the canonical entrypoint reached Codex only and Claude never saw
    # the identity, communication, or working-agreement sections.
    ".claude/includes/agents-entrypoint.md".source = oosLink "${agentsDir}/AGENTS.md";
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

  # Claude actually loads the layers through these imports. entryAfter
  # linkGeneration (not just writeBoundary): the block must only be written
  # once the include symlinks it points at have been linked - otherwise a
  # failure later in activation leaves CLAUDE.md importing files that do not
  # exist. The private include may still dangle until agenix decrypts the
  # overlay; Claude Code skips unresolvable imports, so the public layers
  # still load.
  home.activation.claudeAgentsImports = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${claudeMdSync} "$HOME/.claude/CLAUDE.md" ${claudeImportBlock}
  '';

  # Identity and secretsDir are configured in ../git.nix; this only adds
  # secrets. One attrset rather than three `age.secrets.<name> =` statements:
  # statix's repeated_keys fires at the third, and the grouping matches
  # `home.file` above.
  age.secrets = {
    # Private overlay: agenix decrypts the ciphertext and exposes the plaintext
    # at this stable home path. Using a per-secret `path` keeps the decrypted
    # file in the agenix runtime dir (symlinked here) and out of the Nix store.
    agent-instructions = {
      file = ../../../secrets/personal/agent-instructions.age;
      path = "${agentsDir}/instructions.private.md";
    };

    # Linear API key for the `linear` MCP server. No `path` override on purpose:
    # the default is "${age.secretsDir}/${name}", i.e.
    # ~/.local/share/agenix/linear-api-key-work, which is exactly where the
    # server's headersHelper looks. Activation therefore replaces the manual
    # `just linear-key-set` step - the key arrives with the generation, so a
    # fresh container has a working Linear MCP without a paste-the-key ritual.
    #
    # The attributes keep the account suffix the *files* no longer need. Which
    # Linear account a key belongs to is a directory in secrets/, but agenix
    # secret names are one flat namespace and the decrypted filename comes from
    # the name - so secrets/work/ and secrets/personal/ carry the same filename
    # while still needing distinct attributes here.
    #
    # The ciphertext is committed ARMORED (`rage -a`). A binary .age blob is
    # valid on disk but does not survive every path it takes to get into a
    # commit; armor is plain ASCII, so it diffs, reviews, and round-trips
    # intact. Converting binary -> armor needs no key: age armor is just the
    # same ciphertext PEM-wrapped, so `{ echo BEGIN; base64 -w64 blob; echo END; }`
    # is a lossless transform on an already-encrypted file.
    linear-api-key-work = {
      file = ../../../secrets/work/linear-api-key.age;
    };

    # The personal-account counterpart. Carried, not consumed: nothing reads
    # ~/.local/share/agenix/linear-api-key-personal today. The `linear` MCP
    # server lives in the work tree, and both paths that authenticate it - its
    # headersHelper and that tree's .envrc export of $LINEAR_API_KEY - name the
    # -work file explicitly. So adding this secret delivers the value without
    # changing which Linear account any agent talks to.
    #
    # Carrying it before there is a consumer is the point. A key that exists
    # only in a container's runtime dir dies with the container; encrypted here
    # it survives, and pointing a personal tree at it later is one
    # $LINEAR_API_KEY_FILE away rather than a trip back to linear.app to mint a
    # replacement.
    linear-api-key-personal = {
      file = ../../../secrets/personal/linear-api-key.age;
    };
  };
}
