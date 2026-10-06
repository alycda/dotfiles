#!/usr/bin/env bats
# The HUID task recipes (`just task`, `just task-edit`) against the spec in
# tasks/README.md. Each test runs a copy of the repo's justfile from a temp
# dir, so the repo's own tasks/ is never touched. date, sleep and $EDITOR are
# stubbed where a test needs to control them.

HUID='^[0-9]{8}-[0-9]{6}$'

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  work="$BATS_TEST_TMPDIR/work"
  stubs="$BATS_TEST_TMPDIR/bin"
  log="$BATS_TEST_TMPDIR/log"
  mkdir -p "$work/tasks" "$stubs"
  : > "$log"
  cp "$repo/justfile" "$work/justfile"
  cd "$work" || return
}

# stub_date HUID...: `date` prints each HUID in turn, repeating the last, and
# logs its arguments. sleep is stubbed too, so a retry costs no time.
stub_date() {
  printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/dates"
  cat > "$stubs/date" <<STUB
#!/bin/sh
echo "date \$*" >> "$log"
q="$BATS_TEST_TMPDIR/dates"
head -n 1 "\$q"
if [ "\$(wc -l < "\$q")" -gt 1 ]; then tail -n +2 "\$q" > "\$q.next" && mv "\$q.next" "\$q"; fi
STUB
  printf '#!/bin/sh\necho "sleep $*" >> "%s"\n' "$log" > "$stubs/sleep"
  chmod +x "$stubs/date" "$stubs/sleep"
}

@test "task creates tasks/<HUID>/TASK.md and prints its path" {
  run just task "Write tests"
  [ "$status" -eq 0 ]
  dirs=(tasks/*/)
  [ "${#dirs[@]}" -eq 1 ]
  id="$(basename "${dirs[0]}")"
  [[ $id =~ $HUID ]]
  [ -f "tasks/$id/TASK.md" ]
  # The path is for other commands to use, so it has to resolve from the
  # justfile's directory, not from inside tasks/.
  [ "$output" = "tasks/$id/TASK.md" ]
}

@test "the HUID is the current time in UTC" {
  stub_date 20260101-120000
  PATH="$stubs:$PATH" run just task "UTC"
  [ "$status" -eq 0 ]
  [ -d tasks/20260101-120000 ]
  grep -qx 'date -u +%Y%m%d-%H%M%S' "$log"
}

@test "TASK.md follows the template in tasks/README.md" {
  run just task "Write tests"
  [ "$status" -eq 0 ]
  printf '# Write tests\n\n- STATUS: OPEN\n- TAGS:\n\n## Description\n\n' > "$BATS_TEST_TMPDIR/want"
  diff "$BATS_TEST_TMPDIR/want" tasks/*/TASK.md
}

@test "the title is written literally" {
  # shellcheck disable=SC2016 # the title is meant literally: nothing expands
  title='Fix "quotes", $HOME, `ticks` and \backslashes'
  run just task "$title"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 tasks/*/TASK.md)" = "# $title" ]
}

@test "a taken HUID is retried once, after a second" {
  stub_date 20260101-120000 20260101-120001
  mkdir tasks/20260101-120000
  PATH="$stubs:$PATH" run just task "Retry"
  [ "$status" -eq 0 ]
  [ -f tasks/20260101-120001/TASK.md ]
  [ "$(grep -c '^sleep 1$' "$log")" -eq 1 ]
}

@test "a HUID still taken after the retry fails, creating nothing" {
  stub_date 20260101-120000
  mkdir tasks/20260101-120000
  PATH="$stubs:$PATH" run just task "Collide"
  [ "$status" -ne 0 ]
  [[ $output == *"HUID still colliding on 20260101-120000"* ]]
  [ "$(ls tasks)" = "20260101-120000" ]
  [ ! -e tasks/20260101-120000/TASK.md ]
}

@test "task-edit opens the task it created" {
  # shellcheck disable=SC2016 # the stub's own "$1", written out verbatim
  printf '#!/bin/sh\nif [ -f "$1" ]; then echo "opened $1"; else echo "missing $1"; fi >> "%s"\n' "$log" > "$stubs/editor"
  chmod +x "$stubs/editor"
  EDITOR="$stubs/editor" run just task-edit "Edit me"
  [ "$status" -eq 0 ]
  grep -q '^opened ' "$log"
}

@test "every task in the repo follows the spec" {
  shopt -s nullglob
  for dir in "$repo"/tasks/*/; do
    id="$(basename "$dir")"
    # The README's one exception: tooling, not a task.
    [ "$id" = scripts ] && continue
    [[ $id =~ ^[0-9]{8}-[0-9]{6}(-[a-zA-Z0-9-]*)?$ ]] || { echo "not a HUID: $id"; return 1; }
    [ -f "$dir/TASK.md" ] || { echo "no TASK.md: $id"; return 1; }
    head -n 1 "$dir/TASK.md" | grep -q '^# ' || { echo "no title: $id"; return 1; }
    grep -qE '^- STATUS: (OPEN|CLOSED)$' "$dir/TASK.md" || { echo "bad STATUS: $id"; return 1; }
  done
}
