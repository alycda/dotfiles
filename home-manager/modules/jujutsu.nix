{ config, lib, pkgs, ... }:

let
  # jj >= 0.29 reads its user config from XDG_CONFIG_HOME on every platform
  # (older versions used ~/Library/Application Support on darwin). The pinned
  # jujutsu is well past that, and home-manager's own module resolves the same
  # path, so config.toml and conf.d/ end up as siblings.
  jjConfigDir = "${config.xdg.configHome}/jj";

  # The git identity lives in secrets/personal/git-config.age and is decrypted
  # to this path by agenix (see ./git.nix, which also sets age.secretsDir).
  gitConfigSecret = "${config.home.homeDirectory}/.local/share/agenix/git-config";
in
{
  programs.jujutsu = {
    enable = true;

    # The binary already comes from lib/core-packages.nix, which both this
    # home-manager closure and the flake's devShells import. Installing it
    # again here would be the same store path, but saying `null` keeps one
    # answer to "where does jj come from" instead of two. What we want from
    # this module is the *config*, not the package - same split as
    # `programs.bash.package = null` in ../profiles/dev.nix.
    package = null;

    # Everything here is rendered into a read-only /nix/store TOML file that
    # ~/.config/jj/config.toml symlinks to. That is the whole point: the file
    # is rebuilt from this module on every activation, so it survives a
    # container rebuild instead of being re-typed by hand from the cheatsheet.
    #
    # The corollary is that `jj config set --user` stops being the way to add
    # a setting, in the quiet way rather than the loud one. jj 0.44 prompts for
    # which user config file to edit and defaults to config.toml - the symlink
    # - so the write follows it into /nix/store and lands in the *store copy*
    # wherever the store is writable, which is the case in the devcontainer
    # (verified 2026-08-23). It reports success, and the next activation
    # reverts it. Same trap `gh auth setup-git` sets for git config - see the
    # long note in ./git.nix.
    #
    # So: settings that should follow the machine go here. Machine-local
    # one-offs go in ~/.config/jj/conf.d/99-local.toml, which home-manager does
    # not own and jj loads *after* config.toml, so it wins.
    settings = {
      ui = {
        # Bare `jj` prints help, which is never what's wanted after `cd`ing
        # into a repo. `log` matches the first thing CLAUDE.md's workflows do.
        default-command = "log";

        # jj defaults to color-words diffs. Every diff invocation in this
        # repo's docs and agent skills passes --git, so make that the default
        # rather than a flag to remember.
        diff-formatter = ":git";
      };
    };
  };

  # user.name/user.email deliberately do NOT live in `settings` above: this is
  # a public repo, and the identity is encrypted for the same reason git's is.
  # Instead, derive them from the git-config secret that is already the single
  # source of truth for who commits, and write them to conf.d - so there is
  # still exactly one identity to change, in one encrypted file.
  #
  # Why a generated file rather than a symlink to the secret: agenix decrypts
  # git-config in git's INI format, and jj has no `include` directive and reads
  # only TOML. So the translation has to happen somewhere; activation is the
  # cheapest place.
  #
  # Timing caveat: agenix's home-manager module does not decrypt during
  # activation - it installs a systemd user service (Linux) / launchd agent
  # (darwin) that runs the mount script. So on a machine where that has not run
  # yet (a first switch, or the devcontainer, which has no systemd) the secret
  # is absent and this writes nothing. That is why it never *deletes* the file:
  # once written it lives in $HOME, outside the generation, so it survives both
  # the next switch and a container rebuild of the devhome volume. Re-run
  # `home-manager switch` after the secret appears to refresh it, or hand-write
  # the same file - the format is three lines and nothing here will clobber it
  # unless the secret is readable.
  home.activation.jjIdentityFromGitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    identityFile="${jjConfigDir}/conf.d/10-identity.toml"

    if [ -r "${gitConfigSecret}" ]; then
      # Parse with git rather than grep: the secret is a real gitconfig, with
      # sections and comments. `|| true` because a missing key exits non-zero
      # and activation runs under `set -e`.
      jjUserName=$(${pkgs.git}/bin/git config --file "${gitConfigSecret}" --get user.name || true)
      jjUserEmail=$(${pkgs.git}/bin/git config --file "${gitConfigSecret}" --get user.email || true)

      if [ -n "$jjUserName" ] && [ -n "$jjUserEmail" ]; then
        # TOML basic strings: a stray backslash or quote in a name would
        # otherwise produce a config.toml jj refuses to parse at all, taking
        # every jj command down with it. Escape backslashes first.
        jjUserName=''${jjUserName//\\/\\\\}
        jjUserName=''${jjUserName//\"/\\\"}
        jjUserEmail=''${jjUserEmail//\\/\\\\}
        jjUserEmail=''${jjUserEmail//\"/\\\"}

        run mkdir -p "${jjConfigDir}/conf.d"
        printf '# Generated by home-manager from the agenix git-config secret.\n# Edit secrets/personal/git-config.age (just edit-secret) - not this file.\n[user]\nname = "%s"\nemail = "%s"\n' \
          "$jjUserName" "$jjUserEmail" | run --quiet tee "$identityFile"
      else
        warnEcho "jj identity: ${gitConfigSecret} has no user.name/user.email; leaving $identityFile alone"
      fi
    fi
  '';
}
