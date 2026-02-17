---
auto_invoke:
  description: "Setting up a Postgres database, adding a database, or using Drizzle ORM"
---

# Set Up Postgres (Neon + Drizzle ORM)

Add a Neon Postgres database with Drizzle ORM to the current project.

## Steps

1. Copy all files from `/Users/scottzockoll/projects/workshop/services/postgres/files/` into the project root, preserving directory structure:
   - `src/db/index.ts` — Drizzle client
   - `src/db/schema.ts` — Base schema with example table
   - `drizzle.config.ts` — Drizzle Kit config
   - `scripts/provision-postgres.sh` — Provisioning script

2. Install dependencies:
   ```bash
   npm install drizzle-orm @neondatabase/serverless
   npm install -D drizzle-kit
   ```

3. Add a `DATABASE_URL` placeholder to `.env.local` (create the file if it doesn't exist):
   ```
   DATABASE_URL=postgresql://user:password@host/dbname?sslmode=require
   ```

4. Update or create `services.json` in the project root. If it exists, add `"postgres"` to the array. If not, create it with `["postgres"]`.

5. Tell the user:
   - Customize the example schema in `src/db/schema.ts`
   - Import the db client with `import { db } from '@/db'`
   - Import tables with `import { myTable } from '@/db/schema'`
   - Run `npx drizzle-kit push` to apply schema changes
   - On deploy, `provision-postgres.sh` creates the Neon project and sets `DATABASE_URL` on Vercel
