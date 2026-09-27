# home-manager takeover of zsh: open questions

- STATUS: OPEN
- TAGS: home-manager, zsh, mise

## Description

home-manager now owns `~/.zshrc` and `~/.zshenv` (programs.zsh). On an account
mise set up first, a switch with `-b backup` moves mise's `~/.zshrc` aside.
What that leaves open:

- **mise after the takeover.** The root `mise.toml` still adds a line to
  `~/.zshrc` (`[dotfiles]` line mode). Once `~/.zshrc` is a link into the
  read-only Nix store, `mise dotfiles apply` probably fails there. Check it, then
  decide: skip that entry when home-manager owns the file, or stop running
  mise's `[dotfiles]` on Nix accounts.
- **mise's own activation.** The takeover drops `mise activate zsh` from
  `~/.zshrc`, so mise's tools leave PATH. Either uninstall mise once the Nix
  profile provides the same tools (how, and what to clean up: `~/.local/bin/mise`,
  its data and conf.d links), or have home-manager manage a minimal mise
  (`programs.mise`) that doesn't read the root `mise.toml`.
- **PATH.** home-manager doesn't put `~/.nix-profile/bin` on PATH. In the
  devcontainer the Nix feature does, so nix.yml's home job doesn't check it.
  Decide whether the profile should (for example `targets.genericLinux.enable`)
  and add a check.
