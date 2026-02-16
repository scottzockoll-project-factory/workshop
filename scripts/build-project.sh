#!/usr/bin/env bash
set -euo pipefail

SLUG="$1"
PROJECT_NAME="$2"
FRAMEWORK="$3"
DESCRIPTION="$4"
DATA_MODEL="${5:-}"
EXTRA_INSTRUCTIONS="${6:-}"

PROJECT_DIR="/tmp/$SLUG"
cd "$PROJECT_DIR"

echo "=== Building project: $PROJECT_NAME ($SLUG) ==="

# --------------------------------------------------
# Build the prompt
# --------------------------------------------------
PROMPT="You are building a new web application called \"$PROJECT_NAME\".

## Framework
Use: $FRAMEWORK

## Project Description
$DESCRIPTION"

if [ -n "$DATA_MODEL" ] && [ "$DATA_MODEL" != "_No response_" ]; then
  PROMPT="$PROMPT

## Data Model
$DATA_MODEL"
fi

if [ -n "$EXTRA_INSTRUCTIONS" ] && [ "$EXTRA_INSTRUCTIONS" != "_No response_" ]; then
  PROMPT="$PROMPT

## Extra Instructions
$EXTRA_INSTRUCTIONS"
fi

PROMPT="$PROMPT

## Your Task
1. Initialize the project with the correct framework and package manager (use npm).
2. Install all dependencies (Drizzle ORM, Tailwind CSS, shadcn/ui, and any others needed).
3. Implement the COMPLETE application with ALL features described above.
4. Set up the database schema using Drizzle ORM. The DATABASE_URL env var is already set.
5. Make sure the app is production-ready with proper error handling.
6. Run 'npm run build' to verify everything compiles.

IMPORTANT: Build the ENTIRE app. Do not leave placeholder or TODO comments. Every feature described must be fully implemented."

# --------------------------------------------------
# Run Claude Code
# --------------------------------------------------
echo "--- Running Claude Code ---"
claude -p "$PROMPT" \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-turns 100 \
  --model claude-sonnet-4-5-20250929

# --------------------------------------------------
# Verify build
# --------------------------------------------------
echo "--- Verifying build ---"
if ! npm run build; then
  echo "Build failed. Re-invoking Claude to fix..."
  claude -p "The build failed. Run 'npm run build', read the errors, and fix them. Keep fixing until the build passes." \
    --allowedTools "Bash,Read,Write,Edit" \
    --max-turns 30 \
    --model claude-sonnet-4-5-20250929 \
    --continue

  # Final verification
  npm run build
fi

echo "=== Build complete for $SLUG ==="
