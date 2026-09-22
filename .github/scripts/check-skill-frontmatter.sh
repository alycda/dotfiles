#!/usr/bin/env bash
# Validate agent-skill frontmatter against the loader rules Crush enforces
# (charmbracelet/crush internal/skills/skills.go, Validate). Crush skips a
# skill that fails them with no visible error - cf-now and entity-level-git
# were skipped for descriptions of 1043 and 1146 bytes.
#
# Checked per tools/agents/skills/*/SKILL.md:
#   - frontmatter opens on line 1 and parses as YAML
#   - name is present and matches the skill's directory
#   - description is present and at most 1024 BYTES. Crush uses Go's len(),
#     which counts bytes, so an em-dash costs 3. The count includes the
#     trailing newline a `>` block scalar keeps, exactly as Go sees it.
#
# Needs mikefarah's yq (nixpkgs#yq-go) on PATH, not the Python yq wrapper.
# yq-go parses with go.yaml.in/yaml/v4, the successor to the yaml.v3 Crush
# uses; close enough to catch a parse failure, but not the same library.
set -euo pipefail

readonly max_description_bytes=1024
skills_dir="${1:-tools/agents/skills}"
status=0

fail() {
  echo "FAIL $1: $2" >&2
  status=1
}

for skill_md in "$skills_dir"/*/SKILL.md; do
  dir_name="$(basename "$(dirname "$skill_md")")"

  if [ "$(head -n1 "$skill_md")" != "---" ]; then
    fail "$skill_md" "frontmatter must start with '---' on line 1"
    continue
  fi
  frontmatter="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$skill_md")"

  if ! name="$(yq -r '.name // ""' <<<"$frontmatter" 2>&1)"; then
    fail "$skill_md" "frontmatter is not valid YAML: $name"
    continue
  fi
  if [ -z "$name" ]; then
    fail "$skill_md" "name is required"
  elif [ "$name" != "$dir_name" ]; then
    fail "$skill_md" "name '$name' must match directory '$dir_name'"
  fi

  # base64 round-trip: command substitution would strip the trailing newline
  # that Go's len() counts.
  bytes="$(yq -r '.description // "" | @base64' <<<"$frontmatter" | base64 -d | wc -c)"
  if [ "$bytes" -eq 0 ]; then
    fail "$skill_md" "description is required"
  elif [ "$bytes" -gt "$max_description_bytes" ]; then
    fail "$skill_md" "description is $bytes bytes (max $max_description_bytes)"
  else
    echo "ok   $skill_md ($bytes bytes)"
  fi
done

exit "$status"
