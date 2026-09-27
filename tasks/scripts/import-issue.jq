# Renders the issue JSON from import-issue.graphql as a TASK.md.
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
    "## Description",
    "",
    "see: \(.url)"
  ]
  + (if .state == "CLOSED" then
      [ "",
        "## Closed",
        "",
        "- closed: \(.closedAt | ts) (\(.stateReason // "completed" | ascii_downcase | gsub("_"; " ")))",
        "- closed by: \(
            if $closer == null then "not recorded on GitHub (closed manually, no closer event)"
            elif $closer.__typename == "PullRequest" then ($closer | pr)
            else "commit \($closer.oid[0:12]) \($closer.url) - \($closer.messageHeadline)" end)"
      ]
      + (if ($linked | length) > 0 then ["- linked in the development panel:"] + ($linked | map("  - " + pr)) else [] end)
      + (if ($refs | length) > 0 then ["- referenced by PRs:"] + ($refs | map("  - " + pr)) else [] end)
    else [] end)
  + (if $body == "" then []
     elif .state == "CLOSED" then ["", "## Original issue", "", $body]
     else ["", $body] end)
| join("\n")
