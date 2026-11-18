{ pkgs, ... }:
{
  userSettings = {
    # Claude through my own API key (BYOK) instead of disabling the built-in
    # AI. The provider lives in chatLanguageModels.json, which stays unmanaged:
    # VS Code writes it at runtime and it holds a secret-storage reference.
    chat = {
      # Inline chat (Cmd+I) failed until agent mode was on, so BYOK needs it.
      agent.enabled = true;
      # Utility flows (titles, intent detection) go to the BYOK model, not
      # Copilot - with no GitHub sign-in they fail otherwise. The Settings UI
      # labels this "Main Agent Model"; the stored value is "mainAgent".
      byokUtilityModelDefault = "mainAgent";
    };
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
    vscode-marketplace.ms-azuretools.vscode-containers
    vscode-marketplace.ms-vscode-remote.remote-containers
    vscode-marketplace.ms-vscode-remote.remote-ssh
    vscode-marketplace.skellock.just
  ];
}