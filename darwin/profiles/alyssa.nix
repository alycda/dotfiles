{ pkgs, ... }:

{
  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "alyssa";

  # DARWIN Personal machine packages
  environment.systemPackages = with pkgs; [

  ];

  # Personal system settings
  system.defaults.dock.persistent-apps = [
    # Add your personal dock apps here
  ];
}
