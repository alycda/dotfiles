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

  # HackMD: the work account. Both tokens are encrypted to the same age key, so
  # this is a choice about which account the machine talks to, not about who can
  # decrypt what.
  hackmd.account = "work";

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
      # Was in modules/dev/rust.nix; kept here so this profile's package set is
      # unchanged, but out of the shared module because its 1.6 GiB closure is
      # the whole reason the container profiles could not import Rust.
      lldb
      # flutter - managed by puro (manually installed)
      openjdk
      # swig - installed via homebrew (locked tap)
      # lazydiff - now a real derivation in modules/tools/lazydiff.nix,
      # imported via common.nix, so every profile gets it
    ]
    # darwin-only packages: this profile is also alyssa@work-dev on
    # aarch64-linux (see agentSkills.liveCheckout above), and cocoapods
    # only supports aarch64-darwin
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      cocoapods # for flutter (to be removed soon)
      # taskbook's Node closure is why it isn't in lib/core-packages.nix; the
      # same reasoning keeps it out of the aarch64-linux devcontainer.
      taskbook # interim CLI task manager
      # VM management, for verifying a switch on a clean macOS image. Moved
      # off the cirruslabs/cli tap, whose tart.rb no longer loads under
      # Homebrew 6.0 and aborted the whole activation; version-pinned for
      # macOS 15. Both explained in lib/tart.nix.
      (import ../../lib/tart.nix pkgs)
      # Entity-level merge driver (Ataraxy Labs; see the entity-level-git
      # skill). nixpkgs rather than the ataraxy-labs brew tap, same reasoning
      # as tart. It does build for aarch64-linux, but its ~230 MiB closure
      # keeps it out of the devcontainer alongside taskbook. Pinned forward
      # past nixpkgs' 0.3.6; see lib/weave.nix.
      (import ../../lib/weave.nix pkgs)
      # Entity-level review triage, weave's sibling. aarch64-darwin only (see
      # lib/inspect.nix for why, and for why this is not the brew tap).
      (import ../../lib/inspect.nix pkgs)
    ];
  };

  # The ditto-worktree agent recipes, layered into the global justfile that
  # common.nix owns: its shim ends with `import? '~/.config/just/local.just'`,
  # so the work profile plugs in there instead of redefining just/justfile
  # (two modules defining the same xdg.configFile path would fail eval).
  # work.just's own relative imports (work/*.just) resolve inside the store
  # copy of tools/just. Run with `just -g <recipe>` from the workspace the
  # recipes expect - they execute with the invocation directory as cwd and
  # dotenv-load reads the cwd's .env (verified on just 1.58).
  xdg.configFile."just/local.just".text = "import '${../../tools/just}/work.just'";
}