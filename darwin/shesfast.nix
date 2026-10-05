# shesfast: the personal Mac. Primary user, its admin, who also owns
# its Homebrew. Its home-manager profile is `home`.
#
# Homebrew with `zap`. tasks/20261003-082724/audit/AUDIT.md lists what main
# gives it that this doesn't yet; switch only once that is done.
{ ... }:
{
  # GUI apps: main's list for this Mac, which is also what is installed on it
  # today (/opt/homebrew/Caskroom). Formulae and taps are still to come, so
  # cleanup stays at the module's "none": with "zap", every installed formula
  # would be removed as unlisted.
  homebrew.casks = [
    "arc"
    "brave-browser"
    "claude"
    # clocker is installed here too, but belongs on the work Mac (ditto). With
    # cleanup "none" it stays installed until removed by hand.
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
