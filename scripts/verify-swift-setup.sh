#!/usr/bin/env bash
set -euo pipefail

echo "==> Ditto Swift Development Environment Verification"
echo ""

# Homebrew packages
echo "1. Checking Homebrew packages..."
command -v xcodes >/dev/null && echo "  ✓ xcodes" || echo "  ✗ xcodes MISSING"
command -v rbenv >/dev/null && echo "  ✓ rbenv" || echo "  ✗ rbenv MISSING"
command -v sourcekitten >/dev/null && echo "  ✓ sourcekitten" || echo "  ✗ sourcekitten MISSING"

# Xcode
echo ""
echo "2. Checking Xcode..."
if xcodebuild -version &>/dev/null; then
    echo "  ✓ Xcode: $(xcodebuild -version | head -1)"
    echo "  ✓ Path: $(xcode-select -p)"
else
    echo "  ✗ Xcode NOT INSTALLED - run: ./scripts/setup-xcode.sh"
fi

# Ruby
echo ""
echo "3. Checking Ruby environment..."
if rbenv versions &>/dev/null; then
    echo "  ✓ rbenv active"
    eval "$(rbenv init - zsh)"
    echo "  ✓ Ruby: $(rbenv version)"
    
    if rbenv exec gem list | grep -q cocoapods; then
        echo "  ✓ cocoapods gem"
    else
        echo "  ⚠ cocoapods gem MISSING (should auto-install on rebuild)"
    fi
fi

# Ditto monorepo
echo ""
echo "4. Checking Ditto monorepo..."
if [ -d "$HOME/code/ditto" ]; then
    echo "  ✓ Cloned at ~/code/ditto"
    cd ~/code/ditto
    echo "  ✓ Branch: $(git branch --show-current)"
    
    if [ -f "target/aarch64-apple-ios-sim/debug/libdittoffi.a" ]; then
        echo "  ✓ FFI built"
    else
        echo "  ⚠ FFI not built - run: make build-ios-simulator"
    fi
else
    echo "  ✗ Not cloned - run: gh repo clone getditto/ditto ~/code/ditto"
fi

echo ""
echo "==> Verification complete!"
echo ""
echo "Next steps if needed:"
echo "  - Install Xcode: ./scripts/setup-xcode.sh"
echo "  - Clone Ditto: gh repo clone getditto/ditto ~/code/ditto"
echo "  - Build FFI: cd ~/code/ditto && make build-ios-simulator"
echo "  - Build Swift: cd ~/code/ditto && make build-swift"