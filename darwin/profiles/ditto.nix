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
    xcodegen
  ];

  # System-level zsh configuration (added to /etc/zshrc)
  programs.zsh.interactiveShellInit = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(direnv hook zsh)"
    if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
  '';

  # Work-specific system settings
  system.defaults.dock.persistent-apps = [
    # Finder
    "/Applications/RustDesk.app"
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
    "/Applications/OrbStack.app"
    "/Applications/Utilities/Terminal.app"
  ];
}
