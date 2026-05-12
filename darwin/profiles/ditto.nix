{ pkgs, ... }:

{
  imports = [
    ../modules/homebrew.nix
  ];
  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "admin";

  # Define the user
  users.users.admin = {
    name = "admin";
    home = "/Users/admin";
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
  '';

  # VM validation: trimmed dock to only apps that will actually be installed
  system.defaults.dock.persistent-apps = [
    "/Applications/Visual Studio Code.app"
    "/Applications/Utilities/Terminal.app"
  ];
}
