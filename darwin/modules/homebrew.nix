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
      "android-studio" # Ditto
      "arc"
      "brave-browser"
      "clocker"
      "chromedriver" # Ditto
      "docker-desktop"
      "muteme"
      "orbstack"
      "parallels" # Ditto
      "tailscale-app" # Ditto
      "visual-studio-code"
      "warp"
      "workflowy"
    ];
  };
}
