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
    # Homebrew 6.0 enables HOMEBREW_REQUIRE_TAP_TRUST by default: loading a
    # formula from an untrusted third-party tap aborts activation, so declare
    # trust here instead of imperative per-machine `brew trust`.
    taps = [
      {
        name = "cirruslabs/cli";
        trusted = true;
      }
      {
        name = "getditto/build-infra";
        clone_target = "git@github.com:getditto/homebrew-build-infra.git";
        trusted = true;
      }
    ];

    # Formulae (CLI packages)
    brews = [
      "cirruslabs/cli/tart" # Ditto - VM management
      "envelope"
      "hunk"
      "kondo"           # Clean build artifacts
      "pcre2"
      "sem-cli"         # Semantic Diff (ataraxy-labs/sem)
      "swig@4.2.1"      # Ditto
      "worktrunk" # git worktree management for parallel AI agent workflows
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
      "codex"           # Ditto
      "cmux"
      "logseq-og" # classic file/markdown Logseq; plain "logseq" is now the 2.0 DB version
      "muteme"
      "notion"
      "obsidian"
      "ollama-app"
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
