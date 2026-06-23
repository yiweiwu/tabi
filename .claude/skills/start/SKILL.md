---
name: start
description: Pull latest main and create a new branch before starting a feature or bug fix.
---

# Start Work

Gets the cofounder onto a fresh branch from the latest main before they write any code.

## Steps

1. Run `git status` to check for uncommitted changes.

   If there are unsaved changes, say something like:
   > "You have some unsaved work. Do you want to bring those changes with you to the new branch, or permanently delete them?"

   Use plain language — never say "uncommitted", "stash", or "branch" to the user.

   - **Bring them along** → `git stash`, continue to step 2, then pop after branch is created (step 5)
   - **Delete them** → Warn clearly first:
     > "Just to confirm — this will permanently delete those changes and they cannot be recovered. Are you sure?"
     Only proceed after explicit confirmation. Then run: `git restore .`
     If there are also new untracked files, ask separately: "There are also new files that would be deleted. Delete those too?"
     If yes: `git clean -fd`

2. Run:
   ```bash
   git checkout main && git pull
   ```

3. Ask the user: **"What are you working on?"** Use their answer to generate a short, lowercase, hyphenated branch name (e.g., "add login screen" → `add-login-screen`). Prepend their first name if you know it (e.g., `yiwei/add-login-screen`).

   Show the branch name and confirm before creating it:
   > "I'll create a branch called `yiwei/add-login-screen`. Does that sound right?"

4. Run:
   ```bash
   git checkout -b <branch-name>
   ```

5. If changes were stashed in step 1, pop them:
   ```bash
   git stash pop
   ```
   If this results in a merge conflict, tell the user in plain terms:
   > "There's a conflict bringing your changes over. Let me fix that for you."
   Then resolve the conflicts automatically if possible, or show the user exactly what to do in plain language.

6. Confirm with a friendly message, e.g.:
   > "You're all set! You're working on `yiwei/add-login-screen`. Go build it."
