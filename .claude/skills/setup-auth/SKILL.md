---
auto_invoke:
  description: "Setting up authentication, login, user auth, email whitelist, or SSO"
---

# Set Up Auth (JWT + Email Whitelist + Sessions)

Add authentication with email magic links, per-app whitelists, and cross-subdomain SSO to the current project.

**Requires the postgres service.** If postgres is not set up, set it up first using the setup-postgres skill.

## Steps

1. **Verify postgres is set up.** Check `services.json` for `"postgres"`. If not present, set up postgres first.

2. Copy all files from `/Users/scottzockoll/projects/workshop/services/auth/files/` into the project root, preserving directory structure:
   - `src/db/schema-auth.ts` — Sessions table schema
   - `src/lib/auth.ts` — Auth utilities (createSession, verifyAuth, requireAuth, etc.)
   - `src/app/login/page.tsx` — Login page with email input
   - `src/app/api/auth/login/route.ts` — Magic link email sender
   - `src/app/api/auth/verify/route.ts` — Magic link verification + session creation
   - `src/app/api/auth/logout/route.ts` — Logout + session deletion
   - `middleware.ts` — Auth middleware (goes in project root)
   - `scripts/provision-auth.sh` — Provisioning script

3. Install dependencies:
   ```bash
   npm install jose resend
   ```

4. Import the sessions table in the project's main schema file. Add this to `src/db/schema.ts`:
   ```typescript
   export { sessions } from "./schema-auth";
   ```

5. Add env vars to `.env.local` (create if it doesn't exist):
   ```
   JWT_SECRET=<generate a random string: node -e "console.log(require('crypto').randomBytes(32).toString('base64'))">
   ALLOWED_EMAILS=user@example.com
   RESEND_API_KEY=re_xxxxxxxxxxxx
   ADMIN_EMAIL=admin@example.com
   ```

6. Update `services.json` to include `"auth"` in the services array.

7. Push the sessions table to the database:
   ```bash
   npx drizzle-kit push
   ```

8. Tell the user:
   - Set `ALLOWED_EMAILS` to a comma-separated list of authorized emails
   - Get a Resend API key at https://resend.com and set `RESEND_API_KEY`
   - Set `ADMIN_EMAIL` to receive new login notifications
   - Use `import { requireAuth } from '@/lib/auth'` in API routes and server actions
   - Sessions can be revoked by deleting the row in the Neon console
   - The auth cookie is set on `.scottzockoll.com` so all subdomain apps share authentication
