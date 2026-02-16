#!/usr/bin/env bash
set -euo pipefail

SLUG="$1"
PROJECT_NAME="$2"
FRAMEWORK="$3"

echo "=== Provisioning infrastructure for: $SLUG ==="

# --------------------------------------------------
# 1. Create GitHub repo (skip if exists)
# --------------------------------------------------
echo "--- Creating GitHub repo: scottzockoll/$SLUG ---"
if gh repo view "scottzockoll/$SLUG" --json url &>/dev/null; then
  echo "Repo already exists, skipping creation."
else
  gh repo create "scottzockoll/$SLUG" \
    --public \
    --description "$PROJECT_NAME - built by Workshop"
fi

if [ -d "/tmp/$SLUG" ]; then
  rm -rf "/tmp/$SLUG"
fi
git clone "https://github.com/scottzockoll/$SLUG.git" "/tmp/$SLUG"
cd "/tmp/$SLUG"

# --------------------------------------------------
# 2. Create Neon database (skip if exists)
# --------------------------------------------------
echo "--- Creating Neon database: $SLUG ---"
EXISTING_PROJECT=$(neonctl projects list --org-id "$NEON_ORG_ID" --output json \
  | jq -r ".[] | select(.name == \"$SLUG\") | .id" 2>/dev/null || true)

if [ -n "$EXISTING_PROJECT" ]; then
  echo "Neon project '$SLUG' already exists (id: $EXISTING_PROJECT), fetching connection string."
  DATABASE_URL=$(neonctl connection-string --project-id "$EXISTING_PROJECT" --org-id "$NEON_ORG_ID")
else
  NEON_OUTPUT=$(neonctl projects create \
    --name "$SLUG" \
    --org-id "$NEON_ORG_ID" \
    --output json)
  DATABASE_URL=$(echo "$NEON_OUTPUT" | jq -r '.connection_uri')
fi
echo "Database URL captured (redacted): ${DATABASE_URL:0:30}..."

# --------------------------------------------------
# 3. Create Vercel project and set env vars
# --------------------------------------------------
echo "--- Creating Vercel project: $SLUG ---"

# Initialize a minimal project so Vercel can link
echo '{}' > package.json
vercel link --yes --project "$SLUG" --token "$VERCEL_TOKEN"

# Set environment variables (remove first to make idempotent)
vercel env rm DATABASE_URL production --yes --token "$VERCEL_TOKEN" 2>/dev/null || true
echo "$DATABASE_URL" | vercel env add DATABASE_URL production --token "$VERCEL_TOKEN"

# Set custom domain
vercel domains add "${SLUG}.scottzockoll.com" --token "$VERCEL_TOKEN" 2>/dev/null || true

# --------------------------------------------------
# 4. Create Route53 DNS record (UPSERT is already idempotent)
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

echo "=== Infrastructure provisioned for $SLUG ==="
echo "  Repo:     https://github.com/scottzockoll/$SLUG"
echo "  DB:       Neon project '$SLUG'"
echo "  Vercel:   Project linked"
echo "  DNS:      ${SLUG}.scottzockoll.com → cname.vercel-dns.com"
