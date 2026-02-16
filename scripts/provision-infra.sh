#!/usr/bin/env bash
set -euo pipefail

SLUG="$1"
PROJECT_NAME="$2"
FRAMEWORK="$3"

echo "=== Provisioning infrastructure for: $SLUG ==="

# --------------------------------------------------
# 1. Create GitHub repo
# --------------------------------------------------
echo "--- Creating GitHub repo: scottzockoll/$SLUG ---"
gh repo create "scottzockoll/$SLUG" \
  --public \
  --description "$PROJECT_NAME - built by Workshop"

git clone "https://github.com/scottzockoll/$SLUG.git" "/tmp/$SLUG"
cd "/tmp/$SLUG"

# --------------------------------------------------
# 2. Create Neon database
# --------------------------------------------------
echo "--- Creating Neon database: $SLUG ---"
NEON_OUTPUT=$(neonctl projects create \
  --name "$SLUG" \
  --output json)

DATABASE_URL=$(echo "$NEON_OUTPUT" | jq -r '.connection_uri')
echo "Database URL captured (redacted): ${DATABASE_URL:0:30}..."

# --------------------------------------------------
# 3. Create Vercel project and set env vars
# --------------------------------------------------
echo "--- Creating Vercel project: $SLUG ---"

# Determine framework preset for Vercel
case "$FRAMEWORK" in
  "Next.js (App Router)"|"Next.js (Pages Router)")
    VERCEL_FRAMEWORK="nextjs"
    ;;
  "Vite + React")
    VERCEL_FRAMEWORK="vite"
    ;;
  "Astro")
    VERCEL_FRAMEWORK="astro"
    ;;
  *)
    VERCEL_FRAMEWORK="nextjs"
    ;;
esac

# Initialize a minimal project so Vercel can link
echo '{}' > package.json
vercel link --yes --project "$SLUG" --token "$VERCEL_TOKEN"

# Set environment variables
echo "$DATABASE_URL" | vercel env add DATABASE_URL production --token "$VERCEL_TOKEN"

# Set custom domain
vercel domains add "${SLUG}.scottzockoll.com" --token "$VERCEL_TOKEN" || true

# --------------------------------------------------
# 4. Create Route53 DNS record
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
echo "  DB:       Neon project '$SLUG' created"
echo "  Vercel:   Project linked"
echo "  DNS:      ${SLUG}.scottzockoll.com → cname.vercel-dns.com"
