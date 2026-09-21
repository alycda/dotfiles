#!/usr/bin/env bash
# Ledger inbox pipeline v3 — move → extract → classify → bookkeeper draft
# (Hermes) → bean-check gate → git commit → Signal notify. Triggered by
# launchd WatchPaths on the iCloud import/ inbox; safe to run manually.
# Agent writes ONLY import/<base>.draft.beancount; ledger files are never
# touched here. Approval happens via fava Import or the Hermes `ledger` skill.
#
# v3 (2026-08-29):
#  - the inbox PDF is MOVED out of the inbox (after a byte-compare of the repo
#    copy), so the iCloud folder is a real queue: present = not yet ingested.
#    v2 copied and left a hidden .<name>.class marker behind, which made the
#    folder grow forever and marked a PAUSED-skipped file as done so it was
#    never retried. The original goes to LedgerDocs/_backups/pdf-originals/, not the
#    bin: repo PDFs are gitignored and the weekly tarball has no PDFs, so the
#    iCloud copy is the only offsite one.
#  - PAUSED short-circuits the whole run; files wait in the inbox untouched.
#  - extraction text lives in import/.cache/<base>.txt (fava ignores .cache/),
#    not beside the PDF where it doubled the Import page.
set -uo pipefail

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/LedgerDocs"
INBOX="$ICLOUD/import"
ORIGINALS="$ICLOUD/_backups/pdf-originals"
LEDGER="$HOME/ledger"
REPO_IMPORT="$LEDGER/import"
TXT_DIR="$REPO_IMPORT/.cache"
BIN="$HOME/ledger-ingest"
LOG="$BIN/ingest.log"
DOCKER=/usr/local/bin/docker
GIT=/usr/bin/git

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "$(ts) $*" >> "$LOG"; }

shopt -s nullglob
pending=("$INBOX"/*.pdf "$INBOX"/*.PDF "$INBOX"/*/*.pdf "$INBOX"/*/*.PDF)
[ ${#pending[@]} -eq 0 ] && exit 0

if [ -f "$BIN/PAUSED" ]; then
  log "PAUSED — ${#pending[@]} pdf(s) waiting in the inbox; rm $BIN/PAUSED to resume"
  exit 0
fi

mkdir -p "$REPO_IMPORT" "$TXT_DIR" "$ORIGINALS"

# Subfolders let a second account coexist despite identical filenames. BANKA
# names every statement "<month>_<year>_monthly_statement.pdf" for BOTH the
# credit card and the home equity line, so dropping LOANA statements in the
# top level collides and gets skipped. Put them in e.g. import/loana/ and they
# are stored prefixed ("loana-june_2026_...") with the folder as a class hint.
for pdf in "${pending[@]}"; do
  rel="${pdf#$INBOX/}"
  hint=""
  if [[ "$rel" == */* ]]; then
    hint="${rel%%/*}"
    base="${hint}-$(basename "$pdf")"
  else
    base=$(basename "$pdf")
  fi

  # A collision is the one case that leaves a file in the inbox on purpose;
  # the marker stops the watcher re-notifying on every trigger.
  side="$INBOX/.$base.class"
  if [ -e "$REPO_IMPORT/$base" ] && ! cmp -s "$pdf" "$REPO_IMPORT/$base"; then
    [ -e "$side" ] && continue
    log "$base -> SKIPPED (name collision, different content)"
    echo collision > "$side"
    "$BIN/notify.sh" "ledger inbox: $base collides with different content in import/ — left in inbox" || true
    continue
  fi

  # Copy, verify, then move the original aside. iCloud can hand us a
  # partially-downloaded file; the byte-compare catches that and leaves the
  # original in the inbox for the next trigger.
  cp -p "$pdf" "$REPO_IMPORT/$base"
  if cmp -s "$pdf" "$REPO_IMPORT/$base"; then
    mv -f "$pdf" "$ORIGINALS/$base"
    rm -f "$side"
  else
    log "$base -> copy did not verify; original left in inbox for retry"
    rm -f "$REPO_IMPORT/$base"
    continue
  fi

  # Full-text extraction (pypdf inside fava-custom; /data mounts ~/ledger).
  # Writes import/.cache/<base>.txt for the agent; prints head for classification.
  txt="$TXT_DIR/$base.txt"
  text=$("$DOCKER" exec fava-custom python -c "
import sys, os
from pypdf import PdfReader
r = PdfReader('/data/import/' + sys.argv[1])
t = '\n'.join((p.extract_text() or '') for p in r.pages)[:20000]
os.makedirs('/data/import/.cache', exist_ok=True)
open('/data/import/.cache/' + sys.argv[1] + '.txt', 'w').write(t)
print(t[:4000])
" "$base" 2>/dev/null || true)

  # Image-only PDFs (CardB) have NO text layer: pypdf returns ~200 bytes of
  # mail-barcode junk. That is not empty, so it would sail past the -z guard
  # below and be classified from garbage. Fall back to macOS Vision OCR
  # (pdfocr, compiled Swift, no network) whenever the text layer is too thin.
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
    *PayrollI*|*"EARNINGS STATEMENT"*)  class=paystub-employer ;;
    *"Bank G"*)                      class=bankg ;;
    *VEHICLEH*|*"VEHICLE H"*)     class=bankf-vehicle-loan ;;
    *"Bank F"*)                class=bankf-card ;;
    *"Bank A"*)                   class=banka ;;
    *"Card B"*|*CardB*)         class=cardb ;;
    *BankD*|*StoreE*)                    class=bankd-or-storee ;;
    *Escrow*|*"Unpaid principal"*)      class=mortgage ;;
    *HsaJ*)                            class=hsaj-hsa ;;
    *RetirementK*)                          class=retirementk ;;
    *BrokerL*)                           class=brokerl ;;
  esac
  [ -z "$text" ] && class=unreadable-or-image-only
  # an explicit subfolder beats content sniffing (LOANA statements otherwise
  # look enough like the card's to be misfiled)
  [ -n "$hint" ] && class="$hint"
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
    ( cd "$LEDGER" && $GIT add "import/$base.draft.beancount" && \
      $GIT commit -q -m "[ingest] draft: $base ($class)" ) >> "$LOG" 2>&1 || log "$base git commit failed"
    # Offsite copy, encrypted (offsite-ledger.sh). The commit above is what
    # counts; a failed copy is retried by the next run.
    "$BIN/offsite-ledger.sh" >> "$LOG" 2>&1 || log "$base offsite copy failed (commit is local)"
    log "$base draft -> CLEAN, committed"
    "$BIN/notify.sh" "ledger: $base ($class) drafted, bean-check CLEAN. Approve on fava Import page or tell Hermes: approve $base" || true
  else
    log "$base draft -> BEAN-CHECK GATE FAILED"
    "$BIN/notify.sh" "ledger: $base ($class) draft FAILED bean-check — import/$base.draft.beancount + ingest.log" || true
  fi
done
