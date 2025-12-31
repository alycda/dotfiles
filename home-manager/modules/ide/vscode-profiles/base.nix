{ pkgs, ... }:
{
  userSettings = {
    chat.agent.enabled = false;
    claudeCode.preferredLocation = "panel";
    editor.wordWrap = "on";
    files.exclude = {
      "**/.jj" = true;
    };
    search.exclude = {
      "**/.jj" = true;
    };
    workbench.secondarySideBar.defaultVisibility = "hidden";

    # Terminal settings - use nix-darwin managed zsh
    "terminal.integrated.defaultProfile.osx" = "zsh";
    "terminal.integrated.profiles.osx" = {
      zsh = {
        path = "/run/current-system/sw/bin/zsh";
      };
    };
  };

  extensions = with pkgs; [
    vscode-marketplace.alefragnani.bookmarks
    vscode-marketplace.anthropic.claude-code # unfree
    vscode-marketplace.jnoortheen.nix-ide
  ];
}