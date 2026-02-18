#!/usr/bin/env bash
set -euo pipefail

# Provisions auth env vars for the project.
# Required env vars: VERCEL_TOKEN, VERCEL_TEAM_ID
# Optional: JWT_SECRET, RESEND_API_KEY, ALLOWED_EMAILS, ADMIN_EMAIL

SLUG=$(basename "$(pwd)")

echo "=== Provisioning Auth for: $SLUG ==="

# --------------------------------------------------
# 1. Generate JWT_SECRET if not already set
# --------------------------------------------------
if [ -z "${JWT_SECRET:-}" ]; then
  JWT_SECRET=$(openssl rand -base64 32)
  echo "Generated new JWT_SECRET"
fi

# --------------------------------------------------
# 2. Set env vars on Vercel
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

set_vercel_env "JWT_SECRET" "$JWT_SECRET"

if [ -n "${RESEND_API_KEY:-}" ]; then
  set_vercel_env "RESEND_API_KEY" "$RESEND_API_KEY"
fi

# Always set ALLOWED_EMAILS (even if empty) to ensure whitelist updates propagate
set_vercel_env "ALLOWED_EMAILS" "${ALLOWED_EMAILS:-}"

if [ -n "${ADMIN_EMAIL:-}" ]; then
  set_vercel_env "ADMIN_EMAIL" "$ADMIN_EMAIL"
fi

echo "=== Auth provisioned for $SLUG ==="
