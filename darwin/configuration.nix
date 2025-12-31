{ config, pkgs, nix-vscode-extensions, ... }:

{
  # Nix package manager settings
  nix.settings = {
    # Enable flakes and nix-command
    experimental-features = [ "nix-command" "flakes" ];

    # Allow users to use nix without sudo (needed for flakes)
    trusted-users = [ "@admin" "alyssaevans" "alyssa" ];

    # Build users
    build-users-group = "nixbld";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Apply VSCode marketplace overlay at system level
  nixpkgs.overlays = [
    nix-vscode-extensions.overlays.default
  ];

  # # System-wide packages available to all users
  # environment.systemPackages = with pkgs; [
  #   vim
  #   git
  # ];

  # macOS system defaults
  system.defaults = {
    # Dock settings
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
    };

    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    # NSGlobalDomain settings (general macOS preferences)
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;

      # Disable auto-correct and auto-capitalize
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    # # Trackpad settings
    # trackpad = {
    #   Clicking = true;  # tap to click
    # };
  };

  # Used for backwards compatibility, please read the changelog before changing
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # Create /etc/zshrc that loads the nix-darwin environment
  programs.zsh.enable = true;
}
