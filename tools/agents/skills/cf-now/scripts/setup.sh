#!/usr/bin/env bash
# One-time (idempotent) setup for the cf-now skill.
# Creates a fully private Cloudflare R2 bucket (no r2.dev URL, no custom domain).
# R2 speaks the S3 API, so this drives it with the AWS CLI pointed at the R2
# endpoint. Access is gated by an R2 API token; sharing happens via pre-signed
# URLs. Writes config to ~/.cfnow/config.json.
set -euo pipefail

# AWS CLI v2's newer default request checksums trip R2 uploads (400 /
# XAmzContentSHA256Mismatch); only send them when the API requires it.
export AWS_REQUEST_CHECKSUM_CALCULATION="${AWS_REQUEST_CHECKSUM_CALCULATION:-when_required}"
export AWS_RESPONSE_CHECKSUM_VALIDATION="${AWS_RESPONSE_CHECKSUM_VALIDATION:-when_required}"

PROFILE="${CFNOW_PROFILE:-alyssa-r2}"
REGION="auto"                       # R2 always uses the 'auto' region
ACCOUNT_ID="${CF_ACCOUNT_ID:-}"
BUCKET="${CFNOW_BUCKET:-cf-now}"
CONFIG_DIR="$HOME/.cfnow"
CONFIG="$CONFIG_DIR/config.json"

die() { echo "error: $1" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)    PROFILE="$2";    shift 2 ;;
    --account-id) ACCOUNT_ID="$2"; shift 2 ;;
    --bucket)     BUCKET="$2";     shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done

need_cmd aws
need_cmd jq

[[ -n "$ACCOUNT_ID" ]] || die "no account id — pass --account-id or set CF_ACCOUNT_ID (Cloudflare dashboard → R2)"
ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

AWSP=(aws --profile "$PROFILE" --region "$REGION" --endpoint-url "$ENDPOINT" --output json)

# R2 has no STS; a ListBuckets call is the cheapest auth probe. Account-level
# on purpose here, unlike publish.sh's bucket-scoped probe: this script creates
# the bucket and writes its lifecycle rule, so it needs Admin Read & Write
# regardless, and a token with that can list buckets. Probing account-level
# also fails early with a clear message instead of dying at create-bucket.
if ! "${AWSP[@]}" s3api list-buckets >/dev/null 2>&1; then
  die "not authenticated, or the token lacks Admin Read & Write (needed to create the bucket and set its lifecycle rule). To run with an Object-scoped token instead, create the bucket and its tmp/ rule in the dashboard and skip this script — see SKILL.md → Authentication"
fi
echo "account: $ACCOUNT_ID  profile: $PROFILE  region: $REGION  endpoint: $ENDPOINT" >&2

if [[ -f "$CONFIG" ]]; then
  EXISTING="$(jq -r '.bucket // empty' "$CONFIG")"
  if [[ -n "$EXISTING" ]] && "${AWSP[@]}" s3api head-bucket --bucket "$EXISTING" 2>/dev/null; then
    echo "already set up:" >&2
    cat "$CONFIG"
    exit 0
  fi
fi

if ! "${AWSP[@]}" s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "creating bucket $BUCKET" >&2
  # R2 CreateBucket takes no LocationConstraint (region is always 'auto').
  "${AWSP[@]}" s3api create-bucket --bucket "$BUCKET" >/dev/null
fi

# R2 buckets are private by default — no public-access-block API and no ACLs.
# Privacy comes from simply never attaching an r2.dev URL or custom domain.

"${AWSP[@]}" s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-tmp",
      "Status": "Enabled",
      "Filter": {"Prefix": "tmp/"},
      "Expiration": {"Days": 7}
    }]
  }' >/dev/null

# Read the rule back and hard-fail if it didn't take. Without this, a payload
# R2 doesn't accept could no-op silently, making "ephemeral by default" a lie —
# every upload would then live forever. Verifying here turns that into a loud
# setup-time error instead of a surprise weeks later.
if ! "${AWSP[@]}" s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" \
     --output json 2>/dev/null \
     | jq -e '.Rules[]? | select(.ID == "expire-tmp" and .Status == "Enabled")' >/dev/null; then
  die "lifecycle rule 'expire-tmp' did not apply — R2 rejected or ignored the payload. \
'Ephemeral by default' cannot be guaranteed; refusing to write config. \
Check the PutBucketLifecycleConfiguration format against the current R2 S3 API."
fi
echo "lifecycle verified: tmp/ prefix expires after 7 days" >&2

mkdir -p "$CONFIG_DIR"
jq -n \
  --arg profile "$PROFILE" --arg region "$REGION" --arg bucket "$BUCKET" \
  --arg account "$ACCOUNT_ID" --arg endpoint "$ENDPOINT" \
  '{profile: $profile, region: $region, bucket: $bucket, accountId: $account, endpoint: $endpoint}' \
  > "$CONFIG"
chmod 600 "$CONFIG"

echo "config written to $CONFIG" >&2
echo "bucket ready: r2://$BUCKET (private; tmp/ prefix expires after 7 days)"
