{ pkgs, lib, ... }:

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
  # No `nixpkgs.overlays` here. `pkgs.vscode-marketplace` comes from the
  # nix-vscode-extensions overlay, and every place this module can be
  # evaluated already applies that overlay to the pkgs it hands us: mkHome in
  # flake.nix, darwin/configuration.nix, and nixos/configuration.nix (all
  # three with useGlobalPkgs where a system module is involved). This module
  # used to re-apply it behind a `config.targets.darwin` sniff meant to skip
  # nix-darwin, but home-manager treats any `nixpkgs.*` setting under
  # useGlobalPkgs as a conflict - a warning today, slated to become an error -
  # so the sniff would have to know about NixOS too. Owning the overlay at the
  # pkgs-construction site is the rule CLAUDE.md already states (Configuration
  # Conflicts, item 1); this module just consumes the result.
  programs.vscode = {
    enable = true;

    profiles = {
      default = mergeProfiles base {
        extensions = with pkgs; [
          vscode-marketplace.github.vscode-github-actions
          vscode-marketplace.eamodio.gitlens
          vscode-marketplace.github.vscode-pull-request-github
        ];
      };

      ditto = mergeProfiles (mergeProfiles base {
        extensions = with pkgs; [
          vscode-marketplace.dart-code.flutter
          vscode-marketplace.github.vscode-github-actions
          vscode-marketplace.github.vscode-pull-request-github
          vscode-marketplace.mathiasfrohlich.kotlin
          # vscode-marketplace.ms-vscode.cpptools # removed on aarch64-darwin
          vscode-marketplace.ms-vscode.makefile-tools
          vscode-marketplace.swiftlang.swift-vscode
          vscode-marketplace.vscjava.vscode-gradle
        ];
      }) jujutsu;

      jujutsu = mergeProfiles base jujutsu;

      rust = mergeProfiles (mergeProfiles base jujutsu) rust;
    };
  };
}
