#!/usr/bin/env bash
# Dependency tests for jj-stash, run inside the lab copy. Never the real repo.
set -uo pipefail
S=${S:?}
case $PWD in */scratchpad/lab) ;; *) echo "refusing: not in the lab ($PWD)"; exit 1 ;; esac
J() { jj --no-pager "$@"; }
ids() { J log -r "$1" --no-graph -T 'change_id.short() ++ ":" ++ commit_id.short() ++ " "' 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ' '; }
health() { echo "   health: divergent [$(J log -r 'divergent()' --no-graph -T 'change_id.short() ++ " "')] conflicts [$(J log -r 'conflicts()' --no-graph -T 'change_id.short() ++ " "')]"; }
pass=0; fail=0
check() { if eval "$2"; then echo "   PASS $1"; pass=$((pass+1)); else echo "   FAIL $1"; fail=$((fail+1)); fi; }
quiet() { "$@" 2>&1 | grep -vE '^(Created|Deleted|Abandoned|Rebased|  [a-z]{8}[ /]|Warning: No matching)'; }

echo "== T1: dangling first, then the chain it dangles from; pop in the wrong order"
a0=$(ids 'change_id(ywqrupmpzmsv)'); b0=$(ids 'change_id(zqwrsynstrny)::')
quiet "$S" push flake-lock ywqrupmpzmsv
out=$("$S" push nix-lane 'zqwrsynstrny::' 2>&1); echo "$out" | grep -E '^(parked|note)'
check "push of the chain warns that flake-lock depends on it" 'echo "$out" | grep -q "note: flake-lock depends on this stash"'
out=$("$S" pop flake-lock 2>&1); echo "$out" | sed 's/^/   | /'
check "pop in the wrong order is refused" '[ -n "$(git for-each-ref refs/jj-stash/flake-lock/)" ] && echo "$out" | grep -q "pop nix-lane"'
check "the refusal changed nothing (zqw still hidden)" '[ -z "$(J log -r "present(change_id(zqwrsynstrny)) ~ hidden()" --no-graph -T x 2>/dev/null)" ]'
echo "   list: $("$S" list 2>/dev/null | grep -E '^(flake-lock|nix-lane)' | tr -s ' ' | paste -sd';' -)"
quiet "$S" pop nix-lane; quiet "$S" pop flake-lock
check "right order restores identical ids (chain)" '[ "$b0" = "$(ids "change_id(zqwrsynstrny)::")" ]'
check "right order restores identical ids (flake-lock)" '[ "$a0" = "$(ids "change_id(ywqrupmpzmsv)")" ]'
health

echo "== T2: same setup, pop --with-deps on the dependent stash"
quiet "$S" push flake-lock ywqrupmpzmsv; "$S" push nix-lane 'zqwrsynstrny::' >/dev/null 2>&1
out=$("$S" pop --with-deps flake-lock 2>&1); echo "$out" | grep -E '^(restored|jj-stash)' | sed 's/^/   | /'
check "--with-deps pops nix-lane before flake-lock" '[ "$(echo "$out" | grep ^restored | paste -sd, -)" = "restored nix-lane,restored flake-lock" ]'
check "identical ids after --with-deps" '[ "$b0" = "$(ids "change_id(zqwrsynstrny)::")" ] && [ "$a0" = "$(ids "change_id(ywqrupmpzmsv)")" ]'
check "no refs left" '[ -z "$(git for-each-ref refs/jj-stash/flake-lock/ refs/jj-stash/nix-lane/)" ]'
health

echo "== T3: reattach dependency. issue-99 feeds the merge zpo; park issue-99, then zpo's line"
np0=$(J log -r zpozyzunqsuu --no-graph -T 'parents.len()')
quiet "$S" push issue-99 'wurznuuksntx::ywllsomvqvzn'
out=$("$S" push mise-line 'zpozyzunqsuu::' 2>&1); echo "$out" | grep -E '^(parked|note|jj-stash)'
check "push of the merge's line warns that issue-99 depends on it" 'echo "$out" | grep -q "note: issue-99 depends on this stash"'
out=$("$S" pop issue-99 2>&1)
check "pop issue-99 first is refused (its detached child zpo is parked)" 'echo "$out" | grep -q "pop mise-line"'
quiet "$S" pop --with-deps issue-99
check "zpo gets issue-99 back as a parent ($np0 parents)" '[ "$(J log -r zpozyzunqsuu --no-graph -T "parents.len()")" = "$np0" ] && J log -r "zpozyzunqsuu-" --no-graph -T "change_id.short() ++ \" \"" | grep -q ywllsomvqvzn'
health

echo "== T4: the real case found in your stashes: pr-88 needs docs-readme"
out=$("$S" pop pr-88 2>&1)
check "pop pr-88 alone is refused, naming docs-readme" 'echo "$out" | grep -q "pop docs-readme"'
out=$("$S" pop --with-deps pr-88 2>&1); echo "$out" | grep -E '^(restored|jj-stash)' | sed 's/^/   | /'
check "--with-deps restores docs-readme, then pr-88" '[ "$(echo "$out" | grep ^restored | paste -sd, -)" = "restored docs-readme,restored pr-88" ]'
check "PR-88 sits on the readme commit again" 'J log -r "change_id(ztorvwpuvsrs)-" --no-graph -T "change_id.short()" | grep -q qyqtxxntuvqr'
health

echo "== T5: no false positives: an independent stash pops without --with-deps"
quiet "$S" pop issue-30
check "issue-30 popped" '[ -z "$(git for-each-ref refs/jj-stash/issue-30/)" ]'
health

echo; echo "passed $pass, failed $fail"
