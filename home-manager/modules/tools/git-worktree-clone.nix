# git-worktree-clone — one-command bare-repo + worktree checkout layout.
#
# Distributed as a PATH binary (not a justfile recipe or cheatsheet-only
# procedure) because home-manager PATH is the one surface every machine class
# shares — container, admin mac, working checkout. git discovers any git-*
# binary on PATH as a subcommand, so this runs as `git worktree-clone`.
# The recipe is documented in cheatsheet git/worktree/clone.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "git-worktree-clone";
      runtimeInputs = [ pkgs.git ];
      text = builtins.readFile ../../../tools/git/git-worktree-clone.sh;
    })
  ];
}
