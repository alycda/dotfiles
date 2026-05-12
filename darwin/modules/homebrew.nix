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
      # "cirruslabs/cli"
      # "getditto/build-infra"
    ];

    # Formulae (CLI packages)
    # VM validation: Ditto-specific build tools disabled to avoid private tap auth
    brews = [
      # "cirruslabs/cli/tart" # Ditto - VM management
      # "kondo"               # Clean build artifacts
      # "pcre2"
      # "sem-cli"             # Semantic Diff (ataraxy-labs/sem)
      # "swig@4.2.1"          # Ditto
      # "z3"                  # Ditto
    ];

    # Casks (GUI applications)
    # VM validation: most casks disabled. Keeping only what's needed to validate
    # the claude / hermes workflow on this Tart VM.
    casks = [
      "claude"              # Claude desktop app - validating
      "visual-studio-code"  # Keep per user request
      # "android-studio"    # Ditto
      # "arc"
      # "brave-browser"
      # "clocker"
      # "chromedriver"      # Ditto
      # "logseq"
      # "muteme"
      # "notion"
      # "obsidian"
      # "orbstack"
      # "parallels"         # Ditto
      # "rustdesk"
      # "tailscale-app"     # Ditto
      # "warp"
      # "workflowy"
    ];
  };
}
