# shesfast: the personal Mac. Primary user, its admin, who also owns
# its Homebrew. Its home-manager profile is `home`.
#
# Homebrew with `zap`. tasks/20261003-082724/audit/AUDIT.md lists what main
# gives it that this doesn't yet; switch only once that is done.
{ ... }:
{
  # As on main: every switch updates Homebrew, upgrades what is listed
  # (casks greedily), and removes with "zap" whatever no list below names,
  # app data included. A cask or formula left off a list is uninstalled.
  # App Store apps are never removed.
  homebrew.onActivation = {
    cleanup = "zap";
    autoUpdate = true;
    upgrade = true;
  };

  # Taps and formulae. Homebrew is shared by every account on this Mac, Nix
  # packages reach alyssa only, so the formulae here are the ones another
  # account uses too. The rest of main's formulae come from Nix (the home
  # profile); sem comes from Nix for alyssa and mise for the others.
  homebrew.taps = [
    {
      name = "withgraphite/tap";
      # Homebrew 6 won't load a formula from an untrusted third-party tap.
      trusted = true;
    }
  ];
  homebrew.brews = [
    # The docker CLI; the daemon is OrbStack (a cask). OrbStack's own CLI is
    # per user; this one is on every account's PATH.
    "docker"
    # Keychain-backed secrets as environment variables. The mise account
    # (ditto) runs this copy: it can run formulae, not install them.
    "envchain"
    # Graphite's CLI, for stacked PRs. Unfree in nixpkgs, so from its tap.
    "withgraphite/tap/graphite"
  ];

  # GUI apps: main's list for this Mac, which is also what is installed on it
  # today (/opt/homebrew/Caskroom).
  homebrew.casks = [
    "arc"
    "brave-browser"
    "claude"
    # clocker, installed here today, belongs on the work Mac (ditto); "zap"
    # removes it on the first switch.
    "cmux"
    "dropbox"
    # A Nerd Font, for a prompt with icons (starship, once it is ported).
    # Select it in the terminal's own settings, or the glyphs show as boxes.
    "font-jetbrains-mono-nerd-font"
    "google-drive"
    # The classic file-and-markdown Logseq. Plain "logseq" is now the 2.0
    # database version, and an upgrade would migrate the app to it.
    "logseq-og"
    "obsidian"
    "orbstack"
    "proton-drive"
    "proton-mail"
    "proton-pass"
    "rustdesk"
    "tailscale-app"
    "visual-studio-code"
    "workflowy"
    "zoom"
  ];

  # Mac App Store apps, by name and App Store ID, installed by `mas` in the
  # same `brew bundle`. mas installs only apps the Apple ID already has, so
  # get each one in the App Store once, signed in. Cleanup never removes
  # these.
  homebrew.masApps = {
    # A second clock in the menu bar (sindresorhus.com/second-clock). No
    # Homebrew cask. 1.2.0 needs macOS 26, which shesfast is moving to; on
    # macOS 15 the App Store won't install it.
    "Second Clock" = 6450279539;
  };
}
