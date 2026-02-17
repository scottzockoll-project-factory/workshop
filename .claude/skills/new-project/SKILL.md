---
user_invocable: true
auto_invoke:
  description: "Creating a new project, scaffolding a new app"
---

# Create a New Project

Scaffold a new GitHub repo with selected services using the workshop scaffolder.

## Steps

1. Ask the user for:
   - **Project name** (lowercase, hyphenated, e.g. `my-app`)
   - **Services** to include. Available services:
     - `postgres` — Neon Postgres database with Drizzle ORM
     - `frontend` — Vercel hosting with custom domain at `<slug>.scottzockoll.com`

2. Run the scaffolder from the workshop repo:
   ```bash
   /Users/scottzockoll/projects/workshop/scripts/create-project.sh <project-name> <service1> [service2] ...
   ```

3. Report the result to the user:
   - GitHub repo URL: `https://github.com/scottzockoll-project-factory/<project-name>`
   - Clone command: `git clone git@github.com:scottzockoll-project-factory/<project-name>.git`
   - Next steps: `cd <project-name>` and start building with Claude
   - On push to main, the deploy workflow provisions infrastructure and deploys
