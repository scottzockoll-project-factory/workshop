---
user_invocable: true
---

# Toggle API Key Mode

Show the user their current Claude Code billing mode and how to switch.

## Steps

1. Use the Bash tool to run `printenv ANTHROPIC_API_KEY` to check if an API key is currently set.
2. Tell the user their current mode:
   - If the command printed a key value, they are in **API key mode** (billed to their Anthropic API account).
   - If the command printed nothing or errored, they are in **subscription mode** (billed to their Claude Pro/Max subscription).
3. Tell them how to switch:
   - To **API key mode**: exit Claude Code and run:
     ```
     source /Users/scottzockoll/projects/workshop/secrets.env && claude
     ```
   - To **subscription mode**: exit Claude Code and run:
     ```
     unset ANTHROPIC_API_KEY && claude
     ```

Keep the response short and direct.
