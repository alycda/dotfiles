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

### Persistence Issue

**Problem:** Puro installation gets wiped on `darwin-rebuild switch`

**Investigation needed:**
- Can nix-darwin run the curl installation automatically?
- Should this be handled via system activation scripts?
- Or does puro need a different installation location to persist?
