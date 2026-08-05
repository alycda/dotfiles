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

    # Recovered from two surviving sources, both from 2025 — everything older
    # than that is genuinely lost (no .gitconfig exists in any repo on the
    # account, and no gist predates 2025-01):
    #   - gist "Git Config" 27e511ca5806a9cd7f2e823d6e306d98 (5 revisions,
    #     2025-01 .. 2025-06): the short aliases, pull.rebase, log.date
    #   - alycda/nix-dotfiles vcs/_git/config (this repo's WIP predecessor):
    #     the curated `l` / `lg` graph formats, `s`, `remotes`
    # Deliberately NOT carried over from those sources:
    #   - core.editor = "code --wait": git already honours $EDITOR, which is
    #     hx here. Hard-coding VS Code breaks the editor in every headless
    #     context (this container, CI, ssh).
    #   - core.ignorecase = true: that is a property of the filesystem, which
    #     git detects on its own. Forcing it true on a case-sensitive one
    #     (Linux, i.e. this container) makes git conflate paths that differ
    #     only in case and miss renames between them.
    ignores = [
      ".jj" # colocated repos: jj's own dir is never git's business
      ".notes/"
    ];

    settings = {
      include.path = "${config.home.homeDirectory}/.local/share/agenix/git-config";
      init.defaultBranch = "main";
      log.date = "relative";
      pull.rebase = true;
      push.autoSetupRemote = true;

      # Bare clones come back with no fetch refspec, so `git fetch` in a
      # worktree checked out from one silently updates nothing. Setting the
      # stock refspec globally fixes that; normal clones already write this
      # value locally, where it wins anyway.
      remote.origin.fetch = "+refs/heads/*:refs/remotes/origin/*";

      alias = {
        br = "branch";
        branches = "branch -a";
        co = "checkout";
        cp = "cherry-pick";
        s = "status -s";
        st = "status";
        remotes = "remote -v";
        wip = "commit -m WIP";
        ca = "commit --amend --no-edit";

        # The two curated history views. `l` is the quick glance (last 20,
        # no refs, no dates); `lg` is the full read, with decorations and
        # relative times. Colours are positional, so they stay scannable:
        # magenta = hash, green = refs/date, cyan = author.
        l = "log --color --graph --format='%C(magenta)%h%Creset %s %C(cyan)<%an>%Creset' -n 20 --abbrev-commit";
        lg = "log --color --graph --format='%C(magenta)%h%Creset -%C(green)%d%Creset %s %C(yellow)(%cr) %C(cyan)<%an>%Creset' --abbrev-commit";

        # `since` is the primitive: everything I authored in a time window,
        # across all refs rather than just the current branch — in a colocated
        # jj repo the day's work is usually sitting on anonymous heads that
        # plain `git log` would never show.
        #   git since "2 weeks ago"
        since = ''!f() { git log --all --author="$(git config user.email)" --since="''${1:-1 day ago}" --format='%C(magenta)%h%Creset %C(green)%cr%Creset %s' --abbrev-commit; }; f'';

        # `yesterday` is that primitive with a working-day default: one day
        # back, except on Monday (date +%u = 1), where it reaches back three
        # to pick up Friday. Pass a window to override it.
        yesterday = ''!f() { d=1; [ "$(date +%u)" = 1 ] && d=3; git since "''${1:-$d days ago}"; }; f'';
      };
    };
  };
}
