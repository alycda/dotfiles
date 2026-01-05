# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments
pkgs: with pkgs; [
  bat
  ripgrep
  jujutsu
  just
  gh
]
