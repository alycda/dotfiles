# ditto
{ pkgs, lib, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
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

    # The installer drops the binary in ~/.lazydiff/bin and appends a PATH
    # export to the shell rc — which does nothing once home-manager owns the
    # rc files. Put the directory on PATH declaratively instead.
    sessionPath = [ "$HOME/.lazydiff/bin" ];

    activation = {
      # lazydiff (Ataraxy-Labs) is alpha and not packaged in nixpkgs,
      # so use the official install script for now, guarded so it only
      # runs when the binary is missing. Revisit with a real Nix
      # derivation once it stabilizes.
      #
      # Activation runs with a sanitized PATH (no /usr/bin), so the installer
      # can't find `tar` unless we provide it. Guard on the install path, not
      # `command -v` — lazydiff is never on the activation PATH, so that
      # guard re-ran the installer on every switch. Pin the version: the
      # installer's `releases/latest` lookup hits the GitHub API, which is
      # rate-limited for unauthenticated clients; a pinned version downloads
      # directly and keeps the install reproducible.
      installLazydiff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! [ -x "$HOME/.lazydiff/bin/lazydiff" ]; then
          run /bin/sh -c "export PATH=${lib.makeBinPath [ pkgs.curl pkgs.gnutar pkgs.gzip pkgs.coreutils ]}:\$PATH; curl -fsSL https://raw.githubusercontent.com/Ataraxy-Labs/lazydiff/main/install | /bin/sh -s -- --version 0.1.0-alpha.17"
          [ -x "$HOME/.lazydiff/bin/lazydiff" ] || { echo "lazydiff install failed" >&2; exit 1; }
        fi
      '';
    };
  };
}