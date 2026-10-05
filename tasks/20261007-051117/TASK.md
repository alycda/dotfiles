# nix(hm): what else the code account needs, from main

- STATUS: OPEN
- TAGS: nix, home-manager, code, dev, parity

## Description

`code` is the Mac account without sudo on Shesfast (in `nix-users`, not `admin`).

### Language servers

`code` HAD gopls/dlv, zig/zls, harper, just-lsp, swift-format,
typescript and vscode-*-language-server, golangci-lint-langserver,

### Outside Nix, kept by a switch

`~/.rustup` (stable, nightly-2024-08-01, nightly-2025-08-01),
`~/.cargo/bin` (wasm-pack, wr), `~/.orbstack` (the docker engine),
`~/.age/personal-key.txt`.

## Open questions

- Does `code` keep jdtls, kotlin-language-server and dart? Assumed no
  (work profile only) until decided.
- presenterm: every profile, dev only, or not at all? (nil: dev, decided
  2026-10-07; nixd not added.)
- zig and cargo-zigbuild in `rust.nix`, for Linux builds from the Mac:
  suggested, not decided. nodejs is in `zotxyvzx`'s core list; whether it
  moves to dev only is open.
- `code` standalone (switches itself) or as `home-manager.users.code`? Assumed standalone

## Verification

Verified as `code`:

```sh
nix eval .#homeConfigurations.\"code@aarch64-darwin\".activationPackage.drvPath
nix eval .#homeConfigurations.\"vscode@aarch64-linux\".activationPackage.drvPath
nix run .#home-manager -- build --flake .#code@aarch64-darwin
nix run .#home-manager -- switch -b backup --flake .#code@aarch64-darwin
cargo --version && rustup component list --installed | grep rust-analyzer
which tb
```
