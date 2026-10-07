#!/usr/bin/env bats
# tools/secrets/edit-secret, with the real rage and ragenix, in a copy of the
# repo's layout whose secrets/recipients.txt holds a throwaway key, so the
# repo's secrets and ~/.age are never touched. EDITOR stands in for the
# person: `true` changes nothing, and a script writes a new secret.
#
# Needs rage, rage-keygen and ragenix, which the flake's dev shell has; without
# them every test skips (test.yml), and nix.yml runs this in the dev shell.

setup_file() {
  for tool in rage rage-keygen ragenix; do
    command -v "$tool" >/dev/null || skip "$tool not found: run in the dev shell"
  done
}

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work/tools/secrets" "$work/secrets"
  cp "$repo/tools/secrets/edit-secret" "$work/tools/secrets/"
  cp "$repo/secrets/secrets.nix" "$work/secrets/"
  export AGE_IDENTITY="$BATS_TEST_TMPDIR/key.txt"
  rage-keygen -o "$AGE_IDENTITY" 2>/dev/null
  {
    echo '# a comment, as the real one has'
    rage-keygen -y "$AGE_IDENTITY"
  } > "$work/secrets/recipients.txt"
  cat > "$BATS_TEST_TMPDIR/write" <<'EOF'
#!/bin/sh
echo 'new secret' > "$1"
EOF
  chmod +x "$BATS_TEST_TMPDIR/write"
  export EDITOR=true
}

edit_secret() {
  run "$work/tools/secrets/edit-secret" "$@"
}

# decrypted NAME: secrets/NAME.age, decrypted with the throwaway key.
decrypted() {
  rage -d -i "$AGE_IDENTITY" "$work/secrets/$1.age"
}

@test "a new secret is created, encrypted to recipients.txt, as a placeholder" {
  edit_secret personal/api-key
  [ "$status" -eq 0 ]
  [[ "$output" == *"created secrets/personal/api-key.age"* ]]
  [ "$(head -n 1 "$work/secrets/personal/api-key.age")" = '-----BEGIN AGE ENCRYPTED FILE-----' ]
  [ "$(decrypted personal/api-key)" = 'replace this line with the secret' ]
}

@test "NAME may end in .age" {
  edit_secret token.age
  [ "$status" -eq 0 ]
  [ -f "$work/secrets/token.age" ]
  [ ! -e "$work/secrets/token.age.age" ]
}

@test "an edit is encrypted back" {
  edit_secret token
  EDITOR="$BATS_TEST_TMPDIR/write" edit_secret token
  [ "$status" -eq 0 ]
  [ "$(decrypted token)" = 'new secret' ]
}

@test "a secret left unchanged is left alone" {
  edit_secret token
  cp "$work/secrets/token.age" "$BATS_TEST_TMPDIR/before"
  edit_secret token
  [ "$status" -eq 0 ]
  [[ "$output" == *"wasn't changed, skipping re-encryption"* ]]
  cmp "$BATS_TEST_TMPDIR/before" "$work/secrets/token.age"
}

@test "without the identity it fails and creates nothing" {
  AGE_IDENTITY="$BATS_TEST_TMPDIR/missing.txt" edit_secret token
  [ "$status" -eq 1 ]
  [[ "$output" == *"no age identity at $BATS_TEST_TMPDIR/missing.txt"* ]]
  [ ! -e "$work/secrets/token.age" ]
}

@test "an identity without a trailing newline fails, with the fix" {
  printf '%s' "$(cat "$AGE_IDENTITY")" > "$BATS_TEST_TMPDIR/nonl.txt"
  AGE_IDENTITY="$BATS_TEST_TMPDIR/nonl.txt" edit_secret token
  [ "$status" -eq 1 ]
  [[ "$output" == *"no trailing newline"* ]]
  [[ "$output" == *"fix: echo >> $BATS_TEST_TMPDIR/nonl.txt"* ]]
  [ ! -e "$work/secrets/token.age" ]
}
