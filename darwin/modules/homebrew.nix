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

    # Casks that carry `auto_updates true` (most GUI apps: arc, brave-browser,
    # claude, notion, obsidian, orbstack, visual-studio-code, ...) are skipped
    # by `brew upgrade` - and therefore by the `brew bundle` above - on the
    # assumption that the app updates itself. When the app *can't* (a bundle
    # owned by another account, a non-admin user who can't write the
    # /Applications swap), nothing upgrades it and it nags forever. greedy
    # makes brew the updater for those too: every cask line gets
    # `greedy: true`, i.e. `brew upgrade --cask --greedy`.
    #
    # Cost: brew compares its *recorded* install version, not the app bundle's.
    # An app that self-updated past what homebrew-cask has indexed is reinstalled
    # at the cask's version - a transient downgrade, stable after one switch.
    # `version :latest` casks would reinstall on every switch (no version to
    # compare); none are listed here, so keep an eye out when adding one.
    greedyCasks = true;

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
      "workflowy"
    ];
  };
}
