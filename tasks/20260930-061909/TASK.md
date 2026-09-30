# dev.sh: the taskbook hook inside the container

- STATUS: OPEN
- TAGS: docker, claude, taskbook

## Description

The `SessionEnd` hook (tools/claude/hooks) covers sessions on the host and in
the mise devcontainer. `docker/dev.sh` lives on `main`, and a container it
starts misses three things, so a Claude session in one leaves nothing on the
`@claude` board:

- **`tb` in the image.** `lib/packages.nix` has no taskbook, and nixpkgs has no
  package for the Rust port. Its flake (`github:taskbook-sh/taskbook`) or the
  `tb-linux-*.tar.gz` release asset would do.
- **The data.** `-v "$HOME/.taskbook":/root/.taskbook` in `run_container`,
  beside the devhome and claude-home volumes, so items land in the host's
  `storage.json`. A volume would be a second board nothing outside reads.
- **The hook.** `~/.claude` in there is the claude-home volume, so its
  `settings.json` needs `tools/claude/install-hooks` run against it
  (`docker/entrypoint.sh`, or the home-manager claude-code module), with the
  script at `/root/.claude/hooks/session-end-taskbook.sh`.

The Nix devcontainer (`.devcontainer.json`) is in the same position: no `tb`
in `lib/packages.nix`, and home-manager doesn't link the script yet. Both
follow the decision in `tools/mise/global.toml` to leave taskbook out of Nix
for now.

Two writers on one `storage.json` (a host session and a container session
ending together): tb takes `storage.lock` around writes.
