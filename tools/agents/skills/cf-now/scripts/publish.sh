#!/usr/bin/env bash
# Upload a file (or dir) to the private cf-now R2 bucket and print a pre-signed
# URL. The bucket is never public: generating a URL requires the R2 API token
# credentials, and the URL itself is the time-limited grant you hand to viewers.
#
#   publish.sh <file-or-dir> [--slug SLUG] [--expires 12h] [--permanent]
#   publish.sh --presign --slug SLUG [--expires 12h]    re-issue URL, no upload
#   publish.sh --list                                    list uploads in bucket
#   publish.sh --unpublish --slug SLUG                   delete an upload
#
# Ephemeral by default: uploads land under tmp/ and auto-delete after ~7 days.
# Keys are opaque random strings — unguessable by design; the pre-signed
# signature is the actual gate.
#
# Expiry: raw seconds, or Nm/Nh/Nd (max 7d — R2/SigV4 hard cap). With a
# long-lived R2 token the URL lasts its full requested lifetime; rotating or
# revoking the token invalidates every URL it signed.
#
# State: .cfnow/state.json in the working directory (slug -> key map).
set -euo pipefail

# AWS CLI v2's newer default request checksums trip R2 uploads (400 /
# XAmzContentSHA256Mismatch); only send them when the API requires it.
export AWS_REQUEST_CHECKSUM_CALCULATION="${AWS_REQUEST_CHECKSUM_CALCULATION:-when_required}"
export AWS_RESPONSE_CHECKSUM_VALIDATION="${AWS_RESPONSE_CHECKSUM_VALIDATION:-when_required}"

CONFIG="$HOME/.cfnow/config.json"
STATE_DIR=".cfnow"
STATE="$STATE_DIR/state.json"

die() { echo "error: $1" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }
need_cmd aws
need_cmd jq

[[ -f "$CONFIG" ]] || die "no config at $CONFIG — run setup.sh first"
PROFILE="$(jq -r .profile "$CONFIG")"
REGION="$(jq -r .region "$CONFIG")"
BUCKET="$(jq -r .bucket "$CONFIG")"
ENDPOINT="$(jq -r .endpoint "$CONFIG")"
[[ -n "$ENDPOINT" && "$ENDPOINT" != "null" ]] || die "config missing endpoint — re-run setup.sh"
AWSP=(aws --profile "$PROFILE" --region "$REGION" --endpoint-url "$ENDPOINT")

SRC=""
SLUG=""
EXPIRES_RAW="12h"
EPHEMERAL=true
PRESIGN_ONLY=false
UNPUBLISH=false
LIST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)      SLUG="$2"; shift 2 ;;
    --expires)   EXPIRES_RAW="$2"; shift 2 ;;
    --ephemeral) EPHEMERAL=true; shift ;;
    --permanent) EPHEMERAL=false; shift ;;
    --presign)   PRESIGN_ONLY=true; shift ;;
    --unpublish) UNPUBLISH=true; shift ;;
    --list)      LIST=true; shift ;;
    --profile)   PROFILE="$2"; AWSP=(aws --profile "$PROFILE" --region "$REGION" --endpoint-url "$ENDPOINT"); shift 2 ;;
    -*)          die "unknown flag: $1" ;;
    *)           SRC="$1"; shift ;;
  esac
done

case "$EXPIRES_RAW" in
  *m) EXPIRES=$(( ${EXPIRES_RAW%m} * 60 )) ;;
  *h) EXPIRES=$(( ${EXPIRES_RAW%h} * 3600 )) ;;
  *d) EXPIRES=$(( ${EXPIRES_RAW%d} * 86400 )) ;;
  *[!0-9]*) die "bad --expires value: $EXPIRES_RAW (use seconds or Nm/Nh/Nd)" ;;
  *)  EXPIRES="$EXPIRES_RAW" ;;
esac
(( EXPIRES > 604800 )) && die "--expires exceeds the 7-day R2 pre-sign cap"

# R2 has no STS; a ListBuckets call is the cheapest auth probe.
if ! "${AWSP[@]}" s3api list-buckets >/dev/null 2>&1; then
  die "not authenticated. Configure the R2 token creds for profile '$PROFILE' (see SKILL.md → Authentication)"
fi

state_get_key() {
  [[ -f "$STATE" ]] && jq -r --arg s "$1" '.publishes[$s].key // empty' "$STATE" || true
}

state_put() {
  local slug="$1" key="$2" eph="$3"
  mkdir -p "$STATE_DIR"
  [[ -f "$STATE" ]] || echo '{"publishes":{}}' > "$STATE"
  jq --arg s "$slug" --arg k "$key" --argjson e "$eph" \
     --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.publishes[$s] = {key: $k, ephemeral: $e, publishedAt: $t}' \
     "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

presign() {
  local key="$1"
  "${AWSP[@]}" s3 presign "s3://$BUCKET/$key" --expires-in "$EXPIRES"
}

if $LIST; then
  "${AWSP[@]}" s3 ls "s3://$BUCKET/" --recursive | awk '{print $1, $2, $4}'
  exit 0
fi

if $UNPUBLISH; then
  [[ -n "$SLUG" ]] || die "--unpublish requires --slug"
  KEY="$(state_get_key "$SLUG")"
  PREFIX="${KEY%/*}"
  [[ -n "$KEY" ]] || { PREFIX="$SLUG"; }
  "${AWSP[@]}" s3 rm "s3://$BUCKET/$PREFIX/" --recursive --only-show-errors
  [[ -f "$STATE" ]] && jq --arg s "$SLUG" 'del(.publishes[$s])' "$STATE" > "$STATE.tmp" \
    && mv "$STATE.tmp" "$STATE"
  echo "removed r2://$BUCKET/$PREFIX/"
  exit 0
fi

if $PRESIGN_ONLY; then
  [[ -n "$SLUG" ]] || die "--presign requires --slug"
  KEY="$(state_get_key "$SLUG")"
  if [[ -z "$KEY" ]]; then
    KEY="$("${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" --prefix "$SLUG/" \
      --max-items 1 --output json | jq -r '.Contents[0].Key // empty')"
    [[ -z "$KEY" ]] && KEY="$("${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" \
      --prefix "tmp/$SLUG/" --max-items 1 --output json | jq -r '.Contents[0].Key // empty')"
  fi
  [[ -n "$KEY" ]] || die "no upload found for slug '$SLUG'"
  echo "presign_result.key=$KEY" >&2
  echo "presign_result.expires_in=${EXPIRES}s (or immediately, if the R2 token is rotated/revoked)" >&2
  presign "$KEY"
  exit 0
fi

# --- upload -------------------------------------------------------------------
[[ -n "$SRC" ]] || die "usage: publish.sh <file-or-dir> [--slug SLUG] [--expires 12h] [--permanent]"
[[ -e "$SRC" ]] || die "no such file or directory: $SRC"

# Opaque, unguessable key segment — these URLs are meant to be pasted, not
# typed or remembered. 128 bits of entropy. od reads exactly 16 bytes, so no
# SIGPIPE under pipefail (tr|head from urandom would exit 141).
gen_slug() {
  od -An -tx1 -N16 /dev/urandom | tr -d ' \n'
}

if [[ -n "$SLUG" ]]; then
  [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug must be lowercase alphanumeric/hyphens"
else
  SLUG="$(gen_slug)"
fi
$EPHEMERAL && PREFIX="tmp/$SLUG" || PREFIX="$SLUG"

content_type_flag() {
  case "$1" in
    *.html|*.htm) echo "--content-type text/html" ;;
    *.md)         echo "--content-type text/plain" ;;
    *.pdf)        echo "--content-type application/pdf" ;;
    *)            echo "" ;;
  esac
}

if [[ -d "$SRC" ]]; then
  echo "note: pre-signed URLs are per-object — a multi-file site's relative asset links will NOT resolve. Prefer a single self-contained HTML file." >&2
  "${AWSP[@]}" s3 sync "$SRC" "s3://$BUCKET/$PREFIX/" --delete --only-show-errors
  if [[ -f "$SRC/index.html" ]]; then
    KEY="$PREFIX/index.html"
  else
    KEY="$("${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" --prefix "$PREFIX/" \
      --max-items 1 --output json | jq -r '.Contents[0].Key')"
  fi
else
  KEY="$PREFIX/$(basename "$SRC")"
  # shellcheck disable=SC2046
  "${AWSP[@]}" s3 cp "$SRC" "s3://$BUCKET/$KEY" --only-show-errors \
    $(content_type_flag "$SRC") --content-disposition inline
fi

state_put "$SLUG" "$KEY" "$EPHEMERAL"

echo "publish_result.slug=$SLUG" >&2
echo "publish_result.key=$KEY" >&2
echo "publish_result.ephemeral=$EPHEMERAL" >&2
$EPHEMERAL && echo "publish_result.storage_expires=~7 days (bucket lifecycle rule)" >&2
echo "publish_result.url_expires_in=${EXPIRES}s (or immediately, if the R2 token is rotated/revoked)" >&2
presign "$KEY"
