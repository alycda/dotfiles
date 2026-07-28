# Claude Code global config — managed pieces of ~/.claude.
# The claude-code package itself is installed in common.nix; this module manages
# config that must exist identically on every machine.
#
# ~/.claude/CLAUDE.md is now fully tracked (tools/claude/CLAUDE.md) and deployed
# as a read-only Nix store symlink, rather than hand-edited with import lines
# appended at activation. The tracked file already contains the @includes/ and
# @rules/ import lines, so the old idempotent-append activation scripts (this
# module's outbound-comment-gate appender and agents.nix's layer appender) are
# retired. A pre-existing hand-edited file is adopted as CLAUDE.md.hm-backup
# (home-manager.backupFileExtension in flake.nix).
#
# Tradeoff: because the file is a store symlink it can't be hand-edited on the
# machine, and Claude Code's `/memory` quick-add can't append to it — edit
# tools/claude/CLAUDE.md (or the layers/overlay) and switch instead.
_:
{
  home.file = {
    # The managed global memory file (composition point) and the rule files it
    # imports. CLAUDE.md's @rules/... and @includes/... lines resolve relative
    # to ~/.claude/, so both land under ~/.claude/ alongside it.
    ".claude/CLAUDE.md".source = ../../../tools/claude/CLAUDE.md;
    ".claude/rules/outbound-comment-gate.md".source =
      ../../../tools/claude/rules/outbound-comment-gate.md;
  };
}
