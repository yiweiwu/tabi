---
name: ship
description: Push the current branch, merge it into main, and clean up. Run when your work is ready.
---

# Ship

Pushes the current branch, merges it into main, and cleans up. No review required.

## Steps

1. Run `git status`. If there are uncommitted changes, tell the user and stop — ask them to commit first.

2. Check the current branch:
   ```bash
   git branch --show-current
   ```
   If on `main`, stop and tell the user to run `/start` first.

3. Push the branch:
   ```bash
   git push -u origin <branch>
   ```

4. Create a PR and attempt to merge it:
   ```bash
   gh pr create --title "<branch name, humanized>" --body "" --fill
   gh pr merge --squash --delete-branch --yes
   ```
   If `gh pr merge` fails due to conflicts:
   - Tell the user: "Your branch has conflicts with main. I'll pull in the latest changes so you can fix them."
   - Run:
     ```bash
     git fetch origin main && git merge origin/main
     ```
   - If conflicts remain, show which files are conflicted (`git status`), fix them, stage the files, and commit. Then re-run `gh pr merge --squash --delete-branch --yes`.

5. Switch back to main and pull:
   ```bash
   git checkout main && git pull
   ```

6. Confirm: tell the user their changes are live on main and the branch has been deleted.
