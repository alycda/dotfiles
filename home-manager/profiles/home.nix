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
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}