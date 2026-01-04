# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments
pkgs: with pkgs; [
  # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  bat
  ripgrep
  jujutsu
  just
  gh
  claude-code
]
