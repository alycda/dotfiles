{ pkgs, ... }:

{
  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "alyssaevans";

  # Define the user
  users.users.alyssaevans = {
    name = "alyssaevans";
    home = "/Users/alyssaevans";
  };

  # System-level packages for Ditto work machine
  # These need to be system-level (not home-manager) for system services or root access
  environment.systemPackages = with pkgs; [
    # Ditto work-specific
    teleport
    cmake
    openjdk
    # Note: direnv, rustup, etc. should ideally be in home-manager
    # but keeping them here for now to match the backup config
    direnv
    rustup
    rust-analyzer
    lldb
    bacon
    clock-rs
    nil
    nixd  # nix LSP
    cheat
  ];

  # System-level zsh configuration (added to /etc/zshrc)
  programs.zsh.interactiveShellInit = ''
    rustup update
    # rustup toolchain install nightly
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(direnv hook zsh)"
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
