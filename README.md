# Tabi — Medication Reminder App

iOS medication tracker with AI-powered prescription label scanning, caretaker SMS
alerts, and dose-adherence tracking.

This README is for **people on the team**. Claude's own instructions live in
[`CLAUDE.md`](CLAUDE.md) — you don't need to read that file to work here.

---

## What's in this repo

| Path | What it is |
|---|---|
| `Tabi/` | The iOS app (SwiftUI). Almost all the code you'll touch. |
| `TabiTests/` | Unit tests (Swift Testing). |
| `functions/` | Firebase Cloud Functions — missed-dose detection, caretaker SMS via AWS SNS. |
| `firestore.rules` | Database access rules. Must be deployed to take effect (see below). |
| `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md` | User-facing legal docs, mirrored in-app. |
| `PRIVACY_COMPLIANCE.md` | Guardrails to read *before* shipping anything that touches user health data. |
| `CLAUDE.md`, `.claude/` | Instructions, rules, and skills for Claude Code. |

Firebase project: **`tabi-47030`**. Bundle ID: **`com.hellotabi.Tabi`**.

---

## First-time setup

### 1. Clone the repo

```bash
git clone <repo-url>
cd tabi
```

### 2. Add your Gemini API key

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

### 3. Add the Firebase config

Get `GoogleService-Info.plist` from a teammate and put it at
`Tabi/GoogleService-Info.plist` — also **gitignored, never commit it**.

Its `BUNDLE_ID` must match the `Tabi` target's `PRODUCT_BUNDLE_IDENTIFIER`
(`com.hellotabi.Tabi`). A build phase checks this and fails the build loudly if
they drift apart — if that fires, re-download the plist from the Firebase console
for the right bundle ID.

### 4. Open it

Open `Tabi.xcodeproj` in Xcode and hit Run.

Adding a new Swift file? Just create it inside `Tabi/` — Xcode picks it up
automatically. No project-file surgery needed.

---

## Everyday workflow

You work through Claude Code. Three slash commands cover the whole loop:

| Command | When you use it |
|---|---|
| `/start` | **Before you write anything.** Grabs the latest main and puts you on a fresh branch. Carries over any work in progress. |
| `/sync` | **Any time, mid-work.** Pulls in whatever teammates shipped, keeps your work in place, and resolves conflicts for you. |
| `/ship` | **When it's ready.** Saves your work, opens a PR, merges it into main, and cleans up the branch. |

A normal day looks like:

```
/start            →  "What are you working on?"  →  you're on a clean branch
   ...build with Claude...
/sync             →  (optional, if you've been at it a while)
/ship             →  "What problem does this solve?"  →  merged to main
```

**Never commit straight to main** — always `/start` first, even for a one-line doc
fix. Three people work in this repo at once, and branches are what keep that from
hurting.

If `/ship` asks you to connect GitHub, type `! gh auth login` into the message box,
press Enter through the prompts, then run `/ship` again.

---

## Skills Claude can use

Skills are pre-written playbooks Claude loads on demand. You can invoke any of them
by name (`/swiftui-pro`), but Claude will also reach for the right one on its own.

**Workflow** — the ones you'll type yourself:

| Skill | Does |
|---|---|
| `/start` | Fresh branch off latest main |
| `/sync` | Pull main into your branch, resolve conflicts |
| `/ship` | PR + merge + cleanup |

**iOS & Xcode:**

| Skill | Does |
|---|---|
| `swiftui-pro` | Reviews SwiftUI for modern APIs, performance, and maintainability. Worth asking for on any sizeable view change. |
| `xcode-project-setup` | Safely edits `.pbxproj` to add Swift Packages. The only sanctioned way to add a dependency. |

**Firebase** (installed from `firebase/agent-skills`, pinned in `skills-lock.json`):

| Skill | Does |
|---|---|
| `firebase-basics` | CLI setup, login, project selection, config plists |
| `firebase-firestore` | Data modeling, queries, indexes, security rules |
| `firebase-security-rules-auditor` | Red-teams `firestore.rules`. **Run this whenever the rules change.** |
| `firebase-auth-basics` | Sign-in flows and auth-based access |
| `firebase-crashlytics` | Crash reporting setup |
| `firebase-remote-config-basics` | Feature flags without an app release |
| `firebase-ai-logic-basics` | Gemini via Firebase AI Logic |
| `firebase-hosting-basics`, `firebase-app-hosting-basics`, `firebase-data-connect` | Web hosting and SQL — not used by Tabi today |

**Built-in helpers worth knowing:** `/code-review` (finds bugs in your diff),
`/simplify` (cleanup-only pass), `/security-review` (security pass on the branch).

There's also `.claude/skills/verifier-ios.md` — notes Claude uses to build, install,
and screenshot the app on the simulator.

To add a skill, drop it in `.agents/skills/` and symlink it from `.claude/skills/`.

---

## Building and testing from the command line

```bash
# Build
xcrun xcodebuild -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build

# All tests
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17'

# Unit tests only (faster)
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TabiTests
```

**Simulators available here:** iPhone 17, iPhone 16e, iPhone Air. There is no
"iPhone 16" — using it will just fail.

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

Tabi stores medication, dosage, and profile data regulated under CMIA, Washington's
My Health My Data Act, and CCPA/CPRA — HIPAA doesn't apply to us as a
direct-to-consumer app, but those do.

Read [`PRIVACY_COMPLIANCE.md`](PRIVACY_COMPLIANCE.md) before you add a stored field,
share data with any third party (caretaker SMS counts), or touch
analytics/research/monetization. It has a pre-flight checklist.
