# Helix

[Helix](https://helix-editor.com/) is a post-modern terminal-based text editor with batteries included. It's written in Rust and takes inspiration from Kakoune and Neovim.

Key features:
- **Multiple selections** as a core editing primitive (like Kakoune)
- **Built-in LSP support** - language servers work out of the box
- **Tree-sitter integration** - for syntax highlighting and text objects
- **No plugin system needed** - common features are built-in (fuzzy finder, file picker, etc.)

The command `hx` launches the editor. Press `?` in normal mode to see available keybindings.

## Configuration

The TOML files in this directory are the config. Both kinds of account read
them as they are:

- **Nix accounts:** `home-manager/modules/tools/helix.nix` reads each file with
  `fromTOML` and adds the language servers as packages. Edit the TOML, then run
  `home-manager switch`.
- **The account with no Nix (mise):** link the directory once, and edits apply
  the next time helix starts:
  ```sh
  ln -s ~/dotfiles/tools/helix ~/.config/helix
  ```
  That account has helix from mise but none of the language servers.
  `hx --health` lists them as `not found in $PATH`, and helix just doesn't
  start them.

## Why not the devShell?

Helix doesn't support a `HELIX_CONFIG_DIR` environment variable, and `--config`
only loads `config.toml`, not `languages.toml` or `themes/`. So the devShell
ships helix (for cheat's `$EDITOR`) and language servers but no config.

| Context | Helix | Config | LSPs |
|---------|-------|--------|------|
| `nix develop .#tools` | basic | none | none |
| `nix develop` | basic | none | ✓ available |
| home-manager | full | ✓ | ✓ |
| mise account (linked dir) | full | ✓ | none |

## Files

- `config.toml` - Editor settings (theme, rulers, diagnostics)
- `languages.toml` - Language and language server settings
- `themes/mine.toml` - Custom theme (inherits boo_berry)
- `ignore` - Global file-picker ignore rules
