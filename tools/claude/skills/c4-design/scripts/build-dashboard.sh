#!/usr/bin/env bash
#
# Build the Likec4 dashboard from docs/c4/model.c4.
#
# Usage:
#   build-dashboard.sh [PROJECT_ROOT]
#
# Defaults PROJECT_ROOT to the current working directory.
# Validates the DSL first; aborts if validation fails.
# Outputs the static dashboard to docs/c4/dashboard/.

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

cd "$PROJECT_ROOT"

C4_DIR="docs/c4"
MODEL="${C4_DIR}/model.c4"
OUTPUT="${C4_DIR}/dashboard"

if [[ ! -f "$MODEL" ]]; then
  echo "No model at ${MODEL}. Run Step 1 (draft DSL) first." >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found on PATH. Install Node 18+: https://nodejs.org" >&2
  exit 2
fi

echo "==> Validating ${MODEL}"
if ! npx --yes @likec4/cli validate "$MODEL"; then
  echo "Validation failed. Fix the DSL errors above and rerun." >&2
  exit 1
fi

mkdir -p "$OUTPUT"

echo "==> Building dashboard to ${OUTPUT}"
npx --yes @likec4/cli build --src "$C4_DIR" --output "$OUTPUT"

INDEX="${OUTPUT}/index.html"
if [[ ! -f "$INDEX" ]]; then
  echo "Build completed but no ${INDEX} was produced. Likec4 CLI flags may have changed; see https://likec4.dev/docs/cli for current options." >&2
  exit 1
fi

echo ""
echo "Dashboard ready: ${INDEX}"
echo ""
echo "Open with:"
echo "  open ${INDEX}                                    # macOS"
echo "  python3 -m http.server -d ${OUTPUT} 8000         # any OS — then visit http://localhost:8000"
