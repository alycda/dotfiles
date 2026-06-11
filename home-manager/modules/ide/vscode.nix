{ config, pkgs, lib, nix-vscode-extensions, ... }:

let
  base = import ./vscode-profiles/base.nix { inherit pkgs; };
  jujutsu = import ./vscode-profiles/jujutsu.nix { inherit pkgs; };
  rust = import ./vscode-profiles/rust.nix { inherit pkgs; };

  # Ditto's vsc-es extension is distributed as a .vsix attached to a private
  # GitHub release (https://github.com/getditto/vsc-es/releases), so neither
  # the marketplace overlay nor fetchurl can retrieve it. requireFile makes
  # the dependency declarative while the download stays manual.
  #
  # One-time setup per version bump (browser session with getditto access):
  #   1. Download the .vsix from
  #      https://github.com/getditto/vsc-es/releases/tag/v0.8.0
  #   2. nix-store --add-fixed sha256 vsc-es-0.8.0.vsix
  #   3. Replace the hash below with the output of:
  #      nix hash file vsc-es-0.8.0.vsix
  vsc-es = pkgs.vscode-utils.buildVscodeExtension {
    pname = "vsc-es";
    version = "0.8.0";
    src = pkgs.requireFile {
      name = "vsc-es-0.8.0.vsix"; # TODO: confirm asset filename on the release
      url = "https://github.com/getditto/vsc-es/releases/tag/v0.8.0";
      hash = lib.fakeHash; # TODO: replace per the steps above
    };
    # TODO: confirm publisher/name against the package.json inside the .vsix
    vscodeExtPublisher = "ditto";
    vscodeExtName = "vsc-es";
    vscodeExtUniqueId = "ditto.vsc-es";
  };

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
          vsc-es
        ];
      }) jujutsu;

      jujutsu = mergeProfiles base jujutsu;

      rust = mergeProfiles (mergeProfiles base jujutsu) rust;
    };
  };
}
