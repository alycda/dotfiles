# Moment (moment.dev) - local, jj-backed markdown editor, used as the surface
# for agent-written documents. The app itself is installed by hand: it is not
# in nixpkgs, and Homebrew's `moment` cask is an unrelated countdown app. This
# module only manages the pieces around it.
#
# Desktop profiles only: the paths assume the app's ~/.moment layout, which
# never exists in the headless devcontainer.
_:
{
  # Agent commits in Moment documents are authored as Claude. A conf.d
  # fragment rather than a key in ~/.config/jj/config.toml, which stays
  # hand-edited; jj loads conf.d/*.toml after config.toml.
  xdg.configFile."jj/conf.d/moment-claude-authorship.toml".source =
    ../../../tools/moment/jj-claude-authorship.toml;

  # The commit protocol that makes that authorship come out right. Claude
  # Code loads CLAUDE.md from every ancestor of its cwd, so one file here
  # covers every ~/.moment/documents/<id>/ - no per-document edits, and no
  # fight with the CLAUDE.md/AGENTS.md that Moment writes into each document
  # and keeps overwriting. (Verified: loads as project memory at session
  # start, per the InstructionsLoaded audit log.)
  home.file.".moment/CLAUDE.md".source = ../../../tools/moment/CLAUDE.md;
}
