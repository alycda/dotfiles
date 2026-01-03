#!/usr/bin/env bash
# Xcode installation (requires Apple ID - cannot automate)
set -euo pipefail

XCODE_VERSION="${XCODE_VERSION:-16.2}"

echo "==> Installing Xcode ${XCODE_VERSION}..."
echo "⚠️  This requires Apple ID authentication"

if xcodes installed | grep -q "${XCODE_VERSION}"; then
    echo "✓ Already installed"
else
    xcodes install "${XCODE_VERSION}"
fi

# Post-install automation
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
xcodebuild -downloadPlatform iOS

echo "✓ Xcode ready!"