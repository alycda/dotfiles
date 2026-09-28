#!/usr/bin/env bash
# drop tests for jj-stash, run inside the lab copy. Never the real repo.
set -uo pipefail
S=${S:?}
case $PWD in */scratchpad/lab) ;; *) echo "refusing: not in the lab ($PWD)"; exit 1 ;; esac
J() { jj --no-pager "$@"; }
health() { echo "   health: divergent [$(J log -r 'divergent()' --no-graph -T 'change_id.short() ++ " "')] conflicts [$(J log -r 'conflicts()' --no-graph -T 'change_id.short() ++ " "')]"; }
pass=0; fail=0
check() { if eval "$2"; then echo "   PASS $1"; pass=$((pass+1)); else echo "   FAIL $1"; fail=$((fail+1)); fi; }
visible() { [ -n "$(J log -r "present($1) ~ hidden()" --no-graph -T '"x"' 2>/dev/null)" ]; }

echo "== T1: drop an independent stash"
h=$(git rev-parse refs/jj-stash/docs-solutions/head-0)
out=$("$S" drop docs-solutions 2>&1); echo "$out" | sed 's/^/   | /'
check "refs gone" '[ -z "$(git for-each-ref refs/jj-stash/docs-solutions/)" ]'
check "plaintext gone" '[ ! -e .claude/stashes/docs-solutions.md ]'
check "INDEX no longer lists it" '! grep -q "docs-solutions" .claude/stashes/INDEX.md'
check "list no longer shows it" '! "$S" list 2>/dev/null | grep -q "^docs-solutions "'
check "the commit stays hidden" '! visible "$h"'
check "the commit is still in the store" '[ "$(git cat-file -t "$h")" = commit ]'
hint=$(echo "$out" | sed -n 's/.*recover with: jj new //p')
check "the printed hint names the head" '[ "${h:0:12}" = "$hint" ]'
J new "$hint" -m 'drop test: recovered' >/dev/null 2>&1
check "jj new on the hint brings it back" 'visible "$h"'
J abandon @ >/dev/null 2>&1; J abandon "$h" >/dev/null 2>&1
health

echo "== T2: drop a stash another one sits on (pr-88 needs docs-readme)"
out=$("$S" drop docs-readme 2>&1); echo "$out" | sed 's/^/   | /'
check "refused, naming pr-88" 'echo "$out" | grep -q "^  pr-88$"'
check "the refusal changed nothing" '[ -n "$(git for-each-ref refs/jj-stash/docs-readme/)" ] && [ -e .claude/stashes/docs-readme.md ] && grep -q "docs-readme" .claude/stashes/INDEX.md'

echo "== T3: drop the dependent, then the dependency"
out=$("$S" drop pr-88 2>&1)
check "pr-88 dropped" '[ -z "$(git for-each-ref refs/jj-stash/pr-88/)" ]'
out=$("$S" drop docs-readme 2>&1)
check "docs-readme then drops" '[ -z "$(git for-each-ref refs/jj-stash/docs-readme/)" ]'
check "INDEX lists neither" '! grep -qE "pr-88|docs-readme" .claude/stashes/INDEX.md'
health

echo "== T4: bad arguments"
check "an unknown name fails" '! "$S" drop no-such-stash 2>/dev/null'
check "a missing name fails" '! "$S" drop 2>/dev/null'
check "an extra argument fails" '! "$S" drop vscode-mise extra 2>/dev/null && [ -n "$(git for-each-ref refs/jj-stash/vscode-mise/)" ]'

echo "== T5: drop leaves the other stashes alone"
n0=$(git for-each-ref --format='%(refname)' 'refs/jj-stash/*/head-0' | wc -l)
out=$("$S" pop vscode-mise 2>&1)
check "an unrelated stash still pops" '[ -z "$(git for-each-ref refs/jj-stash/vscode-mise/)" ]'
check "exactly one stash fewer" '[ "$(git for-each-ref --format="%(refname)" "refs/jj-stash/*/head-0" | wc -l)" -eq $((n0 - 1)) ]'
health

echo "== T6: drop a merge that parked lanes were detached from (issue-15 holds the review merge)"
merge=$(git rev-parse refs/jj-stash/issue-15/head-0)
lane=$(git rev-parse refs/jj-stash/issue-104/head-0)
out=$("$S" drop issue-15 2>&1); echo "$out" | sed 's/^/   | /'
check "not refused: nothing sits on issue-15" '[ -z "$(git for-each-ref refs/jj-stash/issue-15/)" ]'
check "warns, naming a lane that loses its merge" 'echo "$out" | grep -q "^  issue-104$"'
check "the lanes no longer need anything" '! "$S" list 2>/dev/null | grep -q "needs: issue-15"'
out=$("$S" pop issue-104 2>&1); echo "$out" | sed 's/^/   | /'
check "a lane pops without --with-deps" '[ -z "$(git for-each-ref refs/jj-stash/issue-104/)" ] && visible "$lane"'
check "it says the merge was not reattached" 'echo "$out" | grep -q "not reattached"'
check "the dropped merge stays hidden" '! visible "$merge"'
health

echo; echo "passed $pass, failed $fail"
