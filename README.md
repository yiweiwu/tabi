# Tabi — Medication Reminder App

iOS medication tracker with AI-powered prescription label scanning, caretaker SMS
alerts, and dose-adherence tracking.

This README is for **people on the team**. Claude's own instructions — architecture
rules and the full skill roster it draws on — live in [`CLAUDE.md`](CLAUDE.md); you
don't need to read that file to work here.

Firebase project: **`tabi-47030`**.

---

## First-time setup

### 1. Clone the repo

```bash
git clone <repo-url>
cd tabi
```

### 2. Third-party dependencies

| Dependency | What it's for | Setup needed |
|---|---|---|
| **Firebase** (Auth, Firestore) — Swift Package Manager | Sign-in, database, all persistent app data | Nothing to install — Xcode resolves the package on its own. You do need `GoogleService-Info.plist` (step 4). |
| **Google Sign-In** — Swift Package Manager | The "Sign in with Google" option | Bundled with the Firebase Auth setup above — nothing extra to do. |
| **Gemini API** | Reads prescription labels off a photo | Needs your own free API key (step 3). |
| **AWS SNS** — used only in `functions/`, not the iOS app | Sends caretaker SMS alerts | Nothing needed to build or run the app. Only matters if you're deploying Cloud Functions — see [Backend](#backend). |

### 3. Add your Gemini API key

Create `Tabi/Config.swift` — **gitignored, never commit it**:

```swift
enum Config {
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
}
```

Get a free key at [aistudio.google.com](https://aistudio.google.com). The app uses
**Gemini 2.5 Flash** for prescription label extraction.

> The free tier is rate-limited. Enable billing on the Google Cloud project for
> anything beyond casual testing.

### 4. Add the Firebase config

Get `GoogleService-Info.plist` from a teammate and put it at
`Tabi/GoogleService-Info.plist` — also **gitignored, never commit it**.

Its `BUNDLE_ID` must match the `Tabi` target's `PRODUCT_BUNDLE_IDENTIFIER`
(`com.hellotabi.Tabi`). A build phase checks this and fails the build loudly if
they drift apart — if that fires, re-download the plist from the Firebase console
for the right bundle ID.

### 5. Open it

Open `Tabi.xcodeproj` in Xcode and hit Run.

Adding a new Swift file? Just create it inside `Tabi/` — Xcode picks it up
automatically. No project-file surgery needed.

---

## Everyday workflow

You work through Claude Code. Three slash commands cover the whole loop — `/start`,
`/sync`, and `/ship` — and you can always type any of them yourself:

| Command | What it does |
|---|---|
| `/start` | Grabs the latest main and puts you on a fresh branch. Carries over any work in progress. |
| `/sync` | Pulls in whatever teammates shipped, keeps your work in place, and resolves conflicts for you. |
| `/ship` | Saves your work, opens a PR, merges it into main, and cleans up the branch. |

In practice, you'll rarely need to type `/start` or `/sync` — Claude runs those on
its own the moment they're needed (e.g. it'll branch you off main automatically
before touching any code if you're sitting on main, and re-sync after a PR merges).
Don't be surprised if you see it happen without being asked; that's expected.

`/ship` is the one exception — Claude will always check with you first before
pushing, opening a PR, or merging, since that's the step visible to the rest of the
team. It'll ask something like "What problem does this solve?" to write the PR
description, and confirm you actually want it shipped before it merges.

**Three people work in this repo at once, so nothing should ever land straight on
main** — Claude will get you onto a branch first even for a one-line doc fix.

If `/ship` asks you to connect GitHub, type `! gh auth login` into the message box,
press Enter through the prompts, then run `/ship` again.

Claude also draws on a bunch of other skills on its own (SwiftUI review, Firebase,
security audits, and more) — that roster is documented in `CLAUDE.md`, not here,
since you won't need to invoke them yourself.

---

## Backend

Cloud Functions (`functions/`, Node 20) handle everything that has to work while the
app is closed:

- `checkMissedDoses` — scheduled sweep that marks doses missed server-side
- `sendMissedPillAlert` — texts caretakers when a dose is missed
- `sendConnectionConfirmation` / `confirmCaretakerOptIn` — caretaker SMS opt-in
- `onUserCreate` — sets up a new user's document

```bash
# Deploy functions
firebase deploy --only functions --project tabi-47030

# Deploy database rules — editing firestore.rules alone does NOTHING until you run this
firebase deploy --only firestore:rules --project tabi-47030
```

That second one bites people. An undeployed rules change looks exactly like a
missing rule: the app's writes just silently fail.

---

## How label scanning works

1. Point the camera at a prescription bottle label
2. Vision OCR pulls the raw text off the image
3. Gemini interprets that text (it's good at OCR noise from curved bottles)
4. Out comes brand name, generic name, dosage, and schedule
5. The user reviews and confirms before anything is saved

---

## Before you ship anything touching user data

Read [`docs/PRIVACY_COMPLIANCE.md`](docs/PRIVACY_COMPLIANCE.md) before adding a stored field,
sharing data with any third party (caretaker SMS counts), or touching
analytics/research/monetization — it covers which privacy laws apply to Tabi and
has a pre-flight checklist.
