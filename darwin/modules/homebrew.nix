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
        # Ataraxy Labs entity-level git stack (weave, inspect below; sem comes
        # from core as sem-cli). See the entity-level-git agent skill.
        name = "ataraxy-labs/tap";
        trusted = true;
      }
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
      "ataraxy-labs/tap/inspect" # Entity-level PR review triage (ataraxy-labs/inspect)
      "ataraxy-labs/tap/weave"   # Entity-level merge driver (ataraxy-labs/weave)
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
      "chatgpt"         # Ditto
      "chromedriver"    # Ditto
      "codex"           # Ditto
      "cmux"
      # Nerd Font for starship's nerd-font-symbols preset (home-manager/modules/
      # tools/starship.nix). Glyphs are resolved by the terminal emulator, so
      # this also covers the prompt inside the container - that prompt is drawn
      # by the host terminal. Installing it is not enough: select it as the font
      # in the terminal's own settings (cmux), or you get tofu boxes.
      "font-jetbrains-mono-nerd-font"
      "logseq-og" # classic file/markdown Logseq; plain "logseq" is now the 2.0 DB version
      "loom"
      "muteme"
      "notion"
      "obsidian"
      "ollama-app"
      "orbstack"
      "parallels"       # Ditto     
      "rustdesk" 
      "tailscale-app"   # Ditto
      "visual-studio-code"
      # "warp" # replaced by cmux as the daily terminal. Left commented rather
      # than deleted because onActivation.cleanup = "zap" means re-adding it is
      # a fresh install with no settings - worth seeing that it was a choice.
      "workflowy"
    ];
  };
}
