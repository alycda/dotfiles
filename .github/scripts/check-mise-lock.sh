#!/usr/bin/env bash
# Validate tools/mise/mise.lock against tools/mise/config.toml.
#
# The mise account installs from the lockfile, so the thing worth checking is
# that the lockfile can actually serve every tool the config declares, for the
# platform that account runs on. Two ways it can fail to:
#
#   - a tool in [tools] that the lockfile has no entry for at all (added to
#     config.toml by `mise use -g` without a re-lock)
#   - an entry with no checksum for the target platform, which is what a
#     lockfile written on some *other* platform looks like. `mise install`
#     falls back to resolving that tool live, silently dropping the pin.
#
# `mise lock --dry-run` is no help here: it reports "would update" for every
# entry whether or not anything changed, so it can neither detect drift nor
# confirm a no-op.
#
# Usage: check-mise-lock.sh [platform]   (default: macos-arm64)
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config="$repo/tools/mise/config.toml"
lock="$repo/tools/mise/mise.lock"
platform="${1:-macos-arm64}"

[ -f "$config" ] || { echo "::error::missing $config"; exit 1; }
[ -f "$lock" ] || { echo "::error::missing $lock — run 'just mise-lock' to create it"; exit 1; }

# Tool names from the [tools] table, up to the next table header.
tools=$(awk '
  /^\[tools\]/ { in_tools = 1; next }
  /^\[/        { in_tools = 0 }
  in_tools && /^[A-Za-z0-9_-]+[[:space:]]*=/ { sub(/[[:space:]]*=.*/, ""); print }
' "$config")
[ -n "$tools" ] || { echo "::error::no [tools] entries found in $config"; exit 1; }

status=0
for tool in $tools; do
  # mise writes one [[tools.<name>]] array entry per tool, followed by a
  # [tools.<name>."platforms.<platform>"] table per locked platform.
  read -r version checksum <<<"$(awk -v tool="$tool" -v plat="$platform" '
    $0 == "[[tools." tool "]]"                      { section = "tool"; next }
    $0 == "[tools." tool ".\"platforms." plat "\"]" { section = "platform"; next }
    /^\[/                                           { section = "" }
    section == "tool"     && /^version[[:space:]]*=/  { split($0, f, "\""); version = f[2] }
    section == "platform" && /^checksum[[:space:]]*=/ { checksum = "present" }
    END { printf "%s %s\n", (version == "" ? "-" : version), (checksum == "" ? "-" : checksum) }
  ' "$lock")"

  if [ "$version" = "-" ]; then
    echo "::error::$tool is in config.toml but not in mise.lock"
    status=1
  elif [ "$checksum" = "-" ]; then
    echo "::error::$tool $version has no $platform checksum in mise.lock"
    status=1
  else
    echo "  $tool $version"
  fi
done

if [ "$status" -eq 0 ]; then
  echo "mise.lock serves all $(echo "$tools" | wc -w | tr -d ' ') tools for $platform."
fi
exit "$status"
