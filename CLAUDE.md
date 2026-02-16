# Workshop - Autonomous Project Factory

This repo contains the infrastructure for autonomously building and deploying web projects using Claude Code.

## How It Works

GitHub Issues describe project ideas. A scheduled GitHub Actions workflow picks up issues labeled `build`, provisions infrastructure (GitHub repo, Neon Postgres, Vercel, DNS), then uses Claude Code to write the entire application.

## For Claude Code (when building projects)

When you are invoked by `build-project.sh` to build a new application, follow these rules:

### Tech Stack
- **Language**: TypeScript (strict mode)
- **ORM**: Drizzle ORM with PostgreSQL (Neon). The `DATABASE_URL` environment variable is already set.
- **Styling**: Tailwind CSS v4
- **UI Components**: shadcn/ui
- **Framework**: As specified in the project spec (usually Next.js App Router)

### Code Quality
- Write production-quality code. No placeholder comments, no TODOs, no "implement this later".
- Implement ALL features described in the project spec. Every single one.
- Handle errors gracefully -- show user-friendly error messages, not raw stack traces.
- Use TypeScript strict mode. No `any` types unless absolutely necessary.
- Use server actions or API routes for data mutations, never client-side direct DB access.

### Database
- Define schema in `src/db/schema.ts` using Drizzle ORM.
- Create a db client in `src/db/index.ts` that reads `DATABASE_URL` from `process.env`.
- Use `drizzle-kit push` to apply schema (not migrations, for simplicity).
- Include seed data when it makes sense for the app.

### Secrets
- NEVER hardcode secrets, API keys, or database URLs.
- Always read from environment variables.

### Build Verification
- The app MUST pass `npm run build` with zero errors.
- If the build fails, fix the errors and try again.

### Project Structure (Next.js App Router)
```
src/
  app/
    layout.tsx
    page.tsx
    globals.css
  components/
    ui/          # shadcn/ui components
  db/
    schema.ts
    index.ts
  lib/
    utils.ts
```
