# ditto
{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
    ../modules/dev/rust.nix
  ];

  # Live-edit agent skills from the local checkout (module imported via
  # common.nix; store-copy mode is the default elsewhere). Darwin-gated:
  # this profile is also instantiated as alyssa@work-dev on aarch64-linux,
  # where ~/dotfiles does not exist and the store copy must win.
  agentSkills.liveCheckout =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "${config.home.homeDirectory}/dotfiles";

  home = {
    username = "alyssaevans";
    homeDirectory = "/Users/alyssaevans";

    packages = with pkgs; [
      cocoapods # for flutter (to be removed soon)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
      teleport # kubectl
      cmake
      # flutter - managed by puro (manually installed)
      openjdk
      # swig - installed via homebrew (locked tap)
      # lazydiff - now a real derivation in modules/tools/lazydiff.nix,
      # imported via common.nix, so every profile gets it
    ];
  };
}