#!/usr/bin/env bash
# Ledger inbox pipeline v2 — copy → classify → bookkeeper draft (Hermes) →
# bean-check gate → git commit → Signal notify. Triggered by launchd
# WatchPaths on the iCloud import/ inbox; safe to run manually.
# Agent writes ONLY import/<base>.draft.beancount; ledger files are never
# touched here. Approval happens via fava Import or the Hermes `ledger` skill.
set -uo pipefail

INBOX="$HOME/Library/Mobile Documents/com~apple~CloudDocs/3282/import"
LEDGER="$HOME/ledger"
REPO_IMPORT="$LEDGER/import"
BIN="$HOME/ledger-ingest"
LOG="$BIN/ingest.log"
DOCKER=/usr/local/bin/docker
GIT=/usr/bin/git

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "$(ts) $*" >> "$LOG"; }

shopt -s nullglob
# Subfolders let a second account coexist despite identical filenames. NFCU
# names every statement "<month>_<year>_monthly_statement.pdf" for BOTH the
# credit card and the home equity line, so dropping HELOC statements in the
# top level collides and gets skipped. Put them in e.g. import/heloc/ and they
# are stored prefixed ("heloc-june_2026_...") with the folder as a class hint.
for pdf in "$INBOX"/*.pdf "$INBOX"/*.PDF "$INBOX"/*/*.pdf "$INBOX"/*/*.PDF; do
  rel="${pdf#$INBOX/}"
  hint=""
  if [[ "$rel" == */* ]]; then
    hint="${rel%%/*}"
    base="${hint}-$(basename "$pdf")"
  else
    base=$(basename "$pdf")
  fi
  side="$INBOX/.$base.class"
  [ -e "$side" ] && continue

  mkdir -p "$REPO_IMPORT"
  if [ -e "$REPO_IMPORT/$base" ] && ! cmp -s "$pdf" "$REPO_IMPORT/$base"; then
    log "$base -> SKIPPED (name collision, different content)"
    echo collision > "$side"
    "$BIN/notify.sh" "ledger inbox: $base collides with different content in import/ — skipped" || true
    continue
  fi
  cp -p "$pdf" "$REPO_IMPORT/$base"

  # Full-text extraction (pypdf inside fava-custom; /data mounts ~/ledger).
  # Writes import/<base>.txt for the agent; prints head for classification.
  text=$("$DOCKER" exec fava-custom python -c "
import sys
from pypdf import PdfReader
r = PdfReader('/data/import/' + sys.argv[1])
t = '\n'.join((p.extract_text() or '') for p in r.pages)[:20000]
open('/data/import/' + sys.argv[1] + '.txt', 'w').write(t)
print(t[:4000])
" "$base" 2>/dev/null || true)

  # Image-only PDFs (PayPal) have NO text layer: pypdf returns ~200 bytes of
  # mail-barcode junk. That is not empty, so it would sail past the -z guard
  # below and be classified from garbage. Fall back to macOS Vision OCR
  # (pdfocr, compiled Swift, no network) whenever the text layer is too thin.
  txt="$REPO_IMPORT/$base.txt"
  tlen=$(wc -c < "$txt" 2>/dev/null | tr -d ' ')
  tlen=${tlen:-0}
  if [ "$tlen" -lt 400 ] && [ -x "$BIN/pdfocr" ]; then
    log "$base -> text layer thin (${tlen}B); running OCR fallback"
    if "$BIN/pdfocr" "$REPO_IMPORT/$base" "$txt" >/dev/null 2>&1; then
      text=$(head -c 4000 "$txt" 2>/dev/null || true)
      log "$base -> OCR produced $(wc -c < "$txt" | tr -d ' ')B"
    else
      log "$base -> OCR FAILED"
    fi
  fi

  class=unknown
  case "$text" in
    *Rippling*|*"EARNINGS STATEMENT"*)  class=paystub-ditto ;;
    *"Ally Bank"*)                      class=ally ;;
    *FORDTRANSIT*|*"FORD TRANSIT"*)     class=bofa-van-loan ;;
    *"Bank of America"*)                class=bofa-card ;;
    *"Navy Federal"*)                   class=nfcu ;;
    *"PayPal Credit"*|*PayPal*)         class=paypal ;;
    *Citi*|*Costco*)                    class=citi-or-costco ;;
    *Escrow*|*"Unpaid principal"*)      class=mortgage ;;
    *Optum*)                            class=optum-hsa ;;
    *Empower*)                          class=empower ;;
    *Schwab*)                           class=schwab ;;
  esac
  [ -z "$text" ] && class=unreadable-or-image-only
  # an explicit subfolder beats content sniffing (HELOC statements otherwise
  # look enough like the card's to be misfiled)
  [ -n "$hint" ] && class="$hint"
  echo "$class" > "$side"
  log "$base -> $class"

  case "$class" in
    unknown|unreadable-or-image-only)
      "$BIN/notify.sh" "ledger inbox: $base -> $class (no auto-draft; staged in import/, handle manually)" || true
      continue ;;
  esac

  draft="$REPO_IMPORT/$base.draft.beancount"
  "$BIN/draft.sh" "$base" "$class" >> "$LOG" 2>&1
  if [ ! -s "$draft" ]; then
    log "$base draft -> agent produced no draft"
    "$BIN/notify.sh" "ledger: $base ($class) — agent produced no draft (Anthropic auth? see ingest.log)" || true
  elif grep -q REVIEW_NEEDED "$draft"; then
    log "$base draft -> REVIEW_NEEDED"
    "$BIN/notify.sh" "ledger: $base ($class) needs review — import/$base.draft.beancount" || true
  elif "$BIN/check-draft.sh" "$base.draft.beancount" >> "$LOG" 2>&1; then
    ( cd "$LEDGER" && $GIT add -A import/ && \
      $GIT commit -q -m "[ingest] draft: $base ($class)" && \
      $GIT push -q origin main ) >> "$LOG" 2>&1 || log "$base git commit/push failed"
    log "$base draft -> CLEAN, committed"
    "$BIN/notify.sh" "ledger: $base ($class) drafted, bean-check CLEAN. Approve on fava Import page or tell Hermes: approve $base" || true
  else
    log "$base draft -> BEAN-CHECK GATE FAILED"
    "$BIN/notify.sh" "ledger: $base ($class) draft FAILED bean-check — import/$base.draft.beancount + ingest.log" || true
  fi
done
