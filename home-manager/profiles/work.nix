# ditto
{ pkgs, ... }:

{
  imports = [
    ../modules/dev/rust.nix
  ];

  home = {
    username = "admin";
    homeDirectory = "/Users/admin";

    packages = with pkgs; [
      cocoapods # for flutter (to be removed soon)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
      teleport # kubectl
      cmake
      # flutter - managed by puro (manually installed)
      openjdk
      # swig - installed via homebrew (locked tap)
    ];
  };
}