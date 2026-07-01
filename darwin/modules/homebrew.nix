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
      "oxen-ai/oxen-server"
    ];

    # Formulae (CLI packages)
    brews = [
      "cirruslabs/cli/tart" # Ditto - VM management
      "awscli"
      "clang-format"
      "cmake"
      "criterion"       # C test framework
      "envelope"        # Env vars manager (nix build pending on claude/envelope-cargo-install)
      "flamegraph"
      "gemini-cli"
      "git-lfs"
      "glow"            # Markdown TUI renderer
      "graphviz"
      "kondo"           # Clean build artifacts
      "llmfit"          # Estimate local-LLM fit for this machine
      "llvm"
      "nmap"
      "ollama"
      "openjdk@17"      # Ditto - Android/JVM SDK toolchain
      "oxen"            # Oxen.ai data versioning
      "oxen-ai/oxen-server/oxen-server"
      "pcre2"
      "pkgconf"
      "poppler"         # PDF tooling
      "python@3.13"
      "sem-cli"         # Semantic Diff (ataraxy-labs/sem)
      "shfmt"
      "silicon"         # Code screenshot tool
      "swig@4.2.1"      # Ditto
      "vhs"             # Terminal GIF recorder
      "wakeonlan"
      "wget"
      "z3"              # Ditto
    ];

    # Casks (GUI applications)
    casks = [
      "android-studio"  # Ditto
      "arc"
      "brave-browser"
      "chatgpt"
      "claude"
      "clocker"
      "cmux"            # Ghostty-based terminal for AI coding agents
      "chromedriver"    # Ditto
      "codex"
      "kitty"
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
