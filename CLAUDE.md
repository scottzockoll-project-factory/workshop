# Workshop - Service Registry & Project Scaffolder

This repo contains reusable **services** (postgres, frontend, etc.) and a scaffolder script that creates new GitHub repos with the selected services attached.

## Creating a New Project

Run the scaffolder with the project name and desired services:

```bash
scripts/create-project.sh <project-name> <service1> [service2] ...
```

Example:
```bash
scripts/create-project.sh my-app postgres frontend
```

This will:
1. Create GitHub repo `scottzockoll-project-factory/<project-name>`
2. Copy service files (provision scripts, code patterns) into the new repo
3. Generate a `deploy.yml` workflow, `services.json`, and `CLAUDE.md`
4. Install dependencies, commit, and push

After creation, clone the repo and build with Claude locally. On push to main, the deploy workflow provisions infrastructure and deploys.

## Available Services

### postgres
Neon Postgres database with Drizzle ORM. Provides:
- `src/db/index.ts` — Drizzle client
- `src/db/schema.ts` — Base schema
- `drizzle.config.ts` — Drizzle Kit config
- `scripts/provision-postgres.sh` — Creates Neon project, sets DATABASE_URL on Vercel

### frontend
Vercel frontend hosting with custom domain. Provides:
- `scripts/provision-frontend.sh` — Creates Vercel project, sets up DNS at `<slug>.scottzockoll.com`

## Adding a New Service

1. Create `services/<name>/service.json` with metadata (dependencies, secrets, docs, etc.)
2. Create `services/<name>/files/` with files to copy into new projects
3. The scaffolder will automatically pick it up

## Repo Structure

```
workshop/
  services/
    postgres/
      service.json
      files/          # Copied into new projects
    frontend/
      service.json
      files/
  scripts/
    create-project.sh # The scaffolder
  templates/
    deploy.yml.tmpl   # Deploy workflow template
    CLAUDE.md.tmpl    # Project CLAUDE.md template
```
