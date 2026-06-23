---
name: ship
description: Push the current branch, merge it into main, and clean up. Run when your work is ready.
---

# Ship

Pushes the current branch, merges it into main, and cleans up. No review required.

## Steps

1. Check the current branch:
   ```bash
   git branch --show-current
   ```
   If on `main`, stop and tell the user in plain language:
   > "You're on the main branch — there's nothing to ship here. Use `/start` to begin a new feature first."

2. Ask the user to describe what they built:
   > "What did you build or fix? Give me a sentence or two — I'll use it to document the changes."

   Store this as `<user_context>`. You'll use it for the commit message, PR description, and conflict resolution.

   Run `git status` and `git diff --stat` to see what changed. If there are unsaved changes, include them.

   Before saving, check if any files were added, moved, renamed, or deleted. If so, update `CLAUDE.md` to reflect the current project structure — new files go in the right section of the File Structure, removed files get cleaned up. Do this silently without telling the user.

   ```bash
   git add -A
   git commit -m "<one-line summary from user_context>" -m "<fuller description from user_context>"
   ```
   Never use the word "commit" with the user — say "saving your changes" instead.

3. Push the branch:
   ```bash
   git push -u origin <branch>
   ```

4. Create a PR using `<user_context>` as the body, then merge it:
   ```bash
   gh pr create --title "<branch name, humanized>" --body "<user_context>"
   gh pr merge --squash --delete-branch --yes
   ```

   If `gh pr merge` fails due to conflicts:
   - Tell the user:
     > "Your changes overlap with something added to main since you started. I'll sort it out."
   - Run:
     ```bash
     git fetch origin main && git merge origin/main
     ```
   - **Try hard to resolve every conflict automatically.** Use `<user_context>` to understand the intent behind the user's changes. Read both sides, and merge in a way that preserves that intent. Most conflicts are mechanical and can be resolved without user input.
   - Only involve the user if the conflict is genuinely ambiguous — both sides changed the same logic in incompatible ways and the right answer depends on product intent. In that case, describe in plain English with zero jargon and ask one concrete question, e.g.:
     > "You changed how the reminder time works, and so did someone else. Yours sends it 10 minutes early; theirs sends it at the exact time. Which do you want?"
   - Never show raw code, diff output, or conflict markers to the user.
   - After resolving: `git add -A && git commit --no-edit`, then re-run `gh pr merge --squash --delete-branch --yes`.

5. Switch back to main and pull:
   ```bash
   git checkout main && git pull
   ```

6. Celebrate:
   > "Shipped! Your changes are live on main. The branch has been cleaned up. Go build something new."
