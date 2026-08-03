# Tabi — Privacy & Compliance Guardrails

Working reference for how Tabi collects, stores, and (eventually) monetizes health
data. Modeled on Oura's approach: hardware/subscription (for us, app) revenue as
the core business, with any research/pharma monetization built as a strictly
aggregate, opt-in, secondary stream — never a sale of raw or individual-level data.

This is an engineering/product guardrail doc, not a legal opinion. Get a
healthcare/privacy attorney to review before shipping anything in the
"Monetization path" section below, or before onboarding the first enterprise/
research/pharma partner.

## Where we actually stand, legally

- **HIPAA does not apply to us today.** HIPAA binds covered entities (providers,
  insurers, clearinghouses) and their business associates. Tabi is direct-to-
  consumer — users enter their own data. This flips the moment we sign a deal to
  process data *on behalf of* a provider, health plan, or pharmacy (that makes us
  a business associate, requiring a BAA and full HIPAA compliance).
- **What does apply:**
  - **California CMIA** — explicitly covers apps "designed primarily to maintain
    medical information" for consumers. Requires reasonable security and
    authorization before disclosing medical info to a third party.
  - **Washington My Health My Data Act** (and NV/CT equivalents) — applies based
    on user residence, not company location. Requires a specific consumer-health-
    data privacy notice, opt-in consent for any use beyond delivering the
    requested product, a distinct authorization for any *sale*, and a way to
    withdraw consent / delete data.
  - **CCPA/CPRA** — age + gender + medication data is "sensitive personal
    information," triggering rights to limit use, delete, correct, and opt out
    of sale/sharing.
  - **FTC Health Breach Notification Rule + FTC Act §5** — the real teeth here.
    GoodRx, Flo Health, and BetterHelp were all fined for sharing health data
    with third parties without disclosure users would actually understand — not
    because sharing is inherently illegal, but because the disclosure was
    inadequate. This is the standard we're actually held to in practice.

## Red lines (do not do these)

1. **Never sell or share raw or individual-level records** (de-identified or
   not) to a third party, including pharma or "research partners."
2. **Never bundle data-sharing consent into general Terms of Service.** Any use
   beyond "run the reminder app the user asked for" needs its own explicit,
   specific opt-in screen.
3. **Never retroactively repurpose data collected under a narrower disclosure.**
   If a future feature needs a new kind of data use, it needs new consent from
   existing users — not just an updated privacy policy nobody sees.
4. **Never let health data flow into ad networks or generic analytics SDKs.**
   No ad-tech SDK gets medication, dosage, age, gender, or pharmacy fields —
   full stop.
5. **Never publish an "aggregate" report where a cell could realistically be
   traced back to one person.** No cohort under a minimum size (start at 20)
   ships in any report, internal or external.

## Data collection: minimize by default

This extends the existing rule in `CLAUDE.md` ("adding a field is the last
resort") with a compliance lens. Before adding any field to a stored model, ask:

- Is this needed to run the feature the user is using right now?
- If it's for future analytics/research use only — don't add it yet. Add it
  when that feature ships, with its own disclosure, not preemptively.
- Does this field, combined with what we already store, make a user easier to
  re-identify later (e.g., exact birth date vs. birth year)? If a field's only
  value is for future aggregate reporting, consider storing the generalized
  form (age band, not DOB) instead of the precise form.

## Consent architecture

Modeled on Oura's structure — separate, purpose-specific, opt-in, not a single
blanket checkbox:

- **Core app use** (reminders, dose tracking): covered by normal account
  creation, no extra consent needed — this is "necessary to provide the
  requested product."
- **Caretaker sharing (SMS)**: already requires an explicit per-recipient
  invite/confirmation flow (`ConnectionConfirmationService`) — keep this
  pattern. Never auto-share with a caretaker without their own confirmation
  step.
- **Any future research/analytics use**: needs its own dedicated opt-in,
  presented as its own screen (à la Oura's separate Research app), stating
  plainly what's collected, that it's aggregated/anonymized, and who receives
  the resulting reports. Off by default.
- **Any future "sale" as legally defined**: needs a distinct, separately
  signed authorization per MHMDA/CMIA — this is not satisfied by the research
  opt-in above. Do not build a "sale" pathway without counsel drafting the
  authorization flow specifically.

## Monetization path (if/when pursued)

The Oura-validated shape: internal use of identifiable data → aggregate,
anonymized report → sell the report, never the underlying data.

- Reports must be true aggregate statistics with minimum cohort size
  enforcement (suppress any cell below threshold) — not de-identified
  individual-level rows.
- The aggregation methodology needs privacy/legal sign-off before the first
  report ships, and again whenever new fields are added to a report.
- Structure partnerships like Eli Lilly/Oura where possible: ecosystem or
  distribution collaboration without raw data exchange, rather than data-for-
  money deals.
- Users must have opted in via the dedicated research/analytics consent (see
  above) before their data contributes to any report.

## Security baseline (already mostly true — keep it that way)

- Firestore rules stay deny-by-default, scoped per-`uid` (see `firestore.rules`
  and `CLAUDE.md`).
- No new Firestore collection ships without an explicit `match` rule — a
  missing rule fails closed on the client but silently, so this needs to be
  checked deliberately, not assumed.
- Encryption in transit/at rest via Firestore defaults — don't build custom
  crypto or opt out of this.
- Support account deletion that actually removes stored medical data, not just
  deactivates the account.

## Engineering checklist (use this when building a new feature)

- [ ] Does this feature share user data with anyone outside the user's own
      account? If yes → does explicit per-recipient consent already exist, or
      does this need a new consent screen?
- [ ] Does this feature add a field to a stored model? If yes → is it needed
      now, and does it increase re-identification risk if later aggregated?
- [ ] Does this feature send data to any third-party SDK or service? If yes →
      confirm it's not an ad/analytics network, and that it's covered by
      existing disclosures.
- [ ] Does this touch the caretaker-sharing or notification pipeline? If yes →
      confirm the recipient went through their own confirmation step.
