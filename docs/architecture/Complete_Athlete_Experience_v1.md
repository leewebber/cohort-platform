# Complete Athlete Experience v1

**Status:** Binding milestone definition. Architecture **approved**.
Sprint 1 **Programme Discovery and Decision** is **complete** on
`origin/main` `a3cd351`. Sprint 2 is **implemented, awaiting founder
approval**. It is **not** complete.
**Recorded:** 2026-09-22
**Live pointer:** 2026-09-23
**Decisions bound:** 2026-09-22
**Audit evidence:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md)
**Sprint 2 binding:**
[`Complete_Athlete_Experience_Sprint_2_v1.md`](./Complete_Athlete_Experience_Sprint_2_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md)
**Historical architecture base:** `c4d3dcbb2656c99e0773427ca6f31944d8ca1e73`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
DAILY_JOURNEY_INTEGRITY=COMPLETE
NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document defines the approved milestone. It is not an implementation
licence. Product code must not change until a later task separately
authorises Sprint 1 implementation.

---

## 1. What this milestone is

**Complete Athlete Experience** is the coherent production athlete journey
that surrounds the now-reliable Daily Journey execution spine.

Daily Journey Integrity (`DAILY_JOURNEY_INTEGRITY=COMPLETE`) closed
authenticated session entry, restore authority, execution reliability, and
production accessibility for the Home / Calendar → Active Session →
completion path. That spine is the execution core. It is not the whole
athlete product.

This milestone asks whether an authenticated athlete can live in one
premium Cohort product: understand what is offered, choose a programme
honestly, enrol without accidental state, know what they are on, see
Calendar / Programmes / Home / Progress / History agree, and recover from
empty, completed, superseded, loading, offline, and error states — without
being asked to invent a later roadmap.

The production entry is `lib/main.dart` → `CohortPlatformApp` → `AuthGate`
→ `AthleteAppShell`. Preview, prototype, coach-studio, and test-only
surfaces receive no readiness credit.

---

## 2. What this milestone is not

The audit may name dependencies on later work. It must not implement them
or silently pull them into this milestone.

Explicitly **outside** Complete Athlete Experience:

| Later work | Binding home |
|------------|--------------|
| Scaling and authoring the full launch programme library | Delivery roadmap item 6 |
| Adaptation engine implementation | Adaptation Policy; later Adaptation Engine v1 |
| Advanced progression mechanics | Progression and tracking |
| Athlete-defined Performance Portfolio | `M-PRG`, not this milestone |
| Exercise knowledge / media completion | Phase 3.2E/F/G unallocated |
| Wearables and GPS | later wearables milestone |
| Full onboarding / matching engine | later onboarding milestone |
| Payments / subscriptions / commercial operations | later commercial milestone |
| Standalone WOD Timer and Whiteboard | pre-launch utility **after** core journey |
| Build Your Own | after individual athlete launch |
| Coaching / publisher product | frozen after M10 |
| B2B / white label | later |
| Blue-brand implementation | not authorised |
| Android release identity / signing | not authorised |
| Offline completion queue | not authorised |

Daily Journey Integrity remains closed. Do not reopen Sprint 1–3 contracts
to absorb catalogue, comparison, Progress, or settings work.

---

## 3. Journey questions this milestone must answer

An authenticated athlete must be able to answer these from production
surfaces, not architecture intent:

1. How does Cohort explain what it offers?
2. How do they find the right programme?
3. How do they inspect and compare programmes?
4. How do they enrol without accidental or misleading state changes?
5. How do they understand their current programme, schedule, and next
   action?
6. How do Calendar, Programmes, Home, Progress, and History agree?
7. What happens when they have no programme?
8. What happens when a programme is completed, retired, superseded, or
   unavailable?
9. How do they understand their pinned programme version?
10. How do they safely leave, replace, or change a programme if that path
    is allowed?
11. How are loading, empty, unavailable, offline, and error states
    presented?
12. Does the app feel like one premium athlete product rather than a
    collection of technical surfaces?

Evidence for the current answers lives in the audit checkpoint. The
scoreboard there is binding for readiness claims.

---

## 4. Production journey map

```text
lib/main.dart
  → CohortPlatformApp
    → AuthGate (ProductionAuthAuthority + CurrentUserSession)
      → LoginScreen / EmailVerificationScreen / ProfileSetupScreen
      → FounderWorkspaceShell (founder email only)
      → AthleteAppShell
           Home        HomeScreen + AthleteProgrammeTodaySection
           Calendar    AthleteCalendarScreen
           Programmes  AthleteProgrammeScreen → catalogue / current
           Progress    ProgressScreen
           Profile     AthleteProfileScreen → TrainingHistoryScreen
```

Daily Journey handoff (already closed): Home or Calendar →
`ProgrammeSessionExecutionLauncher` → `ProductionRestoreResolver` →
`ActiveSessionScreen` → `ActivePerformanceDraft` → idempotent hosted
completion.

Catalogue enrolment (existing authority, not a new mutation path):
`AthleteProgrammeSelectionScreen` →
`enrol_athlete_in_catalogue_programme_version` with exact version pin.

Athlete-facing programme comparison is **not** mounted on this map.
`lib/features/programme_comparison/` is consumed by coach-studio and
migration tooling only.

---

## 5. Authority and integrity (non-negotiable)

These rules are binding for every Complete Athlete Experience sprint.

1. **Authenticated athlete identity remains authoritative.**
   `CurrentUserSession` / `ProductionAuthAuthority` decide who is in the
   athlete shell. Display-name, local profile cache, and fallback strings
   such as `athlete.local` are never identity. Missing authoritative
   athlete identity must fail closed.
2. **Coach role alone does not authorise `AthleteAppShell`.** A coach-only
   identity must fail closed from athlete surfaces. A dual-role person may
   enter athlete surfaces only through their authoritative athlete
   profile/context. No synthetic athlete identity. Later coach/publisher
   product work must use its own authorised shell. This is a
   **launch-integrity** requirement. Do not implement it in documentation
   tasks, and do not silently add it to Sprint 1 unless a later
   implementation plan proves Sprint 1 touches that `AuthGate` boundary.
3. **Assignments remain pinned to programme versions.** Catalogue default
   changes must never move existing athletes. Hosted
   `content_graph_prevent_assignment_repin` remains the pin invariant.
4. **Programme comparison cannot mutate enrolment.** Comparison is a read
   model. Enrolment is a separate explicit transaction.
5. **Enrolment is explicit and uses one mutation authority.** Confirm,
   then call the existing `enrol_athlete_in_catalogue_programme_version`
   RPC. No implicit enrol from browse, compare, or Home empty states. Do
   not add a second enrol path.
6. **Active-programme replacement is out of Sprint 1.** An athlete with
   no active assignment may explicitly enrol through the existing
   authorised path. An athlete with an active assignment may inspect and
   compare other programmes. Sprint 1 must not replace, rewrite, or repin
   that assignment. Do not reuse the normal enrol action as a hidden
   “switch programme” action. If production UI exposes another programme
   to an active athlete, the CTA must truthfully explain that programme
   switching is not available through this Sprint 1 path. There must be
   no dead or misleading replacement CTA.
7. **Programme replacement, if later permitted, is an explicit product
   transaction.** It must not rewrite history or silently repin the
   previous assignment. Listing replacement in Sprint 2 architecture work
   does **not** approve the transaction or UX.
8. **Authored programme facts remain authoritative.** Duration, frequency,
   equipment, goals, and format come from the published programme version,
   not from calculated guesses or name similarity.
9. **M9 graph and composite facts remain derived read models.** They may
   inform inspection. They are not substitution, comparison-as-identity, or
   mutation authority.
10. **Display-name similarity is never identity.**
11. **Programme history remains truthful.** Completed sessions stay
    attached to the assignment and version they were trained on.
12. **Adaptation remains athlete-approved.** Acceptance mutates only the
    current prepared executable session. Scheduling is a separate
    authority.
13. **No unconstrained AI programme generation** on any athlete-facing
    path.
14. **No athlete-facing path may expose another athlete or publisher’s
    private data.**
15. **Athlete-facing copy must be truthful.** “Testing access” language
    may exist only in internal fixtures or explicitly internal builds.
    External beta and production athlete routes must use product-neutral
    language. Do not imply payment, subscription, entitlement, or
    permanence that does not exist. If external beta access is free,
    describe it as beta access, not generic testing access. Commercial
    pricing and subscription design remain later work.
16. **Progress and History must not lie about emptiness or identity.**
    Progress must not present a hosted/query failure as a legitimate empty
    state. History must not use `athlete.local` or another fallback
    identity as athlete authority. Failure must be honest and retryable.
    These are launch blockers owned by Sprint 3. Complete Athlete
    Experience cannot close until both are corrected and tested.

---

## 6. Current production truth (summary)

Full citations and scenario traces are in the audit. Do not treat this
summary as implemented readiness by itself.

| Area | Production truth |
|------|------------------|
| Authenticated shell | `AuthGate` + five-tab `AthleteAppShell`. Guest / START TRAINING closed. Sign-out works. Cold offline cache is process-local only. |
| No-programme Home | `AthleteHomeRuntimeAuthority.none` → `ChoosePlanEntryCard`. |
| Catalogue | List + enrol confirm dialog on Programmes. No filter, search, or athlete programme detail. |
| Comparison | **Missing** on production athlete routes. |
| Enrolment | Explicit dialog → exact-version RPC. Production still exposes replace-active confirm (audit evidence). Founder-bound Sprint 1 must not use that as a switch path. Timezone argument uses device `timeZoneName`. Copy still says testing access. |
| Current programme | Programmes tab overview + session launch. Pin is durable. Superseded-default honesty is weak. |
| Calendar | Month grid, rest, completion, Train today ≠ adapt, Backfill capability-gated. |
| Home Today | Begin / Resume / Complete / rest / completed-today View results. No overdue card. No programme-complete card. |
| Progress / History | Assignment-scoped summaries and Profile-pushed history. Lineage code as name. Empty radar / trends. Error can collapse to empty. |
| Settings | Sign-out production-complete. Timezone, units, privacy, legal, deletion missing. Wearables “Coming later” is a dead row. |

The Daily Journey spine is **not** the launch-critical gap. The gap is the
product around it: decide, enrol honestly, live on a pinned version, and
see one coherent state.

---

## 7. Selected Sprint 1 (complete)

**Name:** Programme Discovery and Decision
**Flag:** `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE` on `origin/main`
`a3cd351`. The section below remains the historical Sprint 1 contract.

Sprint 1 exists to let an athlete:

```text
discover
  → inspect authored programme detail
  → compare candidates
  → make an explicit enrolment decision
```

The existing enrolment RPC remains the **only** enrolment mutation
authority.

**Athlete problem.** A new authenticated athlete can open Programmes and
tap Enrol, but cannot inspect a programme as a product, cannot compare two
candidates, and cannot see authored facts that already exist on the
catalogue model. The decision that starts the rest of the journey is the
weakest honest step. An already-assigned athlete has the same inspection
gap and must be able to look without switching.

This sprint is selected from evidence, not because comparison was already
known to be missing. Ranking is in the audit §8.

**Entry.** Authenticated `AthleteAppShell` → Programmes, or Home
no-programme `ChoosePlanEntryCard` / unavailable `VIEW PROGRAMMES`.

**Exit.**

- No-programme athlete: inspected one programme, optionally compared two,
  and either cancelled or completed the existing explicit enrolment
  transaction. Shell returns to Home with pinned assignment authority, or
  remains no-programme if they cancelled.
- Assigned athlete: inspected and/or compared without any assignment
  mutation. Active pin is unchanged.

**In-scope screens.**

- Catalogue list (existing `AthleteProgrammeSelectionScreen` / Programmes
  catalogue surface): show authored facts already on the published
  version (duration, frequency, equipment, goal, format) without inventing
  copy.
- Programme detail (new athlete-facing read surface): inspect one
  published version.
- Side-by-side comparison (new athlete-facing read surface): two catalogue
  versions; no mutation.
- Enrolment decision for **no-programme** athletes only: reuse
  `enrol_athlete_in_catalogue_programme_version`. Do not add a second
  enrol RPC. Do not pass replace-active as a Sprint 1 product path.
- Production-visible copy on this route: remove testing-access language;
  use truthful product-neutral or explicit beta-access language.

Distinguish four layers. Do not collapse them:

1. **Programme discovery** — find candidates in the existing catalogue.
2. **Programme detail** — inspect one candidate.
3. **Side-by-side comparison** — inspect two candidates without enrolling.
4. **Enrolment decision** — explicit confirm on an already-chosen version,
   only when there is no active assignment.

**Data authorities reused.**

- Published catalogue programme versions (authored facts).
- Current assignment pin (`AthleteHomeRuntimeAuthorityResolver`).
- Existing enrolment RPC for no-active-assignment enrol only.
- M9 graph only as optional derived read labels, never as identity.

**Explicit non-goals (Sprint 1).**

- Active-programme replacement, rewrite, or repin.
- Hidden “switch programme” via the normal enrol action.
- Dead or misleading replacement CTAs.
- Launch programme library authorship or hosted catalogue content.
- Onboarding / matching engine.
- Adaptation, payments, subscriptions, commercial pricing.
- Changing pin semantics or allowing silent repin / catalogue-default
  move.
- Progress, History, Calendar, Active Session, or Daily Journey changes
  except a return-to-Home after a successful no-programme enrol.
- Coach-studio comparison UI reuse as an athlete surface.
- Coach-only `AthleteAppShell` routing, unless the implementation plan
  later proves Sprint 1 touches that `AuthGate` boundary.
- Progress error-as-empty and History `athlete.local` fallback (Sprint 3).
- IANA enrol timezone and superseded-pin honesty (Sprint 2 architecture
  work).
- Filter/search platform if it is not required to decide between the
  current published versions.

**Acceptance criteria.**

1. Production athlete can open detail for a published catalogue version
   and see only authored facts (or minimal neutral labels).
2. Production athlete can compare exactly two published versions without
   changing assignment.
3. No-programme enrol remains explicit, version-exact, and identical in
   authority to today’s RPC.
4. Assigned-athlete browse/compare never calls enrol or replace-active.
5. Any CTA shown beside another programme to an assigned athlete states
   that switching is not available on this Sprint 1 path. No dead
   replacement control.
6. Production discovery/detail/comparison/enrolment copy has no
   “testing access” language.
7. No preview, coach-studio, or test-only surface is required to complete
   the journey.
8. Focused tests cover discovery → detail → compare (read-only) →
   no-programme enrol / cancel, assigned-athlete compare-does-not-enrol,
   and pin-immutability regressions.

**Preview / review.** Founder review on production routes or a
documentation walkthrough. Do not create a fixture preview unless a later
task explicitly authorises one.

**Test plan.** Catalogue enrolment regressions, shell catalogue entry,
assignment pin / `content_graph_prevent_assignment_repin`, Home authority
none → programme after no-programme enrol, and new widget tests for
detail, compare-does-not-enrol, and assigned-athlete no-replace.

**Stop boundary.** When an authenticated athlete can discover, inspect,
compare, and — if unassigned — enrol honestly from production Programmes.
Stop before replacement, timezone/pin-honesty work, Progress composition,
settings, offline catalogue cache, coach-shell routing, or library
content production.

Sprint 1 is **complete** on `origin/main` `a3cd351`.

---

## 8. Recommended later sequence (not authorised)

**Sprint 2** binding (**implemented, awaiting founder approval**):
[`Complete_Athlete_Experience_Sprint_2_v1.md`](./Complete_Athlete_Experience_Sprint_2_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_HANDOFF.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_HANDOFF.md).
Slice: IANA enrol + athlete-local start date + pinned-versus-default
status. Replacement remains architecture only. Pin rules must not change.

Historical outline (2026-09-22): IANA timezone, superseded-pin honesty,
replacement **design**, historical preservation, aftermath. Listing
replacement does **not** approve the transaction.

**Sprint 3 (outline, not authorised):** Programme-complete Home and
cross-surface agreement —

- programme-complete Home
- Progress / History using programme name not only `lineageCode`
- Progress must not present hosted/query failure as empty
- History must not use `athlete.local` or another fallback identity
- honest retryable failure; missing identity fails closed

Complete Athlete Experience **cannot close** until the Progress and
History launch blockers are corrected and tested.

These outlines do not authorise work.

---

## 9. Resolved founder decisions

Recorded 2026-09-22. These replace the prior unresolved list. They do not
erase the production-route audit.

| Decision | Binding |
|----------|---------|
| Architecture v1 | **Approved** (`COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED`) |
| Sprint 1 name | **Programme Discovery and Decision** (`COMPLETE` at `a3cd351`) |
| Implementation | **Not started** until separately authorised |
| Active-programme replacement | **Out of Sprint 1.** Inspect/compare allowed. No replace, rewrite, or repin. No hidden switch. Truthful CTA if another programme is shown. Listed in Sprint 2 architecture work only; **not approved** as a transaction |
| Coach-only shell entry | Coach role alone does **not** authorise `AthleteAppShell`. Fail closed. Dual-role only via authoritative athlete context. No synthetic / display-name / fallback identity. Launch-integrity requirement; not this docs task; not silently Sprint 1 |
| Testing-access copy | Internal fixtures / internal builds only. Production and external beta must be truthful and product-neutral, or explicitly “beta access”. Sprint 1 must replace production-visible testing language on the discovery/detail/comparison/enrolment route. Commercial design remains later |
| Progress error-as-empty | Launch blocker. Out of Sprint 1. Sprint 3. Milestone cannot close until corrected and tested |
| History identity fallback | Launch blocker. No `athlete.local` or other fallback authority. Fail closed. Out of Sprint 1. Sprint 3. Milestone cannot close until corrected and tested |

### 9.1 Sprint 2 decisions (2026-09-23)

Live binding:
[`Complete_Athlete_Experience_Sprint_2_v1.md`](./Complete_Athlete_Experience_Sprint_2_v1.md)
§3. Sprint 2 is **implemented, awaiting founder approval**. End+create replacement is
architecture only. Enrol `started_at` is IANA-local in the enrol
transaction, not session `CURRENT_DATE`.

---

## 10. Explicit non-actions

This decision-binding task must not and did not:

- implement Sprint 1 or any athlete feature
- authorise Sprint 2 or Sprint 3
- create a preview
- change product code, schema, or fixtures
- contact hosted systems
- install or overwrite a phone build
- push any branch
- mutate Field Manual
- change `.env`
- touch WOD Timer / Whiteboard
- start Performance Portfolio
- mark Sprint 1 or the milestone implemented
