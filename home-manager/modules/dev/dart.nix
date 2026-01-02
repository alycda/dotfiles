# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Note: swig from homebrew tap, not nix
  ];

  shellHook = ''
    # Create temporary directory for puro
    export PURO_ROOT="$PWD/.nix-tmp-puro"
    mkdir -p "$PURO_ROOT"
    
    # Download and install puro to temp location
    echo "📦 Installing puro temporarily..."
    curl -fsSL https://puro.dev/install.sh | PURO_ROOT="$PURO_ROOT" bash
    
    # Add puro to PATH
    export PATH="$PURO_ROOT/bin:$PATH"
    
    # Set Android environment
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export NDK_VERSION="23.1.7779620"
    export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
    
    # Setup cleanup on exit
    cleanup() {
      echo "🧹 Cleaning up puro installation..."
      rm -rf "$PURO_ROOT"
    }
    trap cleanup EXIT
    
    echo "✅ Environment ready!"
    echo "   SWIG: $(which swig) ($(swig -version | head -2 | tail -1))"
    echo "   Java: $(java -version 2>&1 | head -1)"
    echo "   Puro: $(which puro)"
    echo ""
    echo "Next steps:"
    echo "  1. puro use -g 3.27.4"
    echo "  2. make build-flutter-android"
  '';
}