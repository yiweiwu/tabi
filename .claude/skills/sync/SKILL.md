---
name: sync
description: Pull the latest main into your current branch without losing your in-progress work, fixing any merge conflicts automatically.
---

# Sync

Brings the cofounder's branch up to date with the latest main, preserving whatever they're mid-way through, and resolves conflicts for them. Safe to run at any time — on `main` or a feature branch, with or without uncommitted changes.

## Steps

1. Check for in-progress work, regardless of which branch it's on:
   ```bash
   git status
   ```
   If there are any uncommitted changes (tracked or untracked), set them aside before touching anything else:
   ```bash
   git stash -u
   ```
   Tell the user in plain language, never using words like "stash", "commit", or "merge":
   > "You've got some work in progress — I'll set it aside for a second, grab the latest updates, then bring it right back."

   Remember whether anything was actually set aside (`git stash -u` prints "No local changes to save" if there was nothing to do) — step 5 needs to know whether to bring something back. Do this check first no matter the branch — someone can easily be mid-edit directly on `main` too.

2. Get the latest main:
   ```bash
   git fetch origin main
   ```

3. Bring those updates into whatever branch is currently checked out — this works the same whether that's `main` itself or a feature branch:
   ```bash
   git merge origin/main
   ```
   If the branch is already up to date, git will say so and there's nothing else to do here.

   If this produces conflicts:
   - Tell the user:
     > "Some things changed on main that overlap with your work. I'll sort it out."
   - **Try hard to resolve every conflict automatically.** Read both sides — the incoming changes from main and the user's own work on this branch — and merge them in a way that preserves the intent of both. Most conflicts are mechanical (two unrelated changes touching the same file) and don't need input from the user.
   - **When writing the resolved code, don't just concatenate both sides.** Rewrite the section so it reads as if one person wrote it cleanly in one pass: no leftover duplicate logic, no dead code from either side that no longer makes sense once combined, and variable/function names or comments from one side that now refer to something removed by the other should be updated to match. Match the surrounding file's existing style and formatting per `CLAUDE.md` — the result should be as readable as any other part of the file, not visibly stitched together.
   - Check `CLAUDE.md` for known trouble spots before resolving (e.g. `DoseStatus`'s custom encode/decode needing both sides updated together, dose-tracking display rules, Firestore field rules) so the resolved code still follows the project's own conventions.
   - Only involve the user if the conflict is genuinely ambiguous — both sides changed the same logic in incompatible ways and the right answer depends on product intent. In that case, describe it in plain English with zero jargon and ask one concrete question, e.g.:
     > "Someone changed how doses get marked as missed, and so did you. Yours checks every 60 seconds, theirs checks every 5 minutes. Which should we keep?"
   - Never show raw code, diff output, or conflict markers to the user.
   - After resolving:
     ```bash
     git add -A && git commit --no-edit
     ```

4. If work was set aside in step 1, bring it back:
   ```bash
   git stash pop
   ```
   If this produces a conflict:
   - Resolve it the same way as step 3 — read both sides, merge to preserve intent, and only ask the user if genuinely ambiguous. Never show raw conflict markers.
   - `git stash pop` does not clean up after itself when a conflict occurs, so once everything looks right, finish the job explicitly:
     ```bash
     git add -A
     git stash drop
     ```
     (`git stash pop` normally does both the restore and the cleanup in one step, but only when there's no conflict — after a manual resolution, do them separately so no stray, already-applied stash entry is left behind.)

5. Confirm with a friendly message:
   > "You're all set! Your branch now has the latest from main, and your work is right where you left it."

   If step 1 found nothing to set aside, adjust the message accordingly:
   > "You're all set! Your branch now has the latest from main."
