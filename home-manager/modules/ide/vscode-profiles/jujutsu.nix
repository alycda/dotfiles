{ pkgs, ... }:

{
  userSettings = {
    git.enabled = false;
  };

  extensions = with pkgs; [
    vscode-marketplace.jjk.jjk
    vscode-marketplace.visualjj.visualjj
  ];
}