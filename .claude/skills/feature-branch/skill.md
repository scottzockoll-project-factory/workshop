---
user_invocable: true
---

# Feature Branch

Create a new feature branch from the latest main.

## Steps

1. If no branch name was provided as an argument, use AskUserQuestion to ask for the feature branch name.

2. Run the following commands using Bash:
   ```bash
   git fetch origin main && git checkout main && git pull origin main && git checkout -b <branch-name>
   ```

3. Confirm to the user that the branch was created and they are now on it.
