# ditto
{ pkgs, lib, ... }:

{
  imports = [
    ../modules/dev/rust.nix
  ];

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
      # lazydiff - alpha, not in nixpkgs yet; installed via official script below
    ];

    activation = {
      # lazydiff (Ataraxy-Labs) is alpha and not packaged in nixpkgs,
      # so use the official install script for now, guarded so it only
      # runs when the binary is missing. Revisit with a real Nix
      # derivation once it stabilizes.
      installLazydiff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! command -v lazydiff >/dev/null 2>&1; then
          run /bin/sh -c "${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/Ataraxy-Labs/lazydiff/main/install | /bin/sh"
        fi
      '';
    };
  };
}