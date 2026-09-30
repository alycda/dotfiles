#!/usr/bin/env bats
# The Claude Code SessionEnd hook (tools/claude/hooks/session-end-taskbook.sh)
# and the installer that registers it (tools/claude/install-hooks). tb is
# stubbed: it logs its arguments and answers --find from a file, so no
# taskbook is touched. HOME is a temp dir, so no settings.json is either.

bats_require_minimum_version 1.5.0

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  hook="$repo/tools/claude/hooks/session-end-taskbook.sh"
  install="$repo/tools/claude/install-hooks"
  stubs="$BATS_TEST_TMPDIR/bin"
  log="$BATS_TEST_TMPDIR/log"
  mkdir -p "$stubs"
  : > "$log"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude"
  settings="$HOME/.claude/settings.json"
  unset TASKBOOK_DIR

  # tb logs its arguments; --find prints the fixture, if a test wrote one.
  cat > "$stubs/tb" <<STUB
#!/bin/sh
echo "tb \$*" >> "$log"
case " \$* " in *" --find "*) cat "$BATS_TEST_TMPDIR/found" 2>/dev/null ;; esac
STUB
  chmod +x "$stubs/tb"
  PATH="$stubs:$PATH"
}

# ended ID DIR REASON: what Claude writes to the hook's stdin.
ended() {
  printf '{"session_id":"%s","transcript_path":"/t.jsonl","cwd":"%s","hook_event_name":"SessionEnd","reason":"%s"}' "$@"
}

@test "a session leaves one resume task on the @claude board" {
  run sh "$hook" <<< "$(ended abc-123 /work/repo prompt_input_exit)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fx 'tb --cli --find abc-123' "$log"
  grep -Fx 'tb --cli --task @claude resume: claude --resume abc-123 (in /work/repo, prompt_input_exit)' "$log"
}

@test "a session already on the board is not added again" {
  echo '  1. ☐ resume: claude --resume abc-123 (in /work/repo, clear)' > "$BATS_TEST_TMPDIR/found"
  run sh "$hook" <<< "$(ended abc-123 /work/repo other)"
  [ "$status" -eq 0 ]
  run ! grep -q -- '--task' "$log"
}

@test "an @ in the directory can't turn into a board" {
  run sh "$hook" <<< "$(ended abc-123 /work/me@host other)"
  [ "$status" -eq 0 ]
  grep -F 'in /work/me_host' "$log"
  [ "$(grep -c '@' "$log")" -eq 1 ]
}

@test "TASKBOOK_DIR reaches tb" {
  TASKBOOK_DIR=/data run sh "$hook" <<< "$(ended abc-123 /work/repo other)"
  [ "$status" -eq 0 ]
  grep -Fx 'tb --cli --taskbook-dir /data --task @claude resume: claude --resume abc-123 (in /work/repo, other)' "$log"
}

@test "without tb it exits 0 and says nothing" {
  rm "$stubs/tb"
  PATH="$stubs:/usr/bin:/bin" run sh "$hook" <<< "$(ended abc-123 /work/repo other)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty input exits 0 and calls nothing" {
  run sh "$hook" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$log" ]
}

@test "install-hooks adds SessionEnd and keeps what Claude wrote" {
  printf '{"theme":"dark","model":"opus"}\n' > "$settings"
  run "$install"
  [ "$status" -eq 0 ]
  [ "$(jq -r .theme "$settings")" = dark ]
  [ "$(jq -r .model "$settings")" = opus ]
  [ "$(jq '.hooks.SessionEnd | length' "$settings")" -eq 1 ]
  jq -e '.hooks.SessionEnd[0].hooks[0].command | contains("session-end-taskbook.sh")' "$settings"
}

@test "install-hooks again adds nothing, and a hook of your own stays" {
  printf '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"echo bye"}]}]}}\n' > "$settings"
  "$install"
  run "$install"
  [ "$status" -eq 0 ]
  [[ $output == *"already"* ]]
  [ "$(jq '.hooks.SessionEnd | length' "$settings")" -eq 2 ]
  [ "$(jq -r '.hooks.SessionEnd[0].hooks[0].command' "$settings")" = "echo bye" ]
}

@test "install-hooks creates the file, at the path it is given" {
  rmdir "$HOME/.claude"
  run "$install" "$HOME/elsewhere/settings.json"
  [ "$status" -eq 0 ]
  jq -e '.hooks.SessionEnd | length == 1' "$HOME/elsewhere/settings.json"
}
