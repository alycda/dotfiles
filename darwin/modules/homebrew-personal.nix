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
      "bazelisk"
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
