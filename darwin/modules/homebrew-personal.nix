_:

{
  # Personal-machine (shesfast) homebrew set. Same zap discipline as the work
  # module: anything installed but not listed here is removed on activation.
  homebrew = {
    enable = true;

    # Remove packages/casks not listed here and update on activation
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };

    # Casks that carry `auto_updates true` (most GUI apps: arc, brave-browser,
    # claude, dropbox, obsidian, orbstack, proton-*, zoom, ...) are skipped
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

    # Export HOMEBREW_BUNDLE_FILE pointing at the generated Brewfile, so a bare
    # `brew bundle install` upgrades exactly what's declared here - that's what
    # `just brew-upgrade` uses to pull cask updates between switches, since
    # nix-darwin only runs brew during activation. This lands in /etc/zshenv and
    # so reaches every account on the machine (see the CLAUDE.md note about
    # system-level shell config); it's inert for an account with no Homebrew.
    global.brewfile = true;

    taps = [
      {
        name = "cirruslabs/cli";
        trusted = true;
      }
      {
        name = "charmbracelet/tap";
        trusted = true;
      }
    ];

    # Formulae (CLI packages). Deliberately NOT listed because nix/home-manager
    # provides them (common.nix / core-packages): asciinema, gh, helix, jj,
    # node. Their brew copies get zapped and the nix ones take over.
    brews = [
      "cirruslabs/cli/tart" # VM management
      "docker" # CLI only; the daemon is OrbStack (cask below)
      "kondo" # Clean build artifacts
      "llmfit"
      "ollama"
      "openvpn"
      "poppler" # pdftotext & friends (also keeps the gpgme/gnupg dep chain)
      "sem-cli" # Semantic Diff (ataraxy-labs/sem)
      "typst"
      "wishlist" # charmbracelet SSH directory
    ];

    # Casks (GUI applications) - declares what is installed today, minus
    # deliberate swaps. Prune later, one decision at a time, not during the
    # initial conversion.
    casks = [
      "arc"
      "brave-browser"
      "claude"
      "clocker"
      # cmux.app was installed manually, not via brew, and the nix-darwin cask
      # args submodule cannot express brew's --adopt. Delete the manual
      # /Applications/cmux.app BEFORE the first switch or `brew bundle` aborts
      # with "App already exists" mid-activation (app-local config in
      # ~/Library survives the delete).
      "cmux"
      "dropbox"
      # Nerd Font for starship's nerd-font-symbols preset - see the note in
      # the work homebrew module.
      "font-jetbrains-mono-nerd-font"
      "google-drive"
      "kitty"
      # Installed today as plain "logseq", but that token now ships the 2.0 DB
      # version and onActivation.upgrade would migrate the app on first switch.
      # logseq-og is the classic file/markdown build (same choice as ditto).
      # Graphs live in user-chosen folders and survive; back up ~/.logseq
      # (settings/plugins) before the first switch anyway.
      "logseq-og"
      "nordpass"
      "obsidian"
      "orbstack"
      "proton-drive"
      "proton-mail"
      "proton-pass"
      "rustdesk"
      "tailscale-app"
      "visual-studio-code"
      # Kept on this machine even though ditto dropped it for cmux; remove
      # deliberately once cmux is confirmed as the daily terminal here too.
      "warp"
      "workflowy"
      "zoom"
    ];
  };
}
