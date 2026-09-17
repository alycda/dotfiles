#!/usr/bin/env bash
# venice-watch.sh — record the Venice balance and warn BEFORE it hits zero.
#
# The problem this solves: on 2026-07-28 the balance went from fine to -$0.24
# with no warning, and the only symptom was hermes reporting "no final response
# was produced" — which reads as an agent bug, not an empty wallet. Hours went
# into misdiagnosing it. A bigger balance does not fix that; visibility does.
#
# Appends a CSV sample each run, computes burn over the last 24h, and Signals
# on: (a) balance below WARN_USD, (b) 24h burn above WARN_BURN, (c) any 402.
# Silent otherwise — a monitor that chirps daily gets muted and stops working.
#
# Run hourly from launchd. Costs nothing: the balance endpoint is free.

set -uo pipefail
BIN=/Users/alyssa/ledger-ingest
CSV="$BIN/venice-balance.csv"
STATE="$BIN/.venice-watch-last-alert"
WARN_USD="${WARN_USD:-3.00}"      # warn when cash buffer drops under this
WARN_BURN="${WARN_BURN:-8.00}"    # warn when 24h spend exceeds this
QUIET_HOURS="${QUIET_HOURS:-6}"   # min hours between repeat alerts

ENVF=/Users/alyssa/hermes-boxed/state/.env
KEY=$(grep -E "^OPENAI_API_KEY=." "$ENVF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\''')
[ -n "$KEY" ] || exit 0

resp=$(curl -s --max-time 20 -H "Authorization: Bearer $KEY" \
  https://api.venice.ai/api/v1/api_keys/rate_limits 2>/dev/null)
[ -n "$resp" ] || exit 0

read -r usd diem permitted <<<"$(/usr/bin/python3 -c '
import json,sys
try:
    d=json.loads(sys.argv[1]); data=d.get("data",d); b=data.get("balances") or {}
    print(b.get("USD") or 0, b.get("DIEM") or 0, data.get("accessPermitted"))
except Exception:
    print("", "", "")
' "$resp")"
[ -n "${usd:-}" ] || exit 0

ts=$(date +%Y-%m-%dT%H:%M:%S%z)
[ -f "$CSV" ] || echo "timestamp,usd,diem,access_permitted" > "$CSV"
echo "$ts,$usd,$diem,$permitted" >> "$CSV"

# 24h burn: compare against the oldest sample within the last 24 hours.
burn=$(/usr/bin/python3 - "$CSV" <<'PY'
import csv, datetime, sys
rows=[]
try:
    with open(sys.argv[1]) as f:
        for r in csv.DictReader(f):
            try:
                t=datetime.datetime.strptime(r["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
                rows.append((t, float(r["usd"]) + float(r["diem"])))
            except Exception:
                continue
except OSError:
    print("0"); raise SystemExit
if len(rows) < 2:
    print("0"); raise SystemExit
now = rows[-1][0]
window = [r for r in rows if (now - r[0]).total_seconds() <= 86400]
if len(window) < 2:
    print("0"); raise SystemExit
# Ignore increases (top-ups and diem refills) — we only want spend.
spend = 0.0
for a, b in zip(window, window[1:]):
    d = a[1] - b[1]
    if d > 0:
        spend += d
print("%.2f" % spend)
PY
)

alerts=""
awk_gt(){ /usr/bin/python3 -c "import sys;print(1 if float(sys.argv[1])>float(sys.argv[2]) else 0)" "$1" "$2"; }

[ "$permitted" = "False" ] && alerts="${alerts}Venice access BLOCKED (USD=$usd DIEM=$diem). The agent cannot run; hermes will report 'no final response was produced'. "
[ "$(awk_gt "$WARN_USD" "$usd")" = "1" ] && [ "$permitted" != "False" ] && \
  alerts="${alerts}Venice cash buffer low: \$$usd (warn under \$$WARN_USD). "
[ "$(awk_gt "$burn" "$WARN_BURN")" = "1" ] && \
  alerts="${alerts}Venice burn in last 24h: \$$burn (warn over \$$WARN_BURN) — check for a runaway loop or a re-inflated prompt. "

[ -z "$alerts" ] && exit 0

# Alert on STATE CHANGE, not on a timer. Repeating "still blocked" every few
# hours through the night is how a monitor gets muted and stops working — and
# a known-bad state you are deliberately waiting out is not news. Re-alert only
# when the situation actually changes, or once a day as a reminder.
now_s=$(date +%s)
sig=$(printf '%s|%s|%s' "$permitted" "$(/usr/bin/python3 -c 'import sys;print(round(float(sys.argv[1])))' "$usd")" "$(/usr/bin/python3 -c 'import sys;print(int(float(sys.argv[1])>8))' "$burn")")
last_sig=$(cut -d' ' -f2- "$STATE" 2>/dev/null || echo "")
last=$(cut -d' ' -f1 "$STATE" 2>/dev/null || echo 0)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
if [ "$sig" = "$last_sig" ] && [ $(( (now_s - last) / 3600 )) -lt 24 ]; then exit 0; fi
echo "$now_s $sig" > "$STATE"

"$BIN/notify.sh" "venice: $alerts(24h burn \$$burn, USD \$$usd, DIEM $diem)" || true
