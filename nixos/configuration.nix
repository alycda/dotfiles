# Shared NixOS system configuration - the Linux sibling of
# darwin/configuration.nix. Machine-specific settings (hostname, hardware,
# desktop, users) live in nixos/profiles/<machine>.nix.
{ pkgs, nix-vscode-extensions, claude-code-nix, nix-skills, charm-nur, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # A group rather than a named user, unlike darwin/configuration.nix: the
    # user is a per-machine fact and belongs in the profile, and every NixOS
    # machine here will have exactly one wheel account anyway.
    trusted-users = [ "@wheel" ];
  };

  nixpkgs = {
    # Inherited by home-manager via useGlobalPkgs = true in flake.nix - the
    # same arrangement as darwin. crush (FSL-1.1-MIT), the vscode marketplace
    # extensions, and the b43 wifi firmware all need it.
    config.allowUnfree = true;

    # The same four overlays as darwin/configuration.nix and flake.nix's
    # mkHome. This is the only place they may be applied for a NixOS machine:
    # home-manager under useGlobalPkgs treats any `nixpkgs.*` setting in a
    # home module as a conflict (see home-manager/modules/ide/vscode.nix).
    overlays = [
      nix-vscode-extensions.overlays.default
      claude-code-nix.overlays.default
      (import ../lib/skills-sh.nix nix-skills)
      (import ../lib/charm-nur.nix charm-nur)
    ];
  };

  # Fonts are system-level here for the reason CLAUDE.md gives for darwin:
  # a font is a shared resource every terminal app must see, and gh-dash /
  # starship render mojibake without the Nerd Font glyphs.
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # Required for `users.users.<name>.shell = pkgs.zsh` to take effect (NixOS
  # refuses a login shell that is not also enabled system-wide). home-manager
  # owns the per-user zsh config; this only registers the shell.
  programs.zsh.enable = true;

  # Stateful-defaults marker, NOT a version to bump on upgrades: set it to the
  # release the machine was first installed from and leave it. Matches the
  # 26.05 installer ISO this was written against; if the install happens from
  # a different ISO generation, change it once, before the first switch.
  system.stateVersion = "26.05";
}
