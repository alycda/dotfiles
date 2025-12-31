{ config, pkgs, lib, nix-vscode-extensions, ... }:

let
  base = import ./vscode-profiles/base.nix { inherit pkgs; };
  jujutsu = import ./vscode-profiles/jujutsu.nix { inherit pkgs; };
  rust = import ./vscode-profiles/rust.nix { inherit pkgs; };

  # Merge profiles, concatenating extensions instead of replacing
  mergeProfiles = a: b: lib.recursiveUpdate a b // {
    extensions = (a.extensions or []) ++ (b.extensions or []);
  };
in
{
  nixpkgs.overlays = [
    nix-vscode-extensions.overlays.default
  ];

  programs.vscode = {
    enable = true;

    profiles.default = mergeProfiles base {
      extensions = with pkgs; [
        vscode-marketplace.eamodio.gitlens
      ];
    };

    profiles.jujutsu = mergeProfiles base jujutsu;

    profiles.rust = mergeProfiles (mergeProfiles base jujutsu) rust;
  };
}