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
    #
    # Scope note: hiPrio only settles collisions INSIDE this closure's buildEnv,
    # which is the case above. It cannot resolve a collision between separate
    # nix-env profile elements (home-manager-path vs a package the base image
    # installed) - priority set on an inner package is invisible at the outer
    # union. For that layer see docker/entrypoint.sh and
    # docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md.
    package = lib.hiPrio pkgs.git;

    settings = {
      include.path = "${config.home.homeDirectory}/.local/share/agenix/git-config";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;

      # `gh auth login` stores its token in ~/.config/gh/hosts.yml for gh's own
      # use; it never teaches git anything. Without a helper, an https push
      # falls through to git's username/password prompt - which GitHub disabled
      # for git operations in 2021 - so a green `gh auth status` sits right next
      # to a failing `git push`. Observed in the dev container (2026-08-17)
      # pushing from a colocated jj repo: `jj git push` shells out to git and
      # inherits the same empty credential config, so it fails identically.
      #
      # `gh auth setup-git` is the usual fix and is the wrong tool here. It
      # writes with --global, which resolves through the home-manager symlink
      # into a /nix/store path. The write lands (the store is writable in the
      # container image) and is then silently reverted by the next activation -
      # a working push that stops working after a rebuild, with no error saying
      # why. Config home-manager owns has to come from home-manager.
      #
      # Absolute store path rather than a bare `gh`: git runs the helper with
      # whatever PATH it inherited, and the nix profile is not on PATH in every
      # non-interactive context. gh is already in lib/core-packages.nix, so
      # naming it here costs nothing in the closure.
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };
}
