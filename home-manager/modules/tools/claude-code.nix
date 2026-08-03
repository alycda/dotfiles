# Claude Code global rules - managed pieces of ~/.claude
# The claude-code package itself is installed in common.nix; this module manages
# config that must exist identically on every machine.
#
# ~/.claude/CLAUDE.md itself stays hand-edited (not yet canonicalized into this
# repo), so managed rules live as separate files under ~/.claude/rules/ and are
# pulled in via CLAUDE.md's @import syntax. The activation script idempotently
# ensures the import line exists.
{ lib, pkgs, ... }:
{
  home = {
    file.".claude/rules/outbound-comment-gate.md".source =
      ../../../tools/claude/rules/outbound-comment-gate.md;

    activation = {
      # Managed slices of ~/.claude/settings.json. The file itself is
      # runtime-mutable (Claude Code writes it), so it stays unmanaged and
      # activation deep-merges these fragments in idempotently:
      #  - tools/claude/settings.json - plain managed defaults (e.g.
      #    cleanupPeriodDays, transcript retention extended to 90 days)
      #  - tools/agents/plugins/catalog.json - the issue #40 plugin catalog:
      #    desired plugin state, never a committed ~/.claude/plugins cache.
      #    Claude Code fetches declared marketplaces and installs enabled
      #    plugins itself on next startup.
      claudeManagedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.claude/settings.json"
        run mkdir -p "$HOME/.claude"
        if [ ! -f "$settings" ]; then
          run sh -c 'echo "{}" > "$1"' _ "$settings"
        fi
        run sh -c '"$1" -s ".[0] * .[1] * .[2]" "$2" "$3" "$4" > "$2.tmp" && mv "$2.tmp" "$2"' \
          _ "${pkgs.jq}/bin/jq" "$settings" \
          "${../../../tools/claude/settings.json}" \
          "${../../../tools/agents/plugins/catalog.json}"
      '';

      # entryAfter linkGeneration (not just writeBoundary): the import line must
      # only be appended once the rule file it points at has actually been
      # linked - otherwise a failure later in activation leaves CLAUDE.md
      # importing a file that doesn't exist (observed on the dotfiles-ci VM,
      # 2026-07-02).
      claudeOutboundCommentGate = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        claudeMd="$HOME/.claude/CLAUDE.md"
        importLine="@rules/outbound-comment-gate.md"
        if [ ! -f "$claudeMd" ] || ! grep -qxF "$importLine" "$claudeMd"; then
          run mkdir -p "$HOME/.claude"
          run sh -c 'printf "\n%s\n" "$1" >> "$2"' _ "$importLine" "$claudeMd"
        fi
      '';
    };
  };
}
