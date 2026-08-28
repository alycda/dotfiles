# devcontainers / codespaces
{ pkgs, ... }:

{
  # Decrypt agenix secrets from the activation script. REQUIRED here, not an
  # optimisation: ragenix's home-manager module installs secrets from a systemd
  # *user* service and contributes no activation step, and this container has no
  # user systemd daemon - so without this every age.secrets entry silently never
  # arrives. See the module header for the full story.
  imports = [ ../modules/agenix-activation.nix ];

  home = {
    username = "root";
    homeDirectory = "/root";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
    ];

    # Container-environment notes as a user-level Claude rule. ~/.claude/rules/
    # is discovered by Claude Code and loaded into every session on the machine
    # with no @import line, so this applies whatever is mounted at /work.
    #
    # This used to be copied over ~/.claude/CLAUDE.md by the Dockerfile and
    # again by docker/entrypoint.sh on every start. The entrypoint copy ran
    # before the *conditional* home-manager activation and wiped the managed
    # import block on every restart after the first. Owning the file through
    # the generation removes the copy, the shadowing problem the copy existed
    # to solve, and the clobber it caused.
    #
    # Arch is resolved at eval time: both "alyssa@dev" (aarch64-linux) and
    # "alyssa@dev-x86" (x86_64-linux) use this profile, so hostPlatform is the
    # same signal the Dockerfile's `uname -m` was reaching for.
    file.".claude/rules/container-env.md".source =
      if pkgs.stdenv.hostPlatform.isAarch64 then
        ../../docker/CLAUDE-arm64.md
      else
        ../../docker/CLAUDE.md;
  };

  # HackMD: the personal account. This profile is the Docker image
  # (alyssa@dev / alyssa@dev-x86), and a container is where the CLI most needs
  # the token to arrive on its own - nobody runs `hackmd-cli login` in a
  # throwaway shell, and without a token the CLI used to hang rather than fail
  # (see tools/hackmd/token-guard.sh). Decryption needs the age identity the
  # Dockerfile already documents copying in for git-config; the same key covers
  # both secrets.
  hackmd.account = "personal";

  # Configure bash, but do NOT ship a bash. common.nix enables programs.bash so
  # the container's fallback shell gets a prompt and direnv; that module also
  # puts bashInteractive into home.packages, which collides head-on with the
  # bash-interactive the nixos/nix base image already has in root's nix-env
  # profile. The two are different store paths, so assembling the user
  # environment dies with:
  #
  #   error: Unable to build profile. There is a conflict for the following files:
  #            ".../home-manager-path/bin/bash"
  #            ".../bash-interactive-5.3p9/bin/bash"
  #
  # and the whole activation fails at installPackages - AFTER linkGeneration has
  # already written the dotfiles, so you get a working prompt and a container
  # with no claude, no jj, no ripgrep. A confusing way to fail.
  #
  # `package = null` (the option is nullable) keeps every generated file -
  # ~/.bashrc, ~/.bash_profile, ~/.profile, and the starship + direnv hooks in
  # them - while leaving the binary to the base image. Configuring a shell and
  # installing one are separate concerns; here we only want the former.
  #
  # Scoped to this profile on purpose. The collision comes from the base image's
  # pre-populated nix-env profile, which is a container fact, not a Linux one.
  # The darwin profiles keep home-manager's bash deliberately: macOS ships bash
  # 3.2, and home-manager's own bashrc uses `[[ -v ]]`, which needs 4.2+.
  programs.bash.package = null;
}