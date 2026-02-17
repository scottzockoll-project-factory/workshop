---
auto_invoke:
  description: "Setting up Vercel hosting, frontend deployment, or custom domain"
---

# Set Up Frontend (Vercel + Custom Domain)

Add Vercel frontend hosting with a custom domain to the current project.

## Steps

1. Copy `scripts/provision-frontend.sh` from `/Users/scottzockoll/projects/workshop/services/frontend/files/scripts/provision-frontend.sh` into the project at `scripts/provision-frontend.sh`. Create the `scripts/` directory if needed.

2. Update or create `services.json` in the project root. If it exists, add `"frontend"` to the array. If not, create it with `["frontend"]`.

3. Tell the user:
   - On push to main, the deploy workflow creates a Vercel project and sets up DNS at `<slug>.scottzockoll.com`
   - Vercel auto-detects the framework (Next.js, Vite, Astro, etc.)
   - The `provision-frontend.sh` script handles Vercel project creation, domain assignment, and Route53 DNS records
