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
  home.file.".claude/rules/outbound-comment-gate.md".source =
    ../../../tools/claude/rules/outbound-comment-gate.md;

  # Declarative Claude Code plugin catalog — the issue #40 follow-up noted in
  # tools/agents/README.md: desired plugin state lives in
  # tools/agents/plugins/catalog.json, never a committed ~/.claude/plugins
  # cache. settings.json is runtime-mutable (Claude Code writes it), so it
  # stays unmanaged; activation deep-merges the catalog in idempotently and
  # Claude Code itself fetches declared marketplaces and installs enabled
  # plugins on next startup.
  home.activation.claudePluginCatalog = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    run mkdir -p "$HOME/.claude"
    if [ ! -f "$settings" ]; then
      run sh -c 'echo "{}" > "$1"' _ "$settings"
    fi
    run sh -c '"$1" -s ".[0] * .[1]" "$2" "$3" > "$2.tmp" && mv "$2.tmp" "$2"' \
      _ "${pkgs.jq}/bin/jq" "$settings" "${../../../tools/agents/plugins/catalog.json}"
  '';

  # entryAfter linkGeneration (not just writeBoundary): the import line must only
  # be appended once the rule file it points at has actually been linked —
  # otherwise a failure later in activation leaves CLAUDE.md importing a file
  # that doesn't exist (observed on the dotfiles-ci VM, 2026-07-02).
  home.activation.claudeOutboundCommentGate = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    claudeMd="$HOME/.claude/CLAUDE.md"
    importLine="@rules/outbound-comment-gate.md"
    if [ ! -f "$claudeMd" ] || ! grep -qxF "$importLine" "$claudeMd"; then
      run mkdir -p "$HOME/.claude"
      run sh -c 'printf "\n%s\n" "$1" >> "$2"' _ "$importLine" "$claudeMd"
    fi
  '';
}
