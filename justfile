# Composes `task` rather than repeating its HUID and collision logic - it reads
# the path that recipe prints on stdout.
#
# Create a task and open it in $EDITOR (helix by default)
task-edit title:
    #!/usr/bin/env bash
    set -euo pipefail
    file="$(just task {{ quote(title) }})"
    exec "${EDITOR:-hx}" "$file"

# Create a task directory named with a UTC HUID and seed its TASK.md.
[working-directory: "tasks"]
task title:
    #!/usr/bin/env bash
    set -euo pipefail
    id="$(date -u +%Y%m%d-%H%M%S)"
    if [ -e "${id}" ]; then
        # HUIDs are only unique at human speed. The documented remedy for a
        # collision is to wait one second and generate a new one.
        sleep 1
        id="$(date -u +%Y%m%d-%H%M%S)"
    fi
    if [ -e "${id}" ]; then
        echo "HUID still colliding on ${id}; use an explicit suffix" >&2
        exit 1
    fi
    mkdir -p "${id}"
    printf '# %s\n\n- STATUS: OPEN\n- TAGS:\n\n# Description\n\n' {{ quote(title) }} > "${id}/TASK.md"
    printf '%s\n' "${id}/TASK.md"

# The HUID is the issue's createdAt rather than "now", so imported tasks sort
# by when the work was first raised. That also makes it deterministic: an
# existing directory carrying the same issue tag means it was imported already.
#
# Locked to alycda/dotfiles: the repo is named explicitly rather than inferred
# from origin, so it works from any clone or remote setup.
#
# Closed issues get a "## Closed" section because issues were not always linked
# to the PR that landed them: it records the closer when GitHub has one, the
# development-panel links, and any other PR that cross-referenced the issue.

# Import GitHub issue N from alycda/dotfiles as a task
import-issue number:
    #!/usr/bin/env bash
    set -euo pipefail
    n={{ quote(number) }}
    case "$n" in ''|*[!0-9]*) echo "issue number must be numeric: $n" >&2; exit 1 ;; esac

    json="$(gh api graphql -F n="$n" -f query='
      query($n: Int!) {
        repository(owner: "alycda", name: "dotfiles") {
          issue(number: $n) {
            number title body url state stateReason createdAt closedAt
            closedByPullRequestsReferences(first: 50, includeClosedPrs: true) {
              nodes { number url mergedAt }
            }
            timelineItems(first: 100, itemTypes: [CLOSED_EVENT, CROSS_REFERENCED_EVENT]) {
              nodes {
                __typename
                ... on ClosedEvent {
                  closer {
                    __typename
                    ... on PullRequest { number url mergedAt }
                    ... on Commit { oid url messageHeadline }
                  }
                }
                ... on CrossReferencedEvent {
                  source { __typename ... on PullRequest { number url mergedAt } }
                }
              }
            }
          }
        }
      }' --jq '.data.repository.issue')"

    id="$(jq -r '.createdAt | fromdateiso8601 | strftime("%Y%m%d-%H%M%S")' <<<"$json")"
    dir="tasks/${id}"
    if [ -e "${dir}" ]; then
        if grep -qx -- "- TAGS: issue-${n}" "${dir}/TASK.md" 2>/dev/null; then
            echo "issue ${n} already imported as ${dir}" >&2
            exit 1
        fi
        # Two issues opened in the same second. The README's remedy is a suffix.
        dir="${dir}-issue-${n}"
    fi

    mkdir -p "${dir}"
    jq -r '
      def ts: sub("T"; " ") | sub("Z$"; " UTC");
      def pr: "PR #\(.number) \(.url) (\(if .mergedAt then "merged \(.mergedAt | ts)" else "not merged" end))";
      (.closedByPullRequestsReferences.nodes | sort_by(.number)) as $linked
      | ([.timelineItems.nodes[] | select(.__typename == "ClosedEvent")] | last | .closer) as $closer
      | ([.timelineItems.nodes[]
          | select(.__typename == "CrossReferencedEvent" and .source.__typename == "PullRequest")
          | .source
          | select(.number as $x | $linked | map(.number) | index($x) | not)]
         | unique_by(.number)) as $refs
      | (.body // "" | gsub("\r"; "") | sub("\\s+$"; "")) as $body
      | [ "# \(.title)",
          "",
          "- STATUS: \(if .state == "CLOSED" then "CLOSED" else "OPEN" end)",
          "- TAGS: issue-\(.number)",
          "",
          "# Description",
          "",
          "see: \(.url)",
          ""
        ]
        + (if .state == "CLOSED" then
            [ "## Closed",
              "",
              "- closed: \(.closedAt | ts) (\(.stateReason // "completed" | ascii_downcase | gsub("_"; " ")))",
              "- closed by: \(
                  if $closer == null then "not recorded on GitHub (closed manually, no closer event)"
                  elif $closer.__typename == "PullRequest" then ($closer | pr)
                  else "commit \($closer.oid[0:12]) \($closer.url) - \($closer.messageHeadline)" end)"
            ]
            + (if ($linked | length) > 0 then ["- linked in the development panel:"] + ($linked | map("  - " + pr)) else [] end)
            + (if ($refs | length) > 0 then ["- referenced by PRs:"] + ($refs | map("  - " + pr)) else [] end)
            + ["", "## Original issue", ""]
          else [] end)
        + (if $body == "" then [] else [$body] end)
      | join("\n")
    ' <<<"$json" > "${dir}/TASK.md"

    # stdout is the path, like `task`, so this composes the same way. The
    # commit message convention goes to stderr as a hint.
    printf '%s\n' "${dir}/TASK.md"
    jq -r '"commit: issue-\(.number)\(if .state == "CLOSED" then " (closed)" else "" end): \(.title)"' <<<"$json" >&2
