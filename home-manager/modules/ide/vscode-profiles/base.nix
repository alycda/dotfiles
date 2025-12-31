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
  };

  extensions = with pkgs; [
    vscode-marketplace.alefragnani.bookmarks
    vscode-marketplace.anthropic.claude-code # unfree
    vscode-marketplace.jnoortheen.nix-ide
  ];
}