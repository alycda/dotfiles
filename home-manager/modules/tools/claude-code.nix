# Claude Code global rules - managed pieces of ~/.claude
# The claude-code package itself is installed via ./claude.nix, which also
# manages ~/.claude/CLAUDE.md as an out-of-store symlink. The managed
# CLAUDE.md imports rules/outbound-comment-gate.md directly, so no activation
# script is needed to splice the import in (it was only required while
# CLAUDE.md was still hand-edited and unmanaged).
_:
{
  home.file.".claude/rules/outbound-comment-gate.md".source =
    ../../../tools/claude/rules/outbound-comment-gate.md;
}
