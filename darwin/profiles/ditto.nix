{ pkgs, ... }:

{
  imports = [
    ../modules/homebrew.nix
  ];
  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "alyssaevans";

  # Define the user
  users.users.alyssaevans = {
    name = "alyssaevans";
    home = "/Users/alyssaevans";
  };

  # DARWIN System-level packages for Ditto machine
  environment.systemPackages = with pkgs; [
    clock-rs
  ];

  # System-level zsh configuration (added to /etc/zshrc)
  programs.zsh.interactiveShellInit = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(direnv hook zsh)"

    # Add puro to PATH
    export PATH="$HOME/.puro/bin:$PATH"
  '';

  # Install puro (Flutter version manager) on system activation
  # Puro installs to ~/.puro by default, which should persist across rebuilds
  system.activationScripts.puro.text = ''
    PURO_USER="alyssaevans"
    PURO_HOME="/Users/$PURO_USER"

    if [ ! -f "$PURO_HOME/.puro/bin/puro" ]; then
      echo "Installing puro for $PURO_USER..." >&2
      # Run as the user, not root
      sudo -u "$PURO_USER" /bin/bash -c 'curl -fsSL https://puro.dev/install.sh | bash'
    else
      echo "Puro already installed at $PURO_HOME/.puro" >&2
    fi
  '';

  # Work-specific system settings
  system.defaults.dock.persistent-apps = [
    # Finder
    "/Applications/Warp.app"
    "/Applications/Slack.app"
    "/Applications/Brave Browser.app"
    "/Applications/Workflowy.app"
    "/Applications/Visual Studio Code.app"
    # Google Drive
    # Speediness
    # Stickies
    "/Applications/Arc.app"
    "/Applications/Notion.app"
  ];
}
