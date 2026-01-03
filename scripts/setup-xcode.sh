#!/usr/bin/env bash
# Xcode setup automation
# Called manually after darwin-rebuild

set -euo pipefail

XCODE_VERSION="${XCODE_VERSION:-16.2}"

echo "==> Installing Xcode ${XCODE_VERSION}..."

# Check if already installed
if xcodes installed | grep -q "${XCODE_VERSION}"; then
    echo "✓ Already installed"
else
    # Prompts for Apple ID (one-time, saves to keychain)
    xcodes install "${XCODE_VERSION}"
fi

# Select and configure
sudo xcodes select "${XCODE_VERSION}"
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
xcodebuild -downloadPlatform iOS

echo "✓ Xcode setup complete!"