# Helix Configuration

This directory contains helix configuration files that serve as:
1. **Documentation** - Human-readable reference for the config
2. **Source of truth** - Manually translated to Nix in `home-manager/modules/tools/helix.nix`

## Architecture

| Context | Helix | Config | LSPs |
|---------|-------|--------|------|
| `nix develop .#tools` | basic | none | none |
| `nix develop` | basic | none | ✓ available |
| home-manager | full | ✓ | ✓ |

### Why this split?

Helix doesn't support a `HELIX_CONFIG_DIR` environment variable. The `--config` flag only loads `config.toml`, not `languages.toml` or `themes/`. This means:

- **devShell**: Provides helix binary + LSPs, but no configuration. Helix here is primarily for cheat's `$EDITOR`.
- **home-manager**: Uses `programs.helix` to generate `~/.config/helix/` with full configuration.

### Future improvement

If helix adds `HELIX_CONFIG_DIR` support, we could:
```nix
shellHook = ''
  export HELIX_CONFIG_DIR="${./tools/helix}"
'';
```

This would give devShell users the same config as home-manager without duplication.

## Files

- `config.toml` - Editor settings (theme, rulers, diagnostics)
- `languages.toml` - Language server configurations
- `themes/mine.toml` - Custom theme (inherits boo_berry)

## Updating config

1. Edit the TOML files here for reference
2. Update `home-manager/modules/tools/helix.nix` with the Nix equivalent
3. Run `home-manager switch` to apply
