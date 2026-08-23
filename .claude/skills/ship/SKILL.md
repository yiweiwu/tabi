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

2. Get context about what was built — the problem/reason (why), not just the change (what). If the user already described their work earlier in the conversation, use it directly — don't confirm, just proceed. Only ask if there is genuinely no context available:
   > "What problem does this solve? A sentence or two on the why — I'll use it to document the changes."

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

4. Before creating the PR, check that `gh` is available and authenticated:
   ```bash
   gh auth status
   ```
   If `gh` is not installed or not authenticated, tell the user:
   > "I need to connect to GitHub once before I can ship your code. It only takes a minute:
   > 1. In the message box at the bottom of this screen, type exactly: `! gh auth login` and press Enter
   > 2. Press Enter to accept each question — it'll open a browser window to sign in to GitHub
   > 3. Once you're signed in, come back here and run `/ship` again — I'll take care of the rest"

   Then stop. Once they return after authenticating, pick up from step 4 and do everything for them.

   Once authenticated, create a PR. Compose the body yourself from `<user_context>` and the diff — never paste `<user_context>` in raw, and never lead with a bullet list of what changed. Structure it as:

   ```markdown
   ## <Problem to Solve / Bug to Fix / Goal — pick whichever fits>
   <1-3 sentences: the problem or reason this MR exists, not what the code does. Someone scanning the PR list for 5 seconds should get the point from this alone. Only explain the non-obvious part — skip anything already obvious from the title or diff.>

   ## Details
   <Only if there's more worth knowing than the opening section already covered - bullet points of what changed, for someone who's actually interested. Skip this section entirely for small/self-explanatory changes.>

   ## Test plan
   <checklist of what was verified>
   ```

   Pick the opening heading to match what the PR actually is — "Bug to Fix" for a fix, "Goal" for a new feature, "Problem to Solve" as the general-purpose default. Don't default to a generic "Why" every time.

   Bad opening (too long, front-loads mechanism): "CalendarStore.save(schedule:) only ever stripped .upcoming entries before appending a freshly-built schedule, so a .skipped mid-day-add seed never got replaced, which meant editing a medication..."
   Good opening (states the problem, nothing else), under "## Bug to Fix": "Editing a medication's schedule twice in one day left stale dose entries behind instead of replacing them."

   ```bash
   gh pr create --title "<branch name, humanized>" --body "<composed body>"
   gh pr merge --squash --delete-branch
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
   - After resolving: `git add -A && git commit --no-edit`, then re-run `gh pr merge --squash --delete-branch`.

5. Switch back to main and pull:
   ```bash
   git checkout main && git pull
   ```

6. Celebrate:
   > "Shipped! Your changes are live on main. The branch has been cleaned up. Go build something new."
