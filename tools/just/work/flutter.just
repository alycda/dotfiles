
# ---------------------------------------------------------------------------
# Flutter sanity-check helpers — sample any Dart-only SDK fix against a stock
# published ditto_live without rebuilding native FFI artifacts. Pattern used
# for TICKET-1888 spinner-canary validation (PR #22347).
#
# Workflow:
#   1. just -g pub-patch ditto_live 5.0.0-rc.1 /tmp/ditto_live_patched
#   2. Edit files inside /tmp/ditto_live_patched (cherry-pick the Dart fix)
#   3. Add to the consuming app's pubspec.yaml:
#        dependency_overrides:
#          ditto_live:
#            path: /tmp/ditto_live_patched
#   4. just -g flutter-record-sim <flutter-app-dir> <sim-id> /tmp/after.mp4 &
#   5. Tap the FAB / exercise the UI, then kill the recordVideo PID printed.
# ---------------------------------------------------------------------------

pub_cache := home_directory() / ".puro" / "shared" / "pub_cache" / "hosted" / "pub.dev"

# Copy a published pub.dev package to a writable directory for in-place patching.
# Use to sanity-check a Dart-only SDK fix against the stock native artifacts that
# already ship with that version, avoiding a full FFI rebuild. Skips the copy if
# <dst> already exists so re-runs are idempotent.
pub-patch package version dst:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{pub_cache}}/{{package}}-{{version}}"
    if [ ! -d "$src" ]; then
        echo "error: $src not found. Run 'flutter pub get' in a project that depends on {{package}}: {{version}} first." >&2
        exit 1
    fi
    if [ -e "{{dst}}" ]; then
        echo "{{dst}} already exists — refusing to overwrite. Delete it first if you want a fresh copy." >&2
        exit 1
    fi
    mkdir -p "$(dirname "{{dst}}")"
    cp -R "$src" "{{dst}}"
    chmod -R u+w "{{dst}}"
    echo "✓ {{package}}@{{version}} → {{dst}} (writable, patch in place)"

# Run a Flutter app on a booted iOS Simulator and start a screen recording in
# parallel. The recording writes to <out>; kill the printed PID to stop it.
# Useful for capturing UI-behavior evidence (e.g. main-thread blocking).
flutter-record-sim dir sim out:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! xcrun simctl list devices booted | grep -q "{{sim}}"; then
        echo "error: simulator {{sim}} is not booted. Boot one with: xcrun simctl boot {{sim}} && open -a Simulator" >&2
        exit 1
    fi
    rm -f "{{out}}"
    xcrun simctl io "{{sim}}" recordVideo --codec h264 "{{out}}" &
    rec_pid=$!
    echo "recordVideo PID: $rec_pid (writing to {{out}})"
    echo "Stop with: kill $rec_pid"
    cd "{{dir}}" && flutter run -d "{{sim}}" --debug