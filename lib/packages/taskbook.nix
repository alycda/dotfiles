# taskbook's Rust port, as mise installs it. flake.nix applies the port's own
# overlay, so pkgs.taskbook is the port here, not nixpkgs' Node.js original.
#
# The overlay installs the release binary as is. On Linux that is linked
# against an FHS glibc loader, which a Nix-only system (the Docker image,
# NixOS) doesn't have: it fails with "cannot execute: required file not
# found". autoPatchelfHook points it at Nix's glibc instead.
{ pkgs }:
[
  (
    if pkgs.stdenv.hostPlatform.isLinux then
      pkgs.taskbook.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.autoPatchelfHook ];
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.stdenv.cc.cc.lib ];
      })
    else
      pkgs.taskbook
  )
]
