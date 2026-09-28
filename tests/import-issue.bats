#!/usr/bin/env bats
# `just import-issue` and tasks/scripts/import-issue against tasks/README.md.
# Each test runs a copy of the justfile and tasks/scripts in a temp dir, so
# the repo's own tasks/ is never touched. gh is stubbed to answer with a
# fixture issue, as if its --jq had already picked out .data.repository.issue;
# the last test asks the real GitHub, when a token is available.

bats_require_minimum_version 1.5.0

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  work="$BATS_TEST_TMPDIR/work"
  stubs="$BATS_TEST_TMPDIR/bin"
  log="$BATS_TEST_TMPDIR/log"
  mkdir -p "$work/tasks" "$stubs"
  : > "$log"
  cp "$repo/justfile" "$work/"
  cp -R "$repo/tasks/scripts" "$work/tasks/"
  cd "$work" || return

  # gh logs its arguments and prints the fixture, or fails without one.
  cat > "$stubs/gh" <<STUB
#!/bin/sh
echo "gh \$*" >> "$log"
cat "$BATS_TEST_TMPDIR/issue.json"
STUB
  chmod +x "$stubs/gh"
  PATH="$stubs:$PATH"
}

# issue: the fixture gh answers with, read from stdin.
issue() { cat > "$BATS_TEST_TMPDIR/issue.json"; }

url=https://github.com/alycda/dotfiles

open_issue() {
  issue <<JSON
{
  "number": 183, "title": "Install jj-stash", "url": "$url/issues/183",
  "body": "Park commit chains.\r\n\r\n- restore them unchanged\r\n\r\n",
  "state": "OPEN", "stateReason": null,
  "createdAt": "2026-09-26T02:05:41Z", "closedAt": null,
  "closedByPullRequestsReferences": { "nodes": [] },
  "timelineItems": { "nodes": [] }
}
JSON
}

@test "an open issue becomes tasks/<createdAt>/TASK.md, and the path is printed" {
  open_issue
  run --separate-stderr tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  [ "$output" = "tasks/20260926-020541/TASK.md" ]
  [ "$stderr" = "commit: issue-183: Install jj-stash" ]
  cat > "$BATS_TEST_TMPDIR/want" <<EOF
# Install jj-stash

- STATUS: OPEN
- TAGS: issue-183

## Description

see: $url/issues/183

Park commit chains.

- restore them unchanged
EOF
  diff "$BATS_TEST_TMPDIR/want" tasks/20260926-020541/TASK.md
}

@test "gh is asked for that issue with the query next to the script" {
  open_issue
  run tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = "gh api graphql -F n=183 -F query=@$work/tasks/scripts/import-issue.graphql --jq .data.repository.issue" ]
}

@test "the HUID is createdAt in UTC, whatever the local timezone" {
  open_issue
  TZ=America/Los_Angeles run tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  [ -f tasks/20260926-020541/TASK.md ]
}

@test "an issue with no body ends at its link" {
  issue <<JSON
{
  "number": 7, "title": "Terse", "url": "$url/issues/7", "body": null,
  "state": "OPEN", "stateReason": null,
  "createdAt": "2026-01-01T00:00:00Z", "closedAt": null,
  "closedByPullRequestsReferences": { "nodes": [] },
  "timelineItems": { "nodes": [] }
}
JSON
  run tasks/scripts/import-issue 7
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 tasks/20260101-000000/TASK.md)" = "see: $url/issues/7" ]
}

@test "a closed issue records its closer, linked PRs and other referencing PRs" {
  # The last ClosedEvent wins (issue reopened, then closed again). Linked PRs
  # sort by number. References skip linked PRs, non-PRs and duplicates.
  issue <<JSON
{
  "number": 42, "title": "Closed thing", "url": "$url/issues/42",
  "body": "Body line\r\nsecond\r\n\n  ",
  "state": "CLOSED", "stateReason": "NOT_PLANNED",
  "createdAt": "2026-01-02T03:04:05Z", "closedAt": "2026-02-03T04:05:06Z",
  "closedByPullRequestsReferences": { "nodes": [
    { "number": 12, "url": "$url/pull/12", "mergedAt": "2026-02-03T04:05:00Z" },
    { "number": 10, "url": "$url/pull/10", "mergedAt": null }
  ] },
  "timelineItems": { "nodes": [
    { "__typename": "CrossReferencedEvent", "source": { "__typename": "PullRequest", "number": 11, "url": "$url/pull/11", "mergedAt": null } },
    { "__typename": "CrossReferencedEvent", "source": { "__typename": "PullRequest", "number": 12, "url": "$url/pull/12", "mergedAt": "2026-02-03T04:05:00Z" } },
    { "__typename": "CrossReferencedEvent", "source": { "__typename": "Issue" } },
    { "__typename": "ClosedEvent", "closer": { "__typename": "Commit", "oid": "0123456789abcdef0123", "url": "$url/commit/0123456789abcdef0123", "messageHeadline": "first close" } },
    { "__typename": "CrossReferencedEvent", "source": { "__typename": "PullRequest", "number": 11, "url": "$url/pull/11", "mergedAt": null } },
    { "__typename": "ClosedEvent", "closer": { "__typename": "PullRequest", "number": 12, "url": "$url/pull/12", "mergedAt": "2026-02-03T04:05:00Z" } }
  ] }
}
JSON
  run --separate-stderr tasks/scripts/import-issue 42
  [ "$status" -eq 0 ]
  [ "$stderr" = "commit: issue-42 (closed): Closed thing" ]
  cat > "$BATS_TEST_TMPDIR/want" <<EOF
# Closed thing

- STATUS: CLOSED
- TAGS: issue-42

## Description

see: $url/issues/42

## Closed

- closed: 2026-02-03 04:05:06 UTC (not planned)
- closed by: PR #12 $url/pull/12 (merged 2026-02-03 04:05:00 UTC)
- linked in the development panel:
  - PR #10 $url/pull/10 (not merged)
  - PR #12 $url/pull/12 (merged 2026-02-03 04:05:00 UTC)
- referenced by PRs:
  - PR #11 $url/pull/11 (not merged)

## Original issue

Body line
second
EOF
  diff "$BATS_TEST_TMPDIR/want" tasks/20260102-030405/TASK.md
}

@test "a closed issue says so when a commit, or nothing, closed it" {
  issue <<JSON
{
  "number": 5, "title": "By commit", "url": "$url/issues/5", "body": "",
  "state": "CLOSED", "stateReason": null,
  "createdAt": "2026-01-01T00:00:05Z", "closedAt": "2026-01-02T00:00:00Z",
  "closedByPullRequestsReferences": { "nodes": [] },
  "timelineItems": { "nodes": [
    { "__typename": "ClosedEvent", "closer": { "__typename": "Commit", "oid": "0123456789abcdef0123", "url": "$url/commit/0123456789abcdef0123", "messageHeadline": "fix it" } }
  ] }
}
JSON
  run tasks/scripts/import-issue 5
  [ "$status" -eq 0 ]
  grep -qxF -- "- closed: 2026-01-02 00:00:00 UTC (completed)" tasks/20260101-000005/TASK.md
  grep -qxF -- "- closed by: commit 0123456789ab $url/commit/0123456789abcdef0123 - fix it" tasks/20260101-000005/TASK.md
  run ! grep -q 'development panel\|referenced by' tasks/20260101-000005/TASK.md

  jq '.number = 6 | .createdAt = "2026-01-01T00:00:06Z" | .timelineItems.nodes = []' \
    "$BATS_TEST_TMPDIR/issue.json" > "$BATS_TEST_TMPDIR/next" && mv "$BATS_TEST_TMPDIR/next" "$BATS_TEST_TMPDIR/issue.json"
  run tasks/scripts/import-issue 6
  [ "$status" -eq 0 ]
  grep -qxF -- "- closed by: not recorded on GitHub (closed manually, no closer event)" tasks/20260101-000006/TASK.md
}

@test "an issue number that isn't numeric fails before asking GitHub" {
  for n in "" 12a -1 "1 2"; do
    run tasks/scripts/import-issue "$n"
    [ "$status" -eq 1 ]
    [ "$output" = "issue number must be numeric: $n" ]
  done
  [ ! -s "$log" ]
}

@test "importing the same issue twice fails, leaving the first" {
  open_issue
  run tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  cp tasks/20260926-020541/TASK.md "$BATS_TEST_TMPDIR/first"
  run tasks/scripts/import-issue 183
  [ "$status" -eq 1 ]
  [ "$output" = "issue 183 already imported as tasks/20260926-020541" ]
  [ "$(ls tasks)" = "$(printf '20260926-020541\nscripts')" ]
  diff "$BATS_TEST_TMPDIR/first" tasks/20260926-020541/TASK.md
}

@test "a different task in the same second gets an -issue-N suffix" {
  open_issue
  mkdir tasks/20260926-020541
  printf '# Someone else\n\n- STATUS: OPEN\n- TAGS:\n' > tasks/20260926-020541/TASK.md
  run --separate-stderr tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  [ "$output" = "tasks/20260926-020541-issue-183/TASK.md" ]
  grep -qx -- "- TAGS: issue-183" tasks/20260926-020541-issue-183/TASK.md
  [ "$(head -n 1 tasks/20260926-020541/TASK.md)" = "# Someone else" ]
}

@test "a failed gh call creates nothing" {
  printf '#!/bin/sh\necho "gh: HTTP 502" >&2\nexit 1\n' > "$stubs/gh"
  run tasks/scripts/import-issue 183
  [ "$status" -ne 0 ]
  [ "$(ls tasks)" = "scripts" ]
}

@test "just import-issue passes its argument through as one word" {
  open_issue
  run --separate-stderr just import-issue 183
  [ "$status" -eq 0 ]
  [ "$output" = "tasks/20260926-020541/TASK.md" ]
  run just import-issue "1 2"
  [ "$status" -ne 0 ]
  [[ $output == *"issue number must be numeric: 1 2"* ]]
}

@test "the query works against GitHub (needs GH_TOKEN)" {
  [ -n "${GH_TOKEN:-}" ] || skip "GH_TOKEN is not set"
  PATH="${PATH#"$stubs:"}"
  # #183 is open and its createdAt never changes, so its HUID is fixed.
  run --separate-stderr tasks/scripts/import-issue 183
  [ "$status" -eq 0 ]
  [ "$output" = "tasks/20260926-020541/TASK.md" ]
  head -n 1 tasks/20260926-020541/TASK.md | grep -q '^# .'
  grep -qx -- "- TAGS: issue-183" tasks/20260926-020541/TASK.md
  grep -qxF -- "see: $url/issues/183" tasks/20260926-020541/TASK.md
}
