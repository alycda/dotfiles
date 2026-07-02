# Claude Code global rules - managed pieces of ~/.claude
# The claude-code package itself is installed in common.nix; this module manages
# config that must exist identically on every machine.
#
# ~/.claude/CLAUDE.md itself stays hand-edited (not yet canonicalized into this
# repo), so managed rules live as separate files under ~/.claude/rules/ and are
# pulled in via CLAUDE.md's @import syntax. The activation script idempotently
# ensures the import line exists.
{ lib, ... }:
{
  home.file.".claude/rules/outbound-comment-gate.md".source =
    ../../../tools/claude/rules/outbound-comment-gate.md;

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
