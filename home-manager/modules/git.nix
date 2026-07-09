{ config, lib, pkgs, ... }:

{
  # Use a stable path for secrets so git's include.path can reference it directly.
  # The default on macOS is $(getconf DARWIN_USER_TEMP_DIR)/agenix which is a shell
  # expression git cannot evaluate. A path under ~ is stable across sessions.
  age = {
    secretsDir = "${config.home.homeDirectory}/.local/share/agenix";
    identityPaths = [ "${config.home.homeDirectory}/.age/personal-key.txt" ];

    secrets.git-config = {
      file = ../../secrets/personal/git-config.age;
    };
  };

  # The agenix mount script symlinks secretsDir into place with `ln -sfn` but
  # does not create its parent. On a fresh account ~/.local/share does not
  # exist yet, so the first activation decrypts secrets and then fails to link
  # them (observed on the dotfiles-ci VM, 2026-07-09). Ensure the parent early.
  home.activation.ensureAgenixSecretsDirParent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/share"
  '';

  programs.git = {
    enable = true;

    # Resolve a profile-assembly (buildEnv) collision: full git and a
    # git-minimal both ship share/git-core/templates/info/exclude (and bin/git),
    # so if anything drags git-minimal into the closure they clash. The dev-x86
    # container hit this when its image was baked from a divergent flake.lock
    # that resolved git-minimal (2.51.2) separately from full git (2.52.0).
    # hiPrio makes buildEnv prefer the full git deterministically. To find and
    # remove the actual git-minimal source instead, build the profile and run:
    #   nix why-depends <profile> <git-minimal-store-path>
    package = lib.hiPrio pkgs.git;

    settings = {
      include.path = "${config.home.homeDirectory}/.local/share/agenix/git-config";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
}
