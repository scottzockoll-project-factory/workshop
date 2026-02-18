#!/usr/bin/env bash
set -euo pipefail

# Usage: create-project.sh <project-name> [--emails "a@x.com,b@x.com"] <service1> [service2] ...
# Example: create-project.sh my-app --emails "scott@x.com" postgres frontend auth

WORKSHOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="$1"
shift

# Parse --emails flag
ALLOWED_EMAILS=""
if [ "${1:-}" = "--emails" ]; then
  ALLOWED_EMAILS="$2"
  shift 2
fi

SERVICES=("$@")

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "Usage: $0 <project-name> [--emails \"a@x.com,b@x.com\"] <service1> [service2] ..."
  echo "Available services:"
  for dir in "$WORKSHOP_DIR"/services/*/; do
    svc=$(basename "$dir")
    desc=$(jq -r '.description' "$dir/service.json")
    echo "  $svc - $desc"
  done
  exit 1
fi

# Require --emails when auth service is selected
for svc in "${SERVICES[@]}"; do
  if [ "$svc" = "auth" ] && [ -z "$ALLOWED_EMAILS" ]; then
    echo "Error: --emails flag is required when using the auth service."
    echo "Usage: $0 <project-name> --emails \"a@x.com,b@x.com\" auth [other-services...]"
    exit 1
  fi
done

PROJECT_DIR="/tmp/$PROJECT_NAME"
GITHUB_OWNER="scottzockoll-project-factory"

echo "=== Creating project: $PROJECT_NAME ==="
echo "Services: ${SERVICES[*]}"

# --------------------------------------------------
# 1. Validate services
# --------------------------------------------------
for svc in "${SERVICES[@]}"; do
  if [ ! -f "$WORKSHOP_DIR/services/$svc/service.json" ]; then
    echo "Error: Unknown service '$svc'. Available services:"
    for dir in "$WORKSHOP_DIR"/services/*/; do
      echo "  $(basename "$dir")"
    done
    exit 1
  fi
done

# --------------------------------------------------
# 2. Create GitHub repo
# --------------------------------------------------
echo "--- Creating GitHub repo: $GITHUB_OWNER/$PROJECT_NAME ---"
if gh repo view "$GITHUB_OWNER/$PROJECT_NAME" --json url &>/dev/null; then
  echo "Repo already exists, skipping creation."
else
  gh repo create "$GITHUB_OWNER/$PROJECT_NAME" \
    --public \
    --description "$PROJECT_NAME - built with Workshop"
fi

# Set repo-level ALLOWED_EMAILS secret if provided
if [ -n "$ALLOWED_EMAILS" ]; then
  echo "--- Setting ALLOWED_EMAILS repo secret ---"
  gh secret set ALLOWED_EMAILS --repo "$GITHUB_OWNER/$PROJECT_NAME" --body "$ALLOWED_EMAILS"
fi

# Clone into temp directory
if [ -d "$PROJECT_DIR" ]; then
  rm -rf "$PROJECT_DIR"
fi
gh repo clone "$GITHUB_OWNER/$PROJECT_NAME" "$PROJECT_DIR" 2>/dev/null || \
  git clone "https://github.com/$GITHUB_OWNER/$PROJECT_NAME.git" "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize if empty repo
if [ ! -f "package.json" ]; then
  npm init -y > /dev/null
fi

# --------------------------------------------------
# 3. Copy service files into project
# --------------------------------------------------
ALL_DEPS=()
ALL_DEV_DEPS=()

for svc in "${SERVICES[@]}"; do
  SVC_DIR="$WORKSHOP_DIR/services/$svc"
  echo "--- Copying files for service: $svc ---"

  # Copy files/ directory contents into project root
  if [ -d "$SVC_DIR/files" ]; then
    cp -r "$SVC_DIR/files/"* "$PROJECT_DIR/" 2>/dev/null || true
    # Also copy hidden files
    cp -r "$SVC_DIR/files/".[!.]* "$PROJECT_DIR/" 2>/dev/null || true
  fi

  # Collect dependencies
  while IFS= read -r dep; do
    ALL_DEPS+=("$dep")
  done < <(jq -r '.dependencies[]' "$SVC_DIR/service.json" 2>/dev/null || true)

  while IFS= read -r dep; do
    ALL_DEV_DEPS+=("$dep")
  done < <(jq -r '.devDependencies[]' "$SVC_DIR/service.json" 2>/dev/null || true)
done

# Make provision scripts executable
chmod +x "$PROJECT_DIR"/scripts/*.sh 2>/dev/null || true

# Generate .gitignore
cat > "$PROJECT_DIR/.gitignore" << 'GITIGNORE'
node_modules/
.next/
.env
.env.local
.vercel
*.tsbuildinfo
next-env.d.ts
GITIGNORE

# --------------------------------------------------
# 4. Generate services.json
# --------------------------------------------------
echo "--- Generating services.json ---"
SERVICES_JSON=$(printf '%s\n' "${SERVICES[@]}" | jq -R . | jq -s '{ services: . }')
echo "$SERVICES_JSON" > "$PROJECT_DIR/services.json"

# --------------------------------------------------
# 5. Generate deploy.yml from template
# --------------------------------------------------
echo "--- Generating deploy workflow ---"
mkdir -p "$PROJECT_DIR/.github/workflows"

PROVISION_STEPS=""
DEPLOY_STEPS=""

for svc in "${SERVICES[@]}"; do
  SVC_DIR="$WORKSHOP_DIR/services/$svc"
  SVC_JSON="$SVC_DIR/service.json"

  # Build provision step
  PROVISION_SCRIPT=$(jq -r '.provisionScript' "$SVC_JSON")
  if [ "$PROVISION_SCRIPT" != "null" ]; then
    # Collect secrets needed for this service
    ENV_BLOCK=""
    while IFS= read -r secret; do
      ENV_BLOCK="$ENV_BLOCK
          $secret: \${{ secrets.$secret }}"
    done < <(jq -r '.secrets[]' "$SVC_JSON" 2>/dev/null || true)

    PROVISION_STEPS="$PROVISION_STEPS
      - name: Provision ${svc}
        run: chmod +x $PROVISION_SCRIPT && $PROVISION_SCRIPT
        env:${ENV_BLOCK}
"
  fi

  # Build deploy steps
  while IFS= read -r step; do
    # Determine env vars needed for deploy step
    DEPLOY_ENV=""
    if echo "$step" | grep -q "drizzle-kit"; then
      DEPLOY_ENV="
          DATABASE_URL: \${{ env.DATABASE_URL }}"
    fi
    if echo "$step" | grep -q "vercel"; then
      DEPLOY_ENV="
          VERCEL_TOKEN: \${{ secrets.VERCEL_TOKEN }}"
    fi

    DEPLOY_STEPS="$DEPLOY_STEPS
      - name: Deploy ${svc} - $(echo "$step" | head -c 40)
        run: $step
        env:${DEPLOY_ENV}
"
  done < <(jq -r '.deploySteps[]' "$SVC_JSON" 2>/dev/null || true)
done

# Read template and substitute
DEPLOY_YML=$(cat "$WORKSHOP_DIR/templates/deploy.yml.tmpl")
DEPLOY_YML="${DEPLOY_YML//\{\{PROVISION_STEPS\}\}/$PROVISION_STEPS}"
DEPLOY_YML="${DEPLOY_YML//\{\{DEPLOY_STEPS\}\}/$DEPLOY_STEPS}"
echo "$DEPLOY_YML" > "$PROJECT_DIR/.github/workflows/deploy.yml"

# --------------------------------------------------
# 6. Generate CLAUDE.md from template
# --------------------------------------------------
echo "--- Generating CLAUDE.md ---"

SERVICE_DOCS=""
for svc in "${SERVICES[@]}"; do
  SVC_DIR="$WORKSHOP_DIR/services/$svc"
  SVC_JSON="$SVC_DIR/service.json"

  SVC_DESC=$(jq -r '.description' "$SVC_JSON")
  SERVICE_DOCS="$SERVICE_DOCS
## $svc - $SVC_DESC
"
  # Add each doc field
  while IFS=$'\t' read -r key value; do
    SERVICE_DOCS="$SERVICE_DOCS- **${key}**: ${value}
"
  done < <(jq -r '.docs | to_entries[] | [.key, .value] | @tsv' "$SVC_JSON" 2>/dev/null || true)

  SERVICE_DOCS="$SERVICE_DOCS
"
done

CLAUDE_MD=$(cat "$WORKSHOP_DIR/templates/CLAUDE.md.tmpl")
CLAUDE_MD="${CLAUDE_MD//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
CLAUDE_MD="${CLAUDE_MD//\{\{SERVICE_DOCS\}\}/$SERVICE_DOCS}"
echo "$CLAUDE_MD" > "$PROJECT_DIR/CLAUDE.md"

# --------------------------------------------------
# 7. Install dependencies
# --------------------------------------------------
echo "--- Installing dependencies ---"
if [ ${#ALL_DEPS[@]} -gt 0 ]; then
  npm install "${ALL_DEPS[@]}"
fi
if [ ${#ALL_DEV_DEPS[@]} -gt 0 ]; then
  npm install -D "${ALL_DEV_DEPS[@]}"
fi

# --------------------------------------------------
# 8. Symlink workshop skills into project
# --------------------------------------------------
echo "--- Linking workshop skills ---"
mkdir -p "$PROJECT_DIR/.claude/skills"
for skill_dir in "$WORKSHOP_DIR"/.claude/skills/*/; do
  skill_name=$(basename "$skill_dir")
  ln -sfn "$skill_dir" "$PROJECT_DIR/.claude/skills/$skill_name"
done

# --------------------------------------------------
# 9. Commit and push
# --------------------------------------------------
echo "--- Committing and pushing ---"
cd "$PROJECT_DIR"
git add -A
git commit -m "Initial scaffold with services: ${SERVICES[*]}

Generated by Workshop create-project.sh" || echo "Nothing to commit"
git push origin main 2>/dev/null || git push origin HEAD:main

echo ""
echo "=== Project created successfully! ==="
echo "  Repo:    https://github.com/$GITHUB_OWNER/$PROJECT_NAME"
echo "  Clone:   git clone https://github.com/$GITHUB_OWNER/$PROJECT_NAME.git"
echo "  Local:   $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR (or clone the repo)"
echo "  2. Open Claude Code and start building!"
echo "  3. Push to main to trigger deploy"
