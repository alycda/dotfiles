{ pkgs, nix-vscode-extensions, claude-code-nix, ... }:

{
  # Nix package manager settings
  nix.settings = {
    # Enable flakes and nix-command
    experimental-features = [ "nix-command" "flakes" ];

    # Allow users to use nix without sudo (needed for flakes)
    trusted-users = [ "@admin" "alyssaevans" ];

    # Build users
    build-users-group = "nixbld";
  };

  # Allow unfree packages (inherited by home-manager via useGlobalPkgs=true in flake.nix)
  nixpkgs.config.allowUnfree = true;

  # Apply VSCode marketplace overlay at system level
  # This overlay is inherited by home-manager via useGlobalPkgs=true in flake.nix
  # For standalone home-manager (non-darwin), the overlay is applied in flake.nix's mkHome function
  nixpkgs.overlays = [
    nix-vscode-extensions.overlays.default
    claude-code-nix.overlays.default
  ];

  # macOS system defaults
  system.defaults = {
    # Dock settings
    dock = {
      autohide = true;
      orientation = "bottom";
      mru-spaces = false;

      # Hot corners
      wvous-tl-corner = 2;  # mission control
      wvous-tr-corner = 4;  # desktop
      wvous-br-corner = 13; # lock screen
      wvous-bl-corner = 24; # quick note
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

      "com.apple.swipescrolldirection" = false;
    };
  };

  # Fonts - installed at system level so all apps can access them
  # Fira Code Nerd Font is used by gh-dash and terminal tools for icon glyphs
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # Used for backwards compatibility, please read the changelog before changing
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # Create /etc/zshrc that loads the nix-darwin environment
  programs.zsh.enable = true;
}
