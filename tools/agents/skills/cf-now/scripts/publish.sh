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
# Config: ~/.cfnow/config.json is optional — settings fall back to the AWS
# profile (endpoint_url, region) and to defaults. See the resolution block below.
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

# Config resolution: ~/.cfnow/config.json, then the environment, then the AWS
# profile itself, then defaults.
#
# That file is OPTIONAL on purpose. It used to be a hard requirement, and the
# only thing that writes it is setup.sh - which probes with account-level
# ListBuckets and so cannot run with the Object Read & Write token this skill
# recommends minting. The two facts together made a fresh machine unable to
# publish at all: credentials decrypt fine, setup.sh refuses to run, publish.sh
# dies "run setup.sh first", and setup.sh's own error tells you to skip it.
#
# Nothing in it was ever secret or even interesting - four of the five fields
# are constants, and the fifth (the endpoint) is already in ~/.aws/config,
# which cfNow.enable decrypts. So ask the AWS profile instead of demanding a
# hand-maintained file in $HOME that no generation manages.
#
# `// empty` on every read, not bare `jq -r`: a missing key yields the *string*
# "null", which would sail into `aws --profile null` and die inside the CLI
# rather than here.
cfg() {
  [[ -f "$CONFIG" ]] || return 0
  jq -r --arg k "$1" '.[$k] // empty' "$CONFIG" 2>/dev/null || true
}

PROFILE="$(cfg profile)";   PROFILE="${PROFILE:-${CFNOW_PROFILE:-alyssa-r2}}"
BUCKET="$(cfg bucket)";     BUCKET="${BUCKET:-${CFNOW_BUCKET:-cf-now}}"
REGION="$(cfg region)"
ENDPOINT="$(cfg endpoint)"

[[ -n "$ENDPOINT" ]] || ENDPOINT="${CFNOW_ENDPOINT:-}"
[[ -n "$ENDPOINT" ]] || ENDPOINT="$(aws configure get endpoint_url --profile "$PROFILE" 2>/dev/null || true)"
if [[ -z "$ENDPOINT" && -n "${CF_ACCOUNT_ID:-}" ]]; then
  ENDPOINT="https://${CF_ACCOUNT_ID}.r2.cloudflarestorage.com"
fi
[[ -n "$ENDPOINT" ]] || die "no R2 endpoint. Set one of: endpoint in $CONFIG, \$CFNOW_ENDPOINT, \$CF_ACCOUNT_ID, or endpoint_url in the '$PROFILE' AWS profile (cfNow.enable writes that one for you)"

[[ -n "$REGION" ]] || REGION="$(aws configure get region --profile "$PROFILE" 2>/dev/null || true)"
REGION="${REGION:-auto}"   # R2 is always 'auto'

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

# Parse --expires with a strict regex FIRST — never feed unvalidated input to
# $(( )). Bash runs command substitution on array subscripts inside arithmetic,
# so a glob like *m) matching `a[$(touch x)]m` would execute it. Requiring
# ^digits + optional single unit also rejects negatives, empties, and `abcm`.
if [[ "$EXPIRES_RAW" =~ ^([0-9]+)([mhd]?)$ ]]; then
  _n="${BASH_REMATCH[1]}"
  case "${BASH_REMATCH[2]}" in
    m)  EXPIRES=$(( _n * 60 )) ;;
    h)  EXPIRES=$(( _n * 3600 )) ;;
    d)  EXPIRES=$(( _n * 86400 )) ;;
    "") EXPIRES="$_n" ;;
  esac
else
  die "bad --expires value: $EXPIRES_RAW (use seconds or Nm/Nh/Nd)"
fi
(( EXPIRES >= 1 )) || die "--expires must be a positive duration"
(( EXPIRES > 604800 )) && die "--expires exceeds the 7-day R2 pre-sign cap"

# Validate the slug HERE, not in the upload path - --unpublish and --presign
# both take --slug and both return before the upload path is ever reached, so a
# check down there guards the one caller that cannot do damage.
#
# `tmp` is the ephemeral *prefix*, not a slug, and it passes the character
# class. Two ways that bites, both silent:
#   --unpublish --slug tmp  resolves PREFIX to `tmp` (the bare-slug candidate
#     matches every ephemeral object), then runs
#     `s3 rm s3://$BUCKET/tmp/ --recursive` - deleting every ephemeral upload in
#     the bucket - and prints "removed".
#   --permanent --slug tmp  writes to tmp/<file>, which the expire-tmp rule
#     deletes after 7 days, while the script reports the upload as permanent.
RESERVED_SLUGS=("tmp")

if [[ -n "$SLUG" ]]; then
  [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug must be lowercase alphanumeric/hyphens"
  # case, not `[[ ]] && die` in a loop: under `set -e` a false test as the last
  # command of a loop body exits the script.
  case " ${RESERVED_SLUGS[*]} " in
    *" $SLUG "*) die "'$SLUG' is a reserved key prefix, not a slug — publishing there would collide with the ephemeral namespace, and unpublishing it would delete every ephemeral upload in the bucket" ;;
  esac
fi

# R2 has no STS, so the auth probe is an ordinary call. It must be a
# *bucket-scoped* one: ListBuckets is an account-level operation, and an R2
# token scoped to specific buckets - the least privilege this script needs, and
# what SKILL.md now recommends minting - cannot make it. Probing with
# ListBuckets reported "not authenticated" on a token that could read, write,
# delete and pre-sign in the target bucket perfectly well (verified against a
# live Object Read & Write token, 2026-08-05). An auth probe demanding broader
# rights than the tool itself is backwards.
#
# HeadBucket also fails closed for the case that actually matters: R2 answers
# AccessDenied rather than NoSuchBucket for a bucket outside the token's scope,
# so a wrong bucket name and a wrong scope are indistinguishable here - hence
# naming both possibilities in the error.
if ! "${AWSP[@]}" s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  die "cannot reach bucket '$BUCKET' with profile '$PROFILE' — check the bucket name, and that the R2 token is scoped to it (see SKILL.md → Authentication)"
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
  # jq, not awk: aws and jq are already hard dependencies (need_cmd above),
  # awk never was - so on a host without it `--list` died with a raw
  # "awk: command not found" rather than this script's own error. The dev
  # container has no awk at all (no gawk, mawk or busybox either), which is
  # how this surfaced.
  #
  # list-objects-v2 over `s3 ls` while here: it returns structured JSON
  # instead of human-formatted columns that a positional field parse can
  # silently misread, and `.Contents[]?` yields nothing on an empty bucket -
  # where --query with --output text would print the literal "None".
  "${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" --output json \
    | jq -r '.Contents[]? | [.LastModified, .Key] | @tsv'
  exit 0
fi

if $UNPUBLISH; then
  [[ -n "$SLUG" ]] || die "--unpublish requires --slug"
  # This is the revocation path — it must fail CLOSED. State lives in the
  # working directory, so unpublishing from a different dir than you published
  # from means state is absent; the old fallback (PREFIX="$SLUG") then rm'd a
  # nonexistent prefix, which exits 0 and reports success while the object —
  # ephemeral uploads live at tmp/$SLUG/, the default — stays live. Probe the
  # live bucket for the real prefix (tmp/ first, then the bare permanent slug),
  # the same way --presign resolves its key, and refuse to claim success unless
  # an object was actually there.
  PREFIX=""
  for _cand in "tmp/$SLUG" "$SLUG"; do
    FOUND="$("${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" --prefix "$_cand/" \
      --max-items 1 --output json | jq -r '.Contents[0].Key // empty')"
    [[ -n "$FOUND" ]] && { PREFIX="$_cand"; break; }
  done
  [[ -n "$PREFIX" ]] || die "no upload found for slug '$SLUG' — nothing to unpublish"
  "${AWSP[@]}" s3 rm "s3://$BUCKET/$PREFIX/" --recursive --only-show-errors
  [[ -f "$STATE" ]] && jq --arg s "$SLUG" 'del(.publishes[$s])' "$STATE" > "$STATE.tmp" \
    && mv "$STATE.tmp" "$STATE"
  echo "removed r2://$BUCKET/$PREFIX/"
  exit 0
fi

if $PRESIGN_ONLY; then
  [[ -n "$SLUG" ]] || die "--presign requires --slug"
  KEY="$(state_get_key "$SLUG")"
  # A cached key proves the slug was published once, not that it is still
  # there: state.json keeps its entry forever while the lifecycle rule deletes
  # the object after ~7 days. Presigning a dead key mints a valid-looking URL
  # that 404s - worse than failing, because SKILL.md tells the agent to
  # reassure the user that re-presigning restores access. Verify, and fall
  # through to the bucket search on a miss (which already fails closed).
  if [[ -n "$KEY" ]] && ! "${AWSP[@]}" s3api head-object \
       --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
    echo "note: state had a key for '$SLUG' but no such object in the bucket — re-resolving" >&2
    KEY=""
  fi
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

# Validated up front, alongside the reserved-prefix check.
[[ -n "$SLUG" ]] || SLUG="$(gen_slug)"
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
    # `// empty` like every other call site here. Without it an empty result
    # prints the string "null", which is then recorded in state and pre-signed
    # as s3://$BUCKET/null - a successful-looking publish of nothing.
    KEY="$("${AWSP[@]}" s3api list-objects-v2 --bucket "$BUCKET" --prefix "$PREFIX/" \
      --max-items 1 --output json | jq -r '.Contents[0].Key // empty')"
    [[ -n "$KEY" ]] || die "nothing was uploaded from '$SRC' — the directory is empty"
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
if $EPHEMERAL; then
  # Check rather than assert. GetBucketLifecycleConfiguration is AccessDenied
  # under a least-privilege Object token, and setup.sh - the only thing that
  # verifies the rule - cannot run with that token either. So on the setup this
  # skill now recommends, *nothing* has ever confirmed the rule exists, and the
  # old unconditional line promised a 7-day deletion that may never happen.
  # Content the user believed was ephemeral living forever is the failure that
  # matters here, so say which of the two situations this is.
  if "${AWSP[@]}" s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" \
       --output json 2>/dev/null \
       | jq -e '.Rules[]? | select(.ID == "expire-tmp" and .Status == "Enabled")' >/dev/null 2>&1; then
    echo "publish_result.storage_expires=~7 days (rule 'expire-tmp' verified)" >&2
  else
    echo "publish_result.storage_expires=UNVERIFIED — could not read the tmp/ lifecycle rule (expected with an Object-scoped token). Do not tell the user this auto-deletes; use --unpublish to be sure." >&2
  fi
fi
echo "publish_result.url_expires_in=${EXPIRES}s (or immediately, if the R2 token is rotated/revoked)" >&2
presign "$KEY"
