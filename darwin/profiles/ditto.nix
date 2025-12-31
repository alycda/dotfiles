{ pkgs, ... }:

{
  # Primary user for this machine (required for user-specific defaults)
  system.primaryUser = "alyssaevans";

  # DARWIN Work-specific packages
  environment.systemPackages = with pkgs; [

  ];

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