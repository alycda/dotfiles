_:

{
  imports = [
    ../modules/homebrew-personal.nix
  ];

  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "alyssa";

  # Define the user
  users.users.alyssa = {
    name = "alyssa";
    home = "/Users/alyssa";
  };

  # System-level zsh configuration (added to /etc/zshrc)
  programs.zsh.interactiveShellInit = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
  '';

  # No system.defaults.dock.persistent-apps here: leaving it unset preserves
  # the dock as-is instead of replacing it (that option is authoritative when
  # set - see ditto.nix).
}
