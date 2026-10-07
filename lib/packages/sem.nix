# sem (Ataraxy Labs): entity-level diffs, blame and impact analysis. The
# release binary mise installs, at the same version, patched to run from the
# Nix store (lib/release-binary.nix). nixpkgs' `sem` is a different program,
# the Semaphore CI CLI.
{ pkgs }:
let
  release = import ../release-binary.nix { inherit pkgs; };
in
[
  (release {
    pname = "sem";
    version = "0.25.0";
    bin = "sem";
    assets = {
      aarch64-darwin = {
        url = "https://github.com/Ataraxy-Labs/sem/releases/download/v0.25.0/sem-darwin-arm64.tar.gz";
        hash = "sha256-nSjaBjEgO0kkfx76QkzZlEaeO9B+Ah3Rp1IWm3ZZU8s=";
      };
      aarch64-linux = {
        url = "https://github.com/Ataraxy-Labs/sem/releases/download/v0.25.0/sem-linux-arm64.tar.gz";
        hash = "sha256-zgq4+Me7rN4cjth+WhC0zRBzeHBZcoXajNYukFrTvYw=";
      };
      x86_64-linux = {
        url = "https://github.com/Ataraxy-Labs/sem/releases/download/v0.25.0/sem-linux-x86_64.tar.gz";
        hash = "sha256-cVH1d/hO7xazKrZ7v0M2sYeN4fTXoIdYOwoI7k4PtP0=";
      };
    };
  })
]
