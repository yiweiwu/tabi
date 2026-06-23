---
name: start
description: Pull latest main and create a new branch before starting a feature or bug fix.
---

# Start Work

Gets the cofounder onto a fresh branch from the latest main before they write any code.

## Steps

1. Run `git status` to check for uncommitted changes. If any exist, tell the user and stop — ask them to commit or stash before starting new work.

2. Run:
   ```bash
   git checkout main && git pull
   ```

3. Ask the user: **"What are you working on?"** Use their answer to generate a short, lowercase, hyphenated branch name (e.g., "add login screen" → `add-login-screen`). Prepend their first name if you know it (e.g., `yiwei/add-login-screen`).

4. Run:
   ```bash
   git checkout -b <branch-name>
   ```

5. Confirm: tell the user the branch name and that they're ready to start coding.
