# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments.
#
# Keep this list LEAN: common.nix imports it into ALL profiles, including the
# headless `dev`/x86 devcontainer, and the flake devShells pull it too. A heavy
# personal tool (e.g. taskbook's Node closure) bloats the disk-constrained 2012
# MBP image for no container benefit — put those in the desktop profiles
# (home.nix, work.nix) instead. Only universal, lightweight CLIs belong here.
pkgs: with pkgs; [
  asciinema
  bat
  ripgrep
  jujutsu
  just
  jq
  gh
  rage
  ragenix
  tmux
]
