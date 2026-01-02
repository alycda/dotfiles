# Ditto Machine Setup

Machine-specific documentation for the work machine (ditto).

## Manual Installations

Some tools cannot be managed by Nix or Homebrew and require manual installation.

### Puro (Flutter version manager)

[Puro](https://puro.dev/) is a Flutter version manager that must be installed manually:

```bash
curl -fsSL https://puro.dev/install.sh | bash
```

After installation, set up your Flutter version:

```bash
# Install and use a specific Flutter version globally
puro use -g 3.27.4
```

**Why not Nix?** Puro dynamically manages Flutter SDKs and integrates with system paths in ways that conflict with Nix's isolated package management.

**Environment setup for Flutter development:**
- Android SDK: `$HOME/Library/Android/sdk`
- NDK: Managed via Android SDK Manager
- SWIG: Install via Homebrew (`brew install swig`)

### Installation via Nix-Darwin

Puro is automatically installed via a `system.activationScripts` hook in [ditto.nix](profiles/ditto.nix). This ensures:

1. **Idempotent installation**: Only installs if not already present
2. **Persistence**: Installs to `~/.puro` which persists across rebuilds
3. **User-level**: Runs as the user (not root) via `sudo -u`

The activation script runs on every `darwin-rebuild switch`, checking if puro exists before attempting installation.

**Why activation scripts?**
- Puro cannot be packaged in nixpkgs (dynamic SDK manager)
- Manual curl installation is required by puro's design
- `~/.puro` is in the user's home directory, so it persists across macOS rebuilds
- See: [nix-darwin activation scripts documentation](https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/activation-scripts.nix)

**Post-installation:**
After the first rebuild, set your Flutter version:
```bash
puro use -g 3.27.4
```
