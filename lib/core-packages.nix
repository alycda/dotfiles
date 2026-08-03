# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments
pkgs: with pkgs; [
  asciinema
  bat
  eza
  ripgrep
  jujutsu
  just
  jq
  gh
  rage
  ragenix
  taskbook
  tmux
]
