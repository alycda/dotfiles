_:

{
  # Enable homebrew integration
  homebrew = {
    enable = true;

    # Remove packages/casks not listed here and update on activation
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };

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
      "cirruslabs/cli/tart" # Ditto
      "claude"
      "clocker"
      "chromedriver" # Ditto
      "kondo"
      "logseq"
      "muteme"
      "notion"
      "obsidian"
      "orbstack"
      "parallels" # Ditto     
      "rustdesk" 
      "tailscale-app" # Ditto
      "visual-studio-code"
      "warp"
      "workflowy"
    ];
  };
}
