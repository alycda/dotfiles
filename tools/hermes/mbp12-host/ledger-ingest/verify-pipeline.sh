#!/usr/bin/env bash
# verify-pipeline.sh — run this the moment Venice credits are available.
#
# Everything left unresolved on 2026-07-28 was blocked on an exhausted balance.
# Rather than leave that knowledge in a chat log, this script answers all of it
# in one run. Safe to re-run; it approves nothing and commits nothing.
#
#   ./verify-pipeline.sh          # checks 1-3 (cheap, ~$0.01)
#   ./verify-pipeline.sh --draft  # also drafts one staged PDF (~$0.07)
#
# Reports PASS/FAIL per check and exits nonzero if anything failed.

set -uo pipefail
BIN=/Users/alyssa/ledger-ingest
BOX=/Users/alyssa/hermes-boxed
DOCKER=/usr/local/bin/docker
MODEL="${VERIFY_MODEL:-zai-org-glm-5.2}"
fails=0
pass(){ printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
fail(){ printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
info(){ printf '        %s\n' "$*"; }

echo
echo "=============================================================="
echo " 1. CREDITS"
echo "=============================================================="
if out=$("$BIN/preflight.sh" 2>&1); then
    pass "$out"
else
    fail "$out"
    echo
    echo "Everything below needs a working balance. Stopping."
    exit 1
fi

echo
echo "=============================================================="
echo " 2. DOES 'hermes -z' ONE-SHOT MODE WORK?  (the open question)"
echo "=============================================================="
info "Every previous test coincided with an exhausted balance, so the"
info "failure 'no final response was produced' was never explained."
zout=$(cd "$BOX" && "$DOCKER" compose run --rm --no-deps -T draft \
        -z "Reply with exactly: OK" -m "$MODEL" --provider openai-api --yolo --cli \
        </dev/null 2>&1 | grep -viE '^s6-|^cont-init|^/package|^\[stage2\]|^Syncing|^Done:|supervise-perms|reconcile:|^$')
if printf '%s' "$zout" | grep -qi "no final response"; then
    fail "-z STILL fails with credits available — it is a real bug, not billing."
    info "Next step: the gateway HTTP API (:8642 chatCompletions) is a working"
    info "alternative path; draft.sh would need rewriting against it."
elif printf '%s' "$zout" | grep -qi "OK"; then
    pass "-z works. The earlier failures were purely the 402."
else
    fail "-z gave an unexpected result:"
    printf '%s\n' "$zout" | head -5 | sed 's/^/        /'
fi

echo
echo "=============================================================="
echo " 3. DID THE SKILLS PRUNE ACTUALLY SHRINK THE PROMPT?"
echo "=============================================================="
info "107 skills -> 6 was applied, but .skills_prompt_snapshot.json is a"
info "CACHE that only rebuilds on an agent turn. Pre-prune it was 45,283 B"
info "(~11,320 tokens) on EVERY call. Forcing a turn to measure it:"
KEY=$(grep -E "^API_SERVER_KEY=." "$BOX/state/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'')
if [ -n "$KEY" ]; then
    curl -s --max-time 120 -o /dev/null -X POST http://127.0.0.1:8642/v1/chat/completions \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}" 2>/dev/null
    sleep 5
else
    info "(no API_SERVER_KEY found — send one Signal message instead, then re-run)"
fi
snap="$BOX/state/.skills_prompt_snapshot.json"
if [ -f "$snap" ]; then
    b=$(wc -c < "$snap" | tr -d ' ')
    n=$(/usr/bin/python3 -c "import json;print(len(json.load(open('$snap')).get('skills',[])))" 2>/dev/null || echo '?')
    if [ "$b" -lt 8000 ]; then
        pass "snapshot rebuilt: ${b} B (~$((b/4)) tokens), ${n} skills — was 45,283 B / 107"
        info "saving ~$(( (45283-b)/4 )) tokens on every call"
    else
        fail "snapshot still ${b} B with ${n} skills — prune did NOT take effect"
        info "check: ls $BOX/state/skills  and  cat $BOX/state/.no-bundled-skills"
    fi
else
    fail "snapshot absent — no agent turn has happened yet; send a Signal message and re-run"
fi

if [ "${1:-}" = "--draft" ]; then
echo
echo "=============================================================="
echo " 4. REAL DRAFT ON A STAGED STATEMENT"
echo "=============================================================="
    pdf=$(ls -1 /Users/alyssa/ledger/import/*.pdf 2>/dev/null | head -1)
    if [ -z "$pdf" ]; then
        info "nothing staged in import/ — skipping"
    else
        base=$(basename "$pdf")
        info "drafting: $base"
        "$BIN/draft.sh" "$base" manual >/tmp/verify-draft.log 2>&1
        if [ -s "/Users/alyssa/ledger/import/$base.draft.beancount" ]; then
            pass "draft produced: import/$base.draft.beancount"
            head -12 "/Users/alyssa/ledger/import/$base.draft.beancount" | sed 's/^/        /'
            info "gate it with: $BIN/check-draft.sh '$base'"
        else
            fail "no draft file produced — see /tmp/verify-draft.log"
        fi
    fi
fi

echo
echo "=============================================================="
[ "$fails" -eq 0 ] && echo " ALL CHECKS PASSED" || echo " $fails CHECK(S) FAILED"
echo "=============================================================="
exit "$fails"
