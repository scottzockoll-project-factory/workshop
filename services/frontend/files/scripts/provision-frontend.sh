#!/usr/bin/env bash
set -euo pipefail

# Provisions a Vercel project with custom domain and DNS.
# Required env vars: VERCEL_TOKEN, VERCEL_TEAM_ID, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ROUTE53_HOSTED_ZONE_ID

SLUG=$(basename "$(pwd)")
FRAMEWORK="${VERCEL_FRAMEWORK:-nextjs}"

echo "=== Provisioning Frontend for: $SLUG ==="

# --------------------------------------------------
# 1. Create Vercel project (idempotent -- 409 if exists)
# --------------------------------------------------
echo "--- Creating Vercel project: $SLUG ---"
curl -s -X POST "https://api.vercel.com/v10/projects?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$SLUG\",\"framework\":\"$FRAMEWORK\"}" > /dev/null 2>&1 || true

# Ensure framework is set (in case project already existed)
curl -s -X PATCH "https://api.vercel.com/v9/projects/$SLUG?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"framework\":\"$FRAMEWORK\"}" > /dev/null

# --------------------------------------------------
# 2. Get project ID and create .vercel link
# --------------------------------------------------
VERCEL_PROJECT_ID=$(curl -s -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v9/projects/$SLUG?teamId=$VERCEL_TEAM_ID" \
  | jq -r '.id')
echo "Vercel project ID: $VERCEL_PROJECT_ID"

mkdir -p .vercel
echo "{\"orgId\":\"$VERCEL_TEAM_ID\",\"projectId\":\"$VERCEL_PROJECT_ID\"}" > .vercel/project.json

# --------------------------------------------------
# 3. Set custom domain
# --------------------------------------------------
echo "--- Setting custom domain: ${SLUG}.scottzockoll.com ---"
curl -s -X POST "https://api.vercel.com/v10/projects/$SLUG/domains?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${SLUG}.scottzockoll.com\"}" > /dev/null 2>&1 || true

# --------------------------------------------------
# 4. Create Route53 DNS record (UPSERT is idempotent)
# --------------------------------------------------
echo "--- Creating DNS record: ${SLUG}.scottzockoll.com ---"
aws route53 change-resource-record-sets \
  --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"${SLUG}.scottzockoll.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"cname.vercel-dns.com\"}]
      }
    }]
  }"

echo "=== Frontend provisioned for $SLUG ==="
echo "  Domain: ${SLUG}.scottzockoll.com"
