#!/usr/bin/env bash
set -euo pipefail

# Provisions an S3 bucket for the project.
# Required env vars: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, VERCEL_TOKEN, VERCEL_TEAM_ID
# Optional: AWS_REGION (default: us-east-1)

SLUG=$(basename "$(pwd)")
BUCKET_NAME="scottzockoll-${SLUG}"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Provisioning Storage for: $SLUG ==="
echo "--- Bucket: $BUCKET_NAME in $REGION ---"

# --------------------------------------------------
# 1. Create S3 bucket (idempotent — ignore AlreadyOwnedByYou)
# --------------------------------------------------
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" 2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
fi

echo "Bucket $BUCKET_NAME exists (created or already owned)"

# --------------------------------------------------
# 2. Bucket stays private — block all public access
# --------------------------------------------------
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Public access blocked on $BUCKET_NAME"

# --------------------------------------------------
# 3. Set CORS policy
# --------------------------------------------------
aws s3api put-bucket-cors \
  --bucket "$BUCKET_NAME" \
  --cors-configuration "{
    \"CORSRules\": [
      {
        \"AllowedOrigins\": [
          \"https://${SLUG}.scottzockoll.com\",
          \"http://localhost:3000\",
          \"https://*.vercel.app\"
        ],
        \"AllowedMethods\": [\"PUT\", \"GET\", \"HEAD\"],
        \"AllowedHeaders\": [\"*\"],
        \"MaxAgeSeconds\": 3000
      }
    ]
  }"

echo "CORS configured on $BUCKET_NAME"

# --------------------------------------------------
# 4. Set env vars on Vercel
# --------------------------------------------------
set_vercel_env() {
  local KEY="$1"
  local VALUE="$2"

  # Remove existing env var if present
  EXISTING_ENV_ID=$(curl -s -H "Authorization: Bearer $VERCEL_TOKEN" \
    "https://api.vercel.com/v9/projects/$SLUG/env?teamId=$VERCEL_TEAM_ID" \
    | jq -r ".envs[]? | select(.key == \"$KEY\") | .id" | head -1)

  if [ -n "$EXISTING_ENV_ID" ]; then
    curl -s -X DELETE "https://api.vercel.com/v9/projects/$SLUG/env/$EXISTING_ENV_ID?teamId=$VERCEL_TEAM_ID" \
      -H "Authorization: Bearer $VERCEL_TOKEN" > /dev/null
  fi

  curl -s -X POST "https://api.vercel.com/v10/projects/$SLUG/env?teamId=$VERCEL_TEAM_ID" \
    -H "Authorization: Bearer $VERCEL_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\",\"value\":\"$VALUE\",\"type\":\"encrypted\",\"target\":[\"production\",\"preview\",\"development\"]}" > /dev/null

  echo "Set $KEY on Vercel"
}

set_vercel_env "S3_BUCKET_NAME" "$BUCKET_NAME"
set_vercel_env "S3_REGION" "$REGION"
set_vercel_env "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
set_vercel_env "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"

echo "=== Storage provisioned for $SLUG ==="
