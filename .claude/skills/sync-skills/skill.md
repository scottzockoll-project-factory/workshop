---
user_invocable: true
---

# Sync Skills

Symlink all workshop skills into the current repo so they're available in Claude sessions for that project.

## Steps

1. Run the following using Bash, replacing the current working directory as the target repo:
   ```bash
   mkdir -p .claude/skills
   for skill in /Users/scottzockoll/projects/workshop/.claude/skills/*/; do
     ln -sfn "$skill" ".claude/skills/$(basename "$skill")"
   done
   ```

2. Confirm to the user which skills were linked.
