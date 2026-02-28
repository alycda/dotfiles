{ pkgs, ... }:

{
  userSettings = {
    git.autofetch = false; # should be covered by git.enabled = false, but setting explicitly just in case
    git.enabled = false;
  };

  extensions = with pkgs; [
    vscode-marketplace.jjk.jjk
    vscode-marketplace.visualjj.visualjj
  ];
}