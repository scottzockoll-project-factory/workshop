#!/usr/bin/env bash
set -euo pipefail

# Provisions a Neon Postgres database for the project.
# Required env vars: NEON_API_KEY, NEON_ORG_ID, VERCEL_TOKEN, VERCEL_TEAM_ID

SLUG=$(basename "$(pwd)")
NEON_API="https://console.neon.tech/api/v2"

echo "=== Provisioning Postgres for: $SLUG ==="

# --------------------------------------------------
# 1. Create Neon project (idempotent)
# --------------------------------------------------
echo "--- Creating Neon database: $SLUG ---"

EXISTING_PROJECT_ID=$(curl -s \
  -H "Authorization: Bearer $NEON_API_KEY" \
  "$NEON_API/projects?org_id=$NEON_ORG_ID&limit=100" \
  | jq -r ".projects[]? | select(.name == \"$SLUG\") | .id" | head -1 || true)

if [ -n "$EXISTING_PROJECT_ID" ]; then
  echo "Neon project '$SLUG' already exists (id: $EXISTING_PROJECT_ID)"
  PROJECT_ID="$EXISTING_PROJECT_ID"
else
  echo "Creating new Neon project: $SLUG"
  PROJECT_ID=$(curl -s -X POST "$NEON_API/projects" \
    -H "Authorization: Bearer $NEON_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"project\":{\"name\":\"$SLUG\",\"org_id\":\"$NEON_ORG_ID\"}}" \
    | jq -r '.project.id')
  echo "Created Neon project: $PROJECT_ID"
fi

# --------------------------------------------------
# 2. Get connection string
# --------------------------------------------------
BRANCH_ID=$(curl -s \
  -H "Authorization: Bearer $NEON_API_KEY" \
  "$NEON_API/projects/$PROJECT_ID/branches" \
  | jq -r '.branches[] | select(.default == true) | .id')

DATABASE_URL=$(curl -s \
  -H "Authorization: Bearer $NEON_API_KEY" \
  "$NEON_API/projects/$PROJECT_ID/connection_uri?branch_id=$BRANCH_ID&database_name=neondb&role_name=neondb_owner&pooled=true" \
  | jq -r '.uri')

echo "Database URL captured (redacted): ${DATABASE_URL:0:30}..."

# --------------------------------------------------
# 3. Set DATABASE_URL on Vercel project
# --------------------------------------------------
echo "--- Setting DATABASE_URL on Vercel ---"

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
