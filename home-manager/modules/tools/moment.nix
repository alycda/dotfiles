# Moment (moment.dev) - local, jj-backed markdown editor, used as the surface
# for agent-written documents. The app itself is installed by hand: it is not
# in nixpkgs, and Homebrew's `moment` cask is an unrelated countdown app. This
# module only manages the pieces around it.
#
# Desktop profiles only: the paths assume the app's ~/.moment layout, which
# never exists in the headless devcontainer.
{ pkgs, ... }:
{
  home = {
    # The agent commit protocol behind `jj agent-start` / `jj agent-done`.
    # jujutsu in runtimeInputs so the aliases never pick up an older jj from
    # PATH - Moment's own embedded jj-lib is 0.37, which mishandles the
    # conf.d scope below (see tools/moment/jj-claude-authorship.toml).
    packages = [
      (pkgs.writeShellApplication {
        name = "jj-moment-agent";
        runtimeInputs = [
          pkgs.jujutsu
          pkgs.jq
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../tools/moment/jj-moment-agent.sh;
      })
    ];

    # Claude Code loads CLAUDE.md from every ancestor of its cwd, so one file
    # here covers every ~/.moment/documents/<id>/ - no per-document edits, and
    # no fight with the CLAUDE.md/AGENTS.md that Moment writes into each
    # document and keeps overwriting. (Verified: loads as project memory at
    # session start, per the InstructionsLoaded audit log.) Codex and crush
    # read instruction files only from the git root down (per their docs;
    # not tested here), so they get the same two commands from the
    # moment-docs skill (tools/agents/skills, deployed by agent-skills.nix).
    file.".moment/CLAUDE.md".source = ../../../tools/moment/CLAUDE.md;
  };

  xdg.configFile = {
    # The two aliases, active only inside Moment documents. conf.d fragments
    # rather than keys in ~/.config/jj/config.toml, which stays hand-edited;
    # jj loads conf.d/*.toml after config.toml.
    "jj/conf.d/moment-agent-aliases.toml".source =
      ../../../tools/moment/jj-agent-aliases.toml;

    # Fallback for when Claude runs a plain `jj new` instead of agent-start:
    # still authored as Claude. Codex and crush have no equivalent - they rely
    # on agent-start setting the identity explicitly.
    "jj/conf.d/moment-claude-authorship.toml".source =
      ../../../tools/moment/jj-claude-authorship.toml;
  };
}
