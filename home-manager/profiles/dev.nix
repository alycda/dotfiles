# devcontainers / codespaces
{ pkgs, ... }:

{
  home = {
    username = "root";
    homeDirectory = "/root";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
    ];
  };

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