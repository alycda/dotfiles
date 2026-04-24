{ pkgs, ... }:
{
  userSettings = {
    # claudeCode = {
    #   preferredLocation = "panel";
    # };
    claudeCode.preferredLocation = "panel";
    diffEditor.ignoreTrimWhitespace = false;
    editor.wordWrap = "on";
    files.exclude = {
      "**/.jj" = true;
      "result" = true;
    };
    files.hotExit = "onExitAndWindowClose"; # remember unsaved changes
    git = {
      autofetch = true;
      confirmSync = false;
      replaceTagsWhenPull = true;
    };
    search.exclude = {
      "**/.jj" = true;
      "result" = true;
    };
    task.allowAutomaticTasks = "on";
    # Use system zsh instead of nix-managed path that may not exist
    terminal.integrated.defaultProfile.osx = "zsh";
    terminal.integrated.initialHint = false;
    workbench.secondarySideBar.defaultVisibility = "hidden";
  };

  extensions = with pkgs; [
    vscode-marketplace.alefragnani.bookmarks
    vscode-marketplace.anthropic.claude-code # unfree
    vscode-marketplace.jnoortheen.nix-ide
    vscode-marketplace.ms-vscode-remote.remote-containers
    vscode-marketplace.ms-vscode-remote.remote-ssh
    vscode-marketplace.skellock.just
  ];
}