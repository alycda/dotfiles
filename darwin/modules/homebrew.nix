{ config, pkgs, ... }:

{
  # Enable homebrew integration
  homebrew = {
    enable = true;

    # Remove packages/casks not listed here
    onActivation.cleanup = "zap";

    # Update homebrew and packages on activation
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    # Custom taps
    taps = [
      "getditto/build-infra"
    ];

    # Formulae (CLI packages)
    brews = [
      "pcre2"
      "swig@4.2.1"
    ];

    # Casks (GUI applications)
    casks = [
      "android-studio"
      "arc"
      "brave-browser"
      "clocker"
      "docker-desktop"
      "muteme"
      "notion"
      "orbstack"
      "parallels"
      "slack"
      "tailscale-app"
      "visual-studio-code"
      "warp"
      "workflowy"
    ];
  };
}
