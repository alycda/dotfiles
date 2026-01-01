{ pkgs, ... }:
{
  userSettings = {
    chat.agent.enabled = false;
    claudeCode = {
      preferredLocation = "panel";
    };
    diffEditor.ignoreTrimWhitespace = false;
    editor.wordWrap = "on";
    files.exclude = {
      "**/.jj" = true;
    };
    search.exclude = {
      "**/.jj" = true;
    };
    # Use system zsh instead of nix-managed path that may not exist
    "terminal.integrated.defaultProfile.osx" = "zsh";
    workbench.secondarySideBar.defaultVisibility = "hidden";
    
  };

  extensions = with pkgs; [
    vscode-marketplace.alefragnani.bookmarks
    vscode-marketplace.anthropic.claude-code # unfree
    vscode-marketplace.jnoortheen.nix-ide
  ];
}