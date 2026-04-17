# gh-dash - GitHub dashboard TUI for the gh CLI
# Requires a Nerd Font for icons - Fira Code Nerd Font installed via darwin/configuration.nix
# https://github.com/dlvhdr/gh-dash
_:
{
  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        { title = "My PRs"; filters = "is:open author:@me"; }
        { title = "Needs Review"; filters = "is:open review-requested:@me"; }
        { title = "Involved"; filters = "is:open involves:@me -author:@me"; }
      ];
      issuesSections = [
        { title = "My Issues"; filters = "is:open author:@me"; }
        { title = "Assigned"; filters = "is:open assignee:@me"; }
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
