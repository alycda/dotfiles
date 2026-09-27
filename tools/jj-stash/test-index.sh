#!/usr/bin/env bash
# show / INDEX.md / exclude tests for jj-stash, run inside the lab copy only.
set -uo pipefail
S=${S:?}
case $PWD in */scratchpad/lab) ;; *) echo "refusing: not in the lab ($PWD)"; exit 1 ;; esac
J() { jj --no-pager "$@"; }
pass=0; fail=0
check() { if eval "$2"; then echo "   PASS $1"; pass=$((pass+1)); else echo "   FAIL $1"; fail=$((fail+1)); fi; }
IDX=.claude/stashes/INDEX.md
rows() { grep -c '^| \[' "$IDX"; }
row() { grep "^| \[$1\]" "$IDX"; }

echo "== S1: show carries a live needs / needed-by header"
out=$("$S" show pr-88); echo "$out" | head -3 | sed 's/^/   | /'
check "pr-88 needs docs-readme" 'echo "$out" | grep -qx "> needs: docs-readme"'
check "pr-88 is needed by nothing" 'echo "$out" | grep -qx "> needed by: nothing"'
check "the file itself follows the header" 'echo "$out" | grep -q "^# stash: pr-88"'
out=$("$S" show docs-readme)
check "docs-readme needs nothing, is needed by pr-88" 'echo "$out" | grep -qx "> needs: nothing" && echo "$out" | grep -qx "> needed by: pr-88"'
check "show of an unknown stash fails cleanly" '! "$S" show no-such-stash 2>/dev/null'

echo "== S2: index writes INDEX.md from the refs"
n=$(git for-each-ref --format=x 'refs/jj-stash/*/head-0' | wc -l | tr -d ' ')
"$S" index >/dev/null
check "one row per stash ($n)" '[ "$(rows)" = "$n" ]'
echo "   | $(row pr-88)"
check "pr-88 row: 2 commits, sits on the readme commit, needs docs-readme" 'row pr-88 | grep -q "| 2 |" && row pr-88 | grep -q "qyqtxxntuvqr" && row pr-88 | grep -q "| docs-readme |$"'
check "rows without dependencies have an empty needs cell" 'row issue-30 | grep -q "|  |$"'
check "INDEX.md is ignored" 'git check-ignore -q "$IDX"'
check "jj does not see it" '! J status 2>&1 | grep -q INDEX'
check ".claude/stashes/ is now in .git/info/exclude" 'grep -qxF ".claude/stashes/" .git/info/exclude'

echo "== S3: push rewrites the index; INDEX is a reserved name"
"$S" push flake-lock ywqrupmpzmsv >/dev/null 2>&1
check "flake-lock row appears ($((n+1)) rows)" '[ "$(rows)" = "$((n+1))" ] && row flake-lock | grep -q "| 1 |"'
check "push named INDEX is refused" '! "$S" push INDEX ywqrupmpzmsv 2>/dev/null'
"$S" pop flake-lock >/dev/null 2>&1
check "pop removes the row again ($n rows)" '[ "$(rows)" = "$n" ] && ! row flake-lock >/dev/null'

echo "== S4: pop --with-deps rewrites the index once both are back"
"$S" pop --with-deps pr-88 >/dev/null 2>&1
check "neither pr-88 nor docs-readme listed; $((n-2)) rows" '[ "$(rows)" = "$((n-2))" ] && ! row pr-88 >/dev/null && ! row docs-readme >/dev/null'
check "no row needs anything now" '! grep "^| \[" "$IDX" | grep -vq "|  |$"'

echo "== S5: checking out a commit older than the .gitignore rule"
files0=$(ls .claude/stashes | wc -l | tr -d ' ')
J new qzxunzpkkmkq >/dev/null 2>&1     # rung 1: before usn, no .claude/stashes rule in .gitignore
check "the .gitignore on disk no longer covers it" '! grep -q "claude/stashes" .gitignore'
check "stash files are still ignored (via .git/info/exclude)" 'git check-ignore -q .claude/stashes/issue-30.md'
check "nothing under .claude/stashes was snapshotted into @" '[ "$(J file list -r @ | grep -c "^\.claude/stashes/")" = 0 ]'
J new usnoouovpoxn >/dev/null 2>&1
check "moving back leaves every stash file on disk ($files0)" '[ "$(ls .claude/stashes | wc -l | tr -d " ")" = "$files0" ]'

echo "   health: divergent [$(J log -r 'divergent()' --no-graph -T 'change_id.short() ++ " "')] conflicts [$(J log -r 'conflicts()' --no-graph -T 'change_id.short() ++ " "')]"
echo; echo "passed $pass, failed $fail"
