{ pkgs, lib, nix-vscode-extensions, claude-code-nix, nix-skills, ... }:

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
    (import ../lib/skills-sh.nix nix-skills)
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

  # Create /etc/zshrc that loads the nix-darwin environment.
  #
  # /etc/zshrc is machine-wide: it is read by EVERY account on the box,
  # including users who have never run darwin-rebuild or home-manager (on
  # shesfast, the `ditto` account, which only uses the docker/dev.sh
  # one-liner). nix-darwin's own `compinit` therefore runs for them too, and
  # prompts on every single login:
  #
  #   zsh compinit: insecure directories and files, run compaudit for list.
  #   Ignore insecure directories and files and continue [y] or abort compinit [n]?
  #
  # compaudit rejects an fpath entry (and its parent) that is owned by neither
  # root nor the current user. For a non-admin account that is both
  # /opt/homebrew/share/zsh{,/site-functions} - put on FPATH by the
  # `brew shellenv` in each profile's interactiveShellInit, and owned by the
  # admin user - and the shared nix default profile. Nothing there can be
  # chown'd into compliance: they legitimately belong to another account.
  #
  # The module's compinit takes no flags, so switch it off and run our own
  # with -i: the non-interactive form of answering `y`, dropping insecure
  # directories from fpath rather than trusting them. mkAfter places this
  # after the profiles' interactiveShellInit, so `brew shellenv` has already
  # edited FPATH by the time compinit reads it. Accounts with home-manager
  # additionally run their own compinit from ~/.zshrc; this only governs the
  # accounts that have no home-manager profile.
  #
  # docs/solutions/runtime-errors/zsh-compinit-prompts-every-non-admin-login.md
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    interactiveShellInit = lib.mkAfter ''
      autoload -U compinit && compinit -i
    '';
  };
}
