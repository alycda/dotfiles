# Terminal UIs from main, for every profile: television and gh-dash.
{ ... }:
{
  # television (tv): a fuzzy finder by channel, run by name: `tv files`,
  # `tv git-log`, `tv shell-history`, and the channels below. Its shell
  # integration is off: loaded after fzf's, it would take Ctrl-R (history)
  # and Ctrl-T, which stay fzf's (shell.nix). The channels are plain files in
  # tools/television/cable/.
  programs.television = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
  };
  xdg.configFile = builtins.listToAttrs (
    map (name: {
      name = "television/cable/${name}.toml";
      value.source = ../tools/television/cable/${name}.toml;
    }) [ "cheat" "claude" "claude-memory" "jj-log" "taskbook" "tasks" ]
  );

  # gh-dash: pull requests and issues in the terminal, as `gh dash`. Its
  # icons need a Nerd Font in the terminal; the Macs get Fira Code's
  # (darwin/configuration.nix).
  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        {
          title = "My PRs";
          filters = "is:open author:@me";
        }
        {
          title = "Needs Review";
          filters = "is:open review-requested:@me";
        }
        {
          title = "Involved";
          filters = "is:open involves:@me -author:@me";
        }
      ];
      issuesSections = [
        {
          title = "My Issues";
          filters = "is:open author:@me";
        }
        {
          title = "Assigned";
          filters = "is:open assignee:@me";
        }
      ];
      defaults = {
        preview = {
          open = false;
          width = 50;
        };
        prsLimit = 20;
        issuesLimit = 20;
        view = "prs";
      };
    };
  };
}
