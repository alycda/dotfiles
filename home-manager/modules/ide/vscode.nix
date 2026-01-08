{ config, pkgs, lib, nix-vscode-extensions, ... }:

let
  base = import ./vscode-profiles/base.nix { inherit pkgs; };
  jujutsu = import ./vscode-profiles/jujutsu.nix { inherit pkgs; };
  rust = import ./vscode-profiles/rust.nix { inherit pkgs; };

  # Merge profiles, concatenating extensions instead of replacing
  mergeProfiles = a: b: lib.recursiveUpdate a b // {
    extensions = (a.extensions or []) ++ (b.extensions or []);
  };

  # Check if we're running under nix-darwin (which has useGlobalPkgs=true)
  # If so, overlays are set at darwin/configuration.nix and inherited
  isDarwin = config.targets.darwin or null != null;
in
{
  # Only set overlays for standalone home-manager (non-darwin)
  # For darwin configs, overlays are inherited via useGlobalPkgs=true
  nixpkgs.overlays = lib.mkIf (!isDarwin) [
    nix-vscode-extensions.overlays.default
  ];

  programs.vscode = {
    enable = true;

    profiles = {
      default = mergeProfiles base {
        extensions = with pkgs; [
          vscode-marketplace.github.vscode-github-actions
          vscode-marketplace.eamodio.gitlens
        ];
      };

      ditto = mergeProfiles (mergeProfiles base {
        extensions = with pkgs; [
          vscode-marketplace.dart-code.flutter
          vscode-marketplace.github.vscode-github-actions
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
