#!/usr/bin/env bash
set -euo pipefail

# Provisions a Neon Postgres database for the project.
# Required env vars: NEON_API_KEY, NEON_ORG_ID, VERCEL_TOKEN, VERCEL_TEAM_ID
# Reads PROJECT_NAME from services.json or falls back to directory name.

SLUG=$(basename "$(pwd)")

echo "=== Provisioning Postgres for: $SLUG ==="

# --------------------------------------------------
# 1. Create Neon database (skip if exists)
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
  DATABASE_URL=$(echo "$NEON_OUTPUT" | jq -r '.connection_uris[0].connection_uri')
fi
echo "Database URL captured (redacted): ${DATABASE_URL:0:30}..."

# --------------------------------------------------
# 2. Set DATABASE_URL on Vercel project
# --------------------------------------------------
echo "--- Setting DATABASE_URL on Vercel ---"

# Remove existing env var if present (makes this idempotent)
EXISTING_ENV_ID=$(curl -s -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v9/projects/$SLUG/env?teamId=$VERCEL_TEAM_ID" \
  | jq -r '.envs[]? | select(.key == "DATABASE_URL") | .id' | head -1)

if [ -n "$EXISTING_ENV_ID" ]; then
  curl -s -X DELETE "https://api.vercel.com/v9/projects/$SLUG/env/$EXISTING_ENV_ID?teamId=$VERCEL_TEAM_ID" \
    -H "Authorization: Bearer $VERCEL_TOKEN" > /dev/null
fi

curl -s -X POST "https://api.vercel.com/v10/projects/$SLUG/env?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"key\":\"DATABASE_URL\",\"value\":\"$DATABASE_URL\",\"type\":\"encrypted\",\"target\":[\"production\",\"preview\",\"development\"]}" > /dev/null

# Export for later steps in CI
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "DATABASE_URL=$DATABASE_URL" >> "$GITHUB_ENV"
fi

echo "=== Postgres provisioned for $SLUG ==="
