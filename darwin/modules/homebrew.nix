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
      "cirruslabs/cli"
      "getditto/build-infra"
    ];

    # Formulae (CLI packages)
    brews = [
      "cirruslabs/cli/tart" # Ditto - VM management
      "gemini-cli"
      "kondo"           # Clean build artifacts
      "pcre2"
      "sem-cli"         # Semantic Diff (ataraxy-labs/sem)
      "swig@4.2.1"      # Ditto
      "z3"              # Ditto
    ];

    # Casks (GUI applications)
    casks = [
      "android-studio"  # Ditto
      "arc"
      "brave-browser"
      "claude"
      "clocker"
      "chromedriver"    # Ditto
      "codex"
      "logseq"
      "muteme"
      "notion"
      "obsidian"
      "orbstack"
      "parallels"       # Ditto     
      "rustdesk" 
      "tailscale-app"   # Ditto
      "visual-studio-code"
      "warp"
      "workflowy"
    ];
  };
}
