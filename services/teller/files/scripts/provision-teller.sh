#!/usr/bin/env bash
set -euo pipefail

# Provisions Teller env vars on Vercel.
# Requires: TELLER_CERT, TELLER_PRIVATE_KEY, NEXT_PUBLIC_TELLER_APPLICATION_ID, VERCEL_TOKEN, VERCEL_TEAM_ID
# TELLER_CERT and TELLER_PRIVATE_KEY should be base64-encoded contents of certificate.pem and private_key.pem

VERCEL_PROJECT_NAME="${VERCEL_PROJECT_NAME:-$PROJECT_NAME}"

required_vars=(TELLER_CERT TELLER_PRIVATE_KEY NEXT_PUBLIC_TELLER_APPLICATION_ID VERCEL_TOKEN VERCEL_TEAM_ID VERCEL_PROJECT_NAME)
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set"
    exit 1
  fi
done

TELLER_ENV="${NEXT_PUBLIC_TELLER_ENV:-sandbox}"

echo "--- Setting Teller env vars on Vercel project: $VERCEL_PROJECT_NAME ---"

set_vercel_env() {
  local key="$1"
  local value="$2"
  echo "$value" | vercel env add "$key" production --token "$VERCEL_TOKEN" --scope "$VERCEL_TEAM_ID" --yes 2>/dev/null || \
  vercel env rm "$key" production --token "$VERCEL_TOKEN" --scope "$VERCEL_TEAM_ID" --yes 2>/dev/null && \
  echo "$value" | vercel env add "$key" production --token "$VERCEL_TOKEN" --scope "$VERCEL_TEAM_ID" --yes
}

set_vercel_env "TELLER_CERT" "$TELLER_CERT"
set_vercel_env "TELLER_PRIVATE_KEY" "$TELLER_PRIVATE_KEY"
set_vercel_env "NEXT_PUBLIC_TELLER_APPLICATION_ID" "$NEXT_PUBLIC_TELLER_APPLICATION_ID"
set_vercel_env "NEXT_PUBLIC_TELLER_ENV" "$TELLER_ENV"

echo "--- Teller provisioning complete ---"
