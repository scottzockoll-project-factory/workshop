---
user_invocable: true
---

# Update App Email Whitelist

Update the ALLOWED_EMAILS whitelist for a project in the `scottzockoll-project-factory` GitHub org, then redeploy to apply the change.

## Arguments

The user should provide:
- **app name** — the repo name (e.g. `test`, `goofenet`)
- **action** — what to change (e.g. "add scott@x.com", "set to scott@x.com,bob@x.com", "clear it")

## Steps

1. **GitHub secrets can't be read**, so ask the user what the current whitelist is if you need it (e.g. when adding/removing a single email). If the user is setting the full list or clearing it, you don't need to ask.

2. **Set the secret** using:
   ```bash
   gh secret set ALLOWED_EMAILS --repo scottzockoll-project-factory/<app-name> --body "<comma-separated-emails>"
   ```
   To clear the whitelist, set it to an empty string (`--body ""`).

3. **Redeploy the app** by pushing an empty commit to trigger the deploy workflow:
   ```bash
   cd /tmp && rm -rf <app-name>-redeploy && gh repo clone scottzockoll-project-factory/<app-name> <app-name>-redeploy && cd <app-name>-redeploy && git commit --allow-empty -m "Redeploy with updated whitelist" && git push origin main
   ```

4. **Confirm** to the user what the whitelist is now set to and that a redeploy has been triggered.
