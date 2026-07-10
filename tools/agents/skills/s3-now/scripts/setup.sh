#!/usr/bin/env bash
# One-time (idempotent) setup for the s3-now skill.
# Creates a fully private S3 bucket (no public access, no CloudFront).
# Access is gated by AWS SSO; sharing happens via pre-signed URLs.
# Writes config to ~/.s3now/config.json.
set -euo pipefail

PROFILE="${S3NOW_PROFILE:-alyssa-scratch}"
REGION="${S3NOW_REGION:-us-east-1}"
CONFIG_DIR="$HOME/.s3now"
CONFIG="$CONFIG_DIR/config.json"

die() { echo "error: $1" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done

need_cmd aws
need_cmd jq

AWSP=(aws --profile "$PROFILE" --region "$REGION" --output json)

if ! IDENTITY="$("${AWSP[@]}" sts get-caller-identity 2>/dev/null)"; then
  die "not authenticated. Run: aws sso login --profile $PROFILE"
fi
ACCOUNT_ID="$(jq -r .Account <<<"$IDENTITY")"
BUCKET="s3now-${ACCOUNT_ID}"
echo "account: $ACCOUNT_ID  profile: $PROFILE  region: $REGION" >&2

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
  if [[ "$REGION" == "us-east-1" ]]; then
    "${AWSP[@]}" s3api create-bucket --bucket "$BUCKET" >/dev/null
  else
    "${AWSP[@]}" s3api create-bucket --bucket "$BUCKET" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
fi

"${AWSP[@]}" s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" >/dev/null

"${AWSP[@]}" s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-tmp",
      "Status": "Enabled",
      "Filter": {"Prefix": "tmp/"},
      "Expiration": {"Days": 7}
    }]
  }' >/dev/null

mkdir -p "$CONFIG_DIR"
jq -n \
  --arg profile "$PROFILE" --arg region "$REGION" --arg bucket "$BUCKET" \
  '{profile: $profile, region: $region, bucket: $bucket}' \
  > "$CONFIG"
chmod 600 "$CONFIG"

echo "config written to $CONFIG" >&2
echo "bucket ready: s3://$BUCKET (private; tmp/ prefix expires after 7 days)"
