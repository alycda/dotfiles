#!/usr/bin/env bash
# Preflight: can the Venice account serve a request at all?
#
# Hermes swallows HTTP 402 and reports only "hermes -z: no final response was
# produced; treating the run as failed", which is indistinguishable from a real
# agent failure. That cost hours of misdiagnosis. Check the balance FIRST so the
# pipeline log says "OUT OF CREDITS" instead of blaming the agent.
#
# Exit 0 = ok to run. Exit 1 = do not run (reason printed).
set -uo pipefail
ENVF=/Users/alyssa/hermes-boxed/state/.env
KEY=$(grep -E "^OPENAI_API_KEY=." "$ENVF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\''')
[ -n "$KEY" ] || { echo "PREFLIGHT: no OPENAI_API_KEY in $ENVF"; exit 1; }

resp=$(curl -s --max-time 20 -H "Authorization: Bearer $KEY" \
  https://api.venice.ai/api/v1/api_keys/rate_limits 2>/dev/null)
[ -n "$resp" ] || { echo "PREFLIGHT: Venice unreachable (network or API down)"; exit 1; }

/usr/bin/python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print("PREFLIGHT: unparseable Venice response"); sys.exit(1)
data = d.get("data", d)
b = data.get("balances") or {}
usd = b.get("USD") or 0
diem = b.get("DIEM") or 0
if usd <= 0 and diem <= 0:
    print("PREFLIGHT: OUT OF CREDITS (USD=%s DIEM=%s) -- Venice returns HTTP 402 and "
          "the agent CANNOT run. Diem allowance refills ~5pm daily." % (usd, diem))
    sys.exit(1)
print("PREFLIGHT: ok (USD=%s DIEM=%s)" % (usd, diem))
' "$resp"
