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

# ended ID DIR REASON [TRANSCRIPT]: what Claude writes to the hook's stdin.
# The default transcript doesn't exist, so the task is the pointer alone.
ended() {
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"SessionEnd","reason":"%s"}' \
    "$1" "${4:-/t.jsonl}" "$2" "$3"
}

# transcript: a session's JSONL, the shapes Claude Code writes, with the noise
# the recap has to skip: an injected attachment carrying a PR link, harness
# blocks ("<bash-input>"), a meta message, a short last prompt, a torn line.
transcript() {
  t="$BATS_TEST_TMPDIR/session.jsonl"
  cat > "$t" <<'JSONL'
{"type":"attachment","attachment":{"type":"skill_listing","content":"see https://github.com/acme/other/pull/9"},"timestamp":"2026-10-17T04:00:00.000Z"}
{"type":"user","message":{"role":"user","content":"look at https://github.com/acme/repo/pull/211 and tasks/20261003-082724"},"gitBranch":"main","timestamp":"2026-10-17T04:00:05.000Z"}
{"type":"user","isMeta":true,"message":{"role":"user","content":"Base directory for this skill: https://github.com/acme/meta/issues/1"},"timestamp":"2026-10-17T04:01:00.000Z"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Posted https://github.com/acme/repo/pull/211#discussion_r1"},{"type":"tool_use","name":"Write","input":{"file_path":"/r/tasks/20261017-120000/TASK.md"}}]},"gitBranch":"v0.1.8","timestamp":"2026-10-17T04:10:00.000Z"}
{"type":"user","message":{"role":"user","content":"<bash-input>just tasks</bash-input>"},"timestamp":"2026-10-17T04:20:00.000Z"}
{"type":"user","message":{"role":"user","content":"make the pointer more useful,\n with p:1 and me@host"},"gitBranch":"v0.1.8","timestamp":"2026-10-17T04:30:00.000Z"}
{"type":"ai-title","aiTitle":"Stale opening title"}
{"type":"user","message":{"role":"user","content":"post it"},"gitBranch":"v0.1.8","timestamp":"2026-10-17T05:35:00.000Z"}
{"type":"user","message":{"rol
JSONL
  printf '%s' "$t"
}

@test "a session leaves one resume task on the @claude board" {
  run sh "$hook" <<< "$(ended abc-123 /work/repo prompt_input_exit)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fx 'tb --cli --find abc-123' "$log"
  grep -Fx 'tb --cli --task @claude resume: claude --resume abc-123 (in /work/repo, prompt_input_exit)' "$log"
}

@test "a session already on the board is updated in place, not added again" {
  echo '  3. ☐ resume: claude --resume abc-123 (in /work/repo, clear)' > "$BATS_TEST_TMPDIR/found"
  run sh "$hook" <<< "$(ended abc-123 /work/repo other)"
  [ "$status" -eq 0 ]
  run ! grep -q -- '--task' "$log"
  grep -Fx 'tb --cli --edit @3 resume: claude --resume abc-123 (in /work/repo, other)' "$log"
}

@test "the transcript gives the task a recap ahead of the pointer" {
  run sh "$hook" <<< "$(ended abc-123 /work/repo other "$(transcript)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fx 'tb --cli --task @claude make the pointer more useful, with p_1 and me_host · on v0.1.8 · repo#211 · task 20261003-082724, 20261017-120000 · 3 prompts, 1h35m · resume: claude --resume abc-123 (in /work/repo, other)' "$log"
}

@test "the recap skips injected context, harness blocks and meta messages" {
  run sh "$hook" <<< "$(ended abc-123 /work/repo other "$(transcript)")"
  run ! grep -E 'other#9|meta#1|bash-input|Stale opening title' "$log"
}

@test "a /rename title heads the recap" {
  t=$(transcript)
  printf '%s\n' '{"type":"custom-title","customTitle":"Session recap hook"}' >> "$t"
  run sh "$hook" <<< "$(ended abc-123 /work/repo other "$t")"
  grep -F -- '--task @claude Session recap hook · on v0.1.8' "$log"
}

@test "a /recap heads it when there is no title" {
  t=$(transcript)
  printf '%s\n' '{"type":"system","subtype":"away_summary","content":"Drafted the hook recap\nmore detail"}' >> "$t"
  run sh "$hook" <<< "$(ended abc-123 /work/repo other "$t")"
  grep -F -- '--task @claude Drafted the hook recap · on v0.1.8' "$log"
  run ! grep -F 'more detail' "$log"
}

@test "a long prompt is clipped to 80 characters" {
  t="$BATS_TEST_TMPDIR/long.jsonl"
  printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$(printf 'word %.0s' $(seq 40))" > "$t"
  run sh "$hook" <<< "$(ended abc-123 /work/repo other "$t")"
  headline=$(sed -n 's/^tb --cli --task @claude \(.*\) · 1 prompts.*/\1/p' "$log")
  [ "${#headline}" -eq 80 ]
  [[ $headline == *… ]]
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

@test "off PATH, tb is found in the home-manager profile" {
  mkdir -p "$HOME/.nix-profile/bin"
  mv "$stubs/tb" "$HOME/.nix-profile/bin/tb"
  PATH="$stubs:/usr/bin:/bin" run sh "$hook" <<< "$(ended abc-123 /work/repo other)"
  [ "$status" -eq 0 ]
  grep -Fx 'tb --cli --task @claude resume: claude --resume abc-123 (in /work/repo, other)' "$log"
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
