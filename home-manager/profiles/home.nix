# shesfast
{ pkgs, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
    ../modules/tools/agent-skills.nix
  ];

  home = {
    username = "alyssa";
    homeDirectory = "/Users/alyssa";

    packages = with pkgs; [
      taskbook # interim CLI task manager; desktop-only (Node closure, not for containers)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}