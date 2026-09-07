# The non-sudo macOS account (flake.nix: homeConfigurations."code",
# aarch64-darwin). It has no sudo and no brew of its own: the admin account owns
# /opt/homebrew, and darwin/modules/homebrew.nix sets
# `onActivation.cleanup = "zap"`, which makes that brews/casks list
# authoritative - anything this account borrowed from it could vanish on
# someone else's rebuild. Standalone home-manager is how tooling reaches this
# user instead:
#
#   home-manager switch --flake .#code
{ pkgs, lib, ... }:

{
  home = {
    username = "code";
    homeDirectory = "/Users/code";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
      rustup

      # envchain: pull environment variables out of the macOS login keychain
      # into one command's environment - `envchain <namespace> <cmd>`. The
      # values live in the keychain, never in a file, and never leak into the
      # ambient shell (nor, therefore, into shell history - the flaw a
      # commenter flagged in envelope's `add` on the very thread that
      # introduced it).
      #
      # Intended use is host-side, wrapping the container one-liner rather than
      # living inside it:
      #
      #   envchain --set dev ANTHROPIC_API_KEY JJ_USER JJ_EMAIL   # once
      #   envchain dev ./docker/dev.sh run
      #
      # It deliberately does NOT work *inside* the container: envchain reads
      # the macOS keychain or a D-Bus secret service, and the nixos/nix rootfs
      # offers neither. That is the whole difference from the mise branch -
      # this is a host-side injector, not a container tool.
      #
      # Its one interactive prompt (`--set`) does not repeat the hackmd-cli
      # mistake: it is a deliberate one-time setup command run by a human on a
      # machine with a keychain, never something an agent reaches headlessly.
      # `envchain <ns> <cmd>` itself never prompts.
      #
      # No isDarwin guard, unlike work.nix's cocoapods/taskbook block: flake.nix
      # instantiates this profile only as aarch64-darwin, so there is no Linux
      # evaluation for a guard to protect.
      envchain
    ];

    activation = {
      rustupSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${pkgs.rustup}/bin/rustup default stable
      '';
    };
  };
}