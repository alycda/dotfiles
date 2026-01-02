# Puro Development Journey: From Temp Shell to Persistent Installation

This document chronicles the evolution from temporary nix-shell experiments to a persistent, automated puro installation via nix-darwin activation scripts.

## Timeline of Attempts

### Phase 1: Discovery & Initial Attempts (Early experiments)

**Problem**: Need Flutter for building Android SDK
- `which flutter` → not found
- `brew info puro` → investigating puro as Flutter version manager
- `brew search puro` → puro not available in Homebrew

**Key insight**: Puro cannot be installed via Homebrew, must use curl installer

---

### Phase 2: Nix-Shell with OpenJDK (First integration attempt)

```bash
nix-shell -p openjdk
```

**Approach**: Use nix-shell for dependencies, but still missing Flutter/puro
- Had OpenJDK from nix
- Still needed to figure out Flutter installation
- `make build-flutter-android` was the goal

---

### Phase 3: Complex Temporary Installation (The "throw it all in one command" phase)

```bash
nix-shell -p openjdk --run '
  export PURO_ROOT="$PWD/.nix-tmp-puro"
  mkdir -p "$PURO_ROOT"
  curl -fsSL https://puro.dev/install.sh | PURO_ROOT="$PURO_ROOT" bash
  export PATH="$PURO_ROOT/bin:$PATH"

  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export NDK_VERSION="23.1.7779620"
  export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"

  puro use -g 3.27.4
  make build-flutter-android
  rm -rf "$PURO_ROOT"
'
```

**Issues**:
- Extremely verbose one-liner
- Had to paste this manually every time
- Installation happened every single time (slow)
- Cleanup at the end meant no persistence
- Multiple variations tried with different flags

**Iterations**:
1. First attempt: Basic temp installation
2. Second attempt: Added `--no-modify-path` flag to puro installer
3. Third attempt: Added `puro create 3.27.4` before `puro use`
4. Fourth attempt: Added Flutter SDK location verification

---

### Phase 4: Shell.nix File (Attempting to codify the mess)

Created `home-manager/modules/dev/dart.nix` (misnamed as shell.nix):

```nix
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Note: swig from homebrew tap, not nix
  ];

  shellHook = ''
    export PURO_ROOT="$PWD/.nix-tmp-puro"
    mkdir -p "$PURO_ROOT"

    echo "📦 Installing puro temporarily..."
    curl -fsSL https://puro.dev/install.sh | PURO_ROOT="$PURO_ROOT" bash

    export PATH="$PURO_ROOT/bin:$PATH"

    # Android environment setup
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export NDK_VERSION="23.1.7779620"
    export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"

    cleanup() {
      echo "🧹 Cleaning up puro installation..."
      rm -rf "$PURO_ROOT"
    }
    trap cleanup EXIT

    echo "Next steps:"
    echo "  1. puro use -g 3.27.4"
    echo "  2. make build-flutter-android"
  '';
}
```

**Usage**:
```bash
nix-shell shell.nix  # or later just: nix-shell
```

**Problems**:
- Still temporary installation on every shell entry
- Still doing cleanup on exit
- Slow to enter the shell
- File was in wrong location (home-manager modules, not a standalone shell.nix)
- Filename mismatch (dart.nix vs shell.nix content)

---

### Phase 5: "Just Install It Globally" (Breakthrough moment)

After many rebuilds where puro kept disappearing:

```bash
curl -fsSL https://puro.dev/install.sh | bash
which puro  # → puro not found
sudo darwin-rebuild switch
which puro  # → puro not found
curl -fsSL https://puro.dev/install.sh | bash
which puro  # → /Users/alyssaevans/.puro/bin/puro
sudo darwin-rebuild switch
which puro  # → puro not found (!)
```

**Key Discovery**:
- Puro installs to `~/.puro`
- The directory persists across rebuilds
- But puro kept "disappearing" after rebuilds
- Confusion: "Does darwin-rebuild wipe user files?"

---

### Phase 6: Investigation & Understanding

```bash
ls -la ~/.puro/bin/puro  # → File exists!
~/.puro/bin/puro --version  # → Works!
which puro  # → puro not found
```

**Root Cause Identified**:
- Puro binary existed and worked
- It just wasn't in PATH
- The puro installer normally modifies shell rc files
- But nix-darwin manages `/etc/zshrc`, not `~/.zshrc`
- PATH configuration was missing

---

### Phase 7: Final Solution (Nix-Darwin Activation Scripts)

**Solution Components**:

1. **Activation Script** in `darwin/profiles/ditto.nix`:
```nix
system.activationScripts.puro.text = ''
  PURO_USER="alyssaevans"
  PURO_HOME="/Users/$PURO_USER"

  if [ ! -f "$PURO_HOME/.puro/bin/puro" ]; then
    echo "Installing puro for $PURO_USER..." >&2
    sudo -u "$PURO_USER" /bin/bash -c 'curl -fsSL https://puro.dev/install.sh | bash'
  else
    echo "Puro already installed at $PURO_HOME/.puro" >&2
  fi
'';
```

2. **PATH Configuration** in same file:
```nix
programs.zsh.interactiveShellInit = ''
  eval "$(/opt/homebrew/bin/brew shellenv)"
  eval "$(direnv hook zsh)"

  # Add puro to PATH
  export PATH="$HOME/.puro/bin:$PATH"
'';
```

**Why This Works**:
- ✅ Installs automatically on first `darwin-rebuild switch`
- ✅ Idempotent: checks before installing
- ✅ Runs as user (not root) via `sudo -u`
- ✅ Persists in `~/.puro` (user home directory)
- ✅ PATH configured in `/etc/zshrc` (managed by nix-darwin)
- ✅ Available in all shell sessions

---

## Lessons Learned

### 1. Not Everything Belongs in Nix
Puro is a **dynamic SDK manager** (like rustup, asdf, nvm). These tools:
- Manage their own ecosystems of versions
- Modify system state dynamically
- Conflict with Nix's immutable package model

### 2. Temporary Solutions Add Friction
The temporary nix-shell approach:
- ❌ Slow (reinstall on every entry)
- ❌ Complex (long shell scripts)
- ❌ Wasteful (download on every use)
- ❌ Cleanup removes benefits

### 3. User Home Directory Persists
`~/.puro` survives `darwin-rebuild switch` because:
- It's in user space, not managed by nix-darwin
- System rebuilds don't touch user files
- Perfect location for dynamic tools like puro

### 4. PATH Management Matters
Having the binary installed isn't enough:
- Must be in PATH for shell to find it
- Nix-darwin manages `/etc/zshrc`
- User `~/.zshrc` may not exist or be loaded
- System-level configuration is the right place

### 5. Activation Scripts Are Powerful
`system.activationScripts` enables:
- Running arbitrary setup on system activation
- Idempotent system configuration
- Bridge between Nix and non-Nix tools
- Automatic recovery if things go missing

---

## Pattern for Other SDK Managers

This pattern applies to other version managers:

| Tool | Can Use Nix? | Recommended Approach |
|------|--------------|---------------------|
| rustup | ❌ | Install globally, exclude from nix, add to PATH |
| puro | ❌ | Activation script + PATH (this doc) |
| nvm | ❌ | Install globally, add to PATH |
| asdf | ❌ | Install globally, add to PATH |
| fvm | ❌ | Install globally (or use puro instead) |
| rbenv | ❌ | Install globally, add to PATH |

**General rule**: If it manages multiple versions of SDKs/runtimes, keep it out of Nix and use activation scripts or document manual installation.

---

## Final Configuration

See:
- [darwin/profiles/ditto.nix](profiles/ditto.nix) - Activation script and PATH setup
- [darwin/DITTO.md](DITTO.md) - User-facing documentation
- [CLAUDE.md](../CLAUDE.md) - Pattern documented for future reference

**Post-installation**:
```bash
darwin-rebuild switch --flake .#ditto
# Start new shell
which puro  # → /Users/alyssaevans/.puro/bin/puro
puro use -g 3.27.4
make build-flutter-android  # Works!
```

---

*Document created: 2026-01-02*
*Last updated: 2026-01-02*
