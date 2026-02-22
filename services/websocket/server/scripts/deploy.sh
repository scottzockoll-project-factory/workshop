#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Deploying WebSocket server to Fly.io..."
flyctl deploy
echo "Done."
