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
git clone "https://x-access-token:${GH_TOKEN}@github.com/scottzockoll/$SLUG.git" "/tmp/$SLUG"
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

# Determine Vercel framework preset
case "$FRAMEWORK" in
  "Next.js (App Router)"|"Next.js (Pages Router)") VERCEL_FRAMEWORK="nextjs" ;;
  "Vite + React") VERCEL_FRAMEWORK="vite" ;;
  "Astro") VERCEL_FRAMEWORK="astro" ;;
  *) VERCEL_FRAMEWORK="nextjs" ;;
esac

# Create Vercel project via API with framework (idempotent -- 409 if exists)
curl -s -X POST "https://api.vercel.com/v10/projects?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$SLUG\",\"framework\":\"$VERCEL_FRAMEWORK\"}" || true

# Ensure framework is set (in case project already existed)
curl -s -X PATCH "https://api.vercel.com/v9/projects/$SLUG?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"framework\":\"$VERCEL_FRAMEWORK\"}" > /dev/null

# Get project ID
VERCEL_PROJECT_ID=$(curl -s -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v9/projects/$SLUG?teamId=$VERCEL_TEAM_ID" \
  | jq -r '.id')
echo "Vercel project ID: $VERCEL_PROJECT_ID"

# Create .vercel link manually
mkdir -p .vercel
echo "{\"orgId\":\"$VERCEL_TEAM_ID\",\"projectId\":\"$VERCEL_PROJECT_ID\"}" > .vercel/project.json

# Set environment variables for all environments (remove first to make idempotent)
for ENV in production preview development; do
  vercel env rm DATABASE_URL "$ENV" --yes --token "$VERCEL_TOKEN" 2>/dev/null || true
  echo "$DATABASE_URL" | vercel env add DATABASE_URL "$ENV" --token "$VERCEL_TOKEN"
done

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

# Export DATABASE_URL for later steps
echo "DATABASE_URL=$DATABASE_URL" >> "$GITHUB_ENV"

echo "=== Infrastructure provisioned for $SLUG ==="
echo "  Repo:     https://github.com/scottzockoll/$SLUG"
echo "  DB:       Neon project '$SLUG'"
echo "  Vercel:   Project linked"
echo "  DNS:      ${SLUG}.scottzockoll.com → cname.vercel-dns.com"
