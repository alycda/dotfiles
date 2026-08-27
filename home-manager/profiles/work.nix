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
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
      teleport # kubectl
      cmake
      # LiteLLM bridge for Claude Code -> casper (Anthropic Messages -> OpenAI 
      # chat/completions translation). Only claude needs it: codex speaks 
      # casper's Responses wire natively, and crush<->venice is 
      # OpenAI-compatible end to end. See cheat claude/casper.
      litellm
      # flutter - managed by puro (manually installed)
      openjdk
      # swig - installed via homebrew (locked tap)
      # lazydiff - alpha, not in nixpkgs yet; installed via official script below
    ]
    # darwin-only packages: this profile is also alyssa@work-dev on
    # aarch64-linux (see agentSkills.liveCheckout above), and cocoapods
    # only supports aarch64-darwin
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      cocoapods # for flutter (to be removed soon)
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

  # The ditto-worktree agent recipes as just's GLOBAL justfile: run with
  # `just -g <recipe>` from the workspace they expect. Verified (just 1.58):
  # -g recipes execute with the invocation directory as cwd and dotenv-load
  # reads the cwd's .env, so relative paths behave as if the justfile were
  # local to the workspace. The justfile imports siblings (recipes/*.just),
  # so the config entry is a one-line shim importing the store copy of
  # tools/just by absolute path - the justfile's own relative imports then
  # resolve inside that directory (also verified empirically).
  xdg.configFile."just/justfile".text = "import '${../../tools/just}/ditto-worktree.justfile'";
}