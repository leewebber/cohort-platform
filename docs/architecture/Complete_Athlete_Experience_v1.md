# Complete Athlete Experience v1

**Status:** Binding milestone definition. Audited. Implementation **not**
authorised.
**Recorded:** 2026-09-22
**Audit evidence:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md)
**Base:** `origin/main` `c4d3dcbb2656c99e0773427ca6f31944d8ca1e73`

```text
COMPLETE_ATHLETE_EXPERIENCE=AUDITED_AWAITING_APPROVAL
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=NOT_STARTED
DAILY_JOURNEY_INTEGRITY=COMPLETE
NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document defines the milestone. It is not an implementation licence.
Founder approval of this architecture and of selected Sprint 1 is required
before product code changes.

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
   athlete shell. Display-name or local profile cache is not identity.
2. **Assignments remain pinned to programme versions.** Catalogue default
   changes must not silently move existing athletes. Hosted
   `content_graph_prevent_assignment_repin` remains the pin invariant.
3. **Programme comparison cannot mutate enrolment.** Comparison, if built,
   is a read model. Enrolment is a separate explicit transaction.
4. **Enrolment is explicit.** Confirm, then call the existing catalogue
   enrolment RPC. No implicit enrol from browse, compare, or Home empty
   states.
5. **Programme replacement, if permitted, is an explicit product
   transaction.** Replacement creates a new assignment; it must not rewrite
   history or silently repin the previous assignment.
6. **Authored programme facts remain authoritative.** Duration, frequency,
   equipment, goals, and format come from the published programme version,
   not from calculated guesses or name similarity.
7. **M9 graph and composite facts remain derived read models.** They may
   inform inspection. They are not substitution, comparison-as-identity, or
   mutation authority.
8. **Display-name similarity is never identity.**
9. **Programme history remains truthful.** Completed sessions stay
   attached to the assignment and version they were trained on.
10. **Adaptation remains athlete-approved.** Acceptance mutates only the
    current prepared executable session. Scheduling is a separate
    authority.
11. **No unconstrained AI programme generation** on any athlete-facing
    path.
12. **No athlete-facing path may expose another athlete or publisher’s
    private data.**

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
| Enrolment | Explicit dialog → exact-version RPC. Replace-active is a second explicit confirm. Timezone argument uses device `timeZoneName`. Copy still says testing access, not a purchase. |
| Current programme | Programmes tab overview + session launch. Pin is durable. Superseded-default honesty is weak. |
| Calendar | Month grid, rest, completion, Train today ≠ adapt, Backfill capability-gated. |
| Home Today | Begin / Resume / Complete / rest / completed-today View results. No overdue card. No programme-complete card. |
| Progress / History | Assignment-scoped summaries and Profile-pushed history. Lineage code as name. Empty radar / trends. Error can collapse to empty. |
| Settings | Sign-out production-complete. Timezone, units, privacy, legal, deletion missing. Wearables “Coming later” is a dead row. |

The Daily Journey spine is **not** the launch-critical gap. The gap is the
product around it: decide, enrol honestly, live on a pinned version, and
see one coherent state.

---

## 7. Selected Sprint 1 (awaiting founder approval)

**Name:** Programme Discovery and Decision

**Athlete problem.** A new or switching athlete can open Programmes and
tap Enrol, but cannot inspect a programme as a product, cannot compare two
candidates, and cannot see authored facts that already exist on the
catalogue model. The decision that starts the rest of the journey is the
weakest honest step.

This sprint is selected from evidence, not because comparison was already
known to be missing. Ranking is in the audit §8.

**Entry.** Authenticated `AthleteAppShell` → Programmes, or Home
no-programme `ChoosePlanEntryCard` / unavailable `VIEW PROGRAMMES`.

**Exit.** Athlete has inspected one programme, optionally compared two,
and either cancelled or completed the existing explicit enrolment
transaction. Shell returns to Home with pinned assignment authority, or
remains no-programme if they cancelled.

**In-scope screens (recommended).**

- Catalogue list (existing `AthleteProgrammeSelectionScreen` / Programmes
  catalogue surface): show authored facts already on the published
  version (duration, frequency, equipment, goal, format) without inventing
  copy.
- Programme detail (new athlete-facing read surface): inspect one
  published version.
- Side-by-side comparison (new athlete-facing read surface): two catalogue
  versions; no mutation.
- Enrolment decision: reuse `enrol_athlete_in_catalogue_programme_version`
  and the existing confirm dialog contract. Do not add a second enrol RPC.

Distinguish four layers. Do not collapse them:

1. **Programme discovery** — find candidates in the existing catalogue.
2. **Programme detail** — inspect one candidate.
3. **Side-by-side comparison** — inspect two candidates without enrolling.
4. **Enrolment decision** — explicit confirm on an already-chosen version.

**Data authorities reused.**

- Published catalogue programme versions (authored facts).
- Current assignment pin (`AthleteHomeRuntimeAuthorityResolver`).
- Existing enrolment RPC and replace-active flag.
- M9 graph only as optional derived read labels, never as identity.

**Explicit non-goals.**

- Launch programme library authorship or hosted catalogue content.
- Onboarding / matching engine.
- Adaptation, payments, subscriptions.
- Changing pin semantics or allowing silent repin.
- Progress, History, Calendar, Active Session, or Daily Journey changes
  except a return-to-Home after successful enrol.
- Coach-studio comparison UI reuse as an athlete surface.
- Filter/search platform if it is not required to decide between the
  current published versions.

**Acceptance criteria (draft, for approval).**

1. Production athlete can open detail for a published catalogue version
   and see only authored facts (or minimal neutral labels).
2. Production athlete can compare exactly two published versions without
   changing assignment.
3. Enrol remains explicit, version-exact, and identical in authority to
   today’s RPC.
4. Replace-active remains an explicit second meaning, not a silent
   side-effect of compare.
5. No preview, coach-studio, or test-only surface is required to complete
   the journey.
6. Focused tests cover discovery → detail → compare (read-only) → enrol
   / cancel, plus pin-immutability regressions.

**Preview / review.** Founder review on production routes or a
documentation walkthrough. Do not create a fixture preview unless a later
task explicitly authorises one.

**Test plan.** Catalogue enrolment regressions, shell catalogue entry,
assignment pin / `content_graph_prevent_assignment_repin`, Home authority
none → programme after enrol, and new widget tests for detail and
compare-does-not-enrol.

**Stop boundary.** When an authenticated athlete can decide and enrol
honestly from production Programmes. Stop before replacement aftermath,
Progress composition, settings, offline catalogue cache, or library
content production.

Sprint 1 remains `NOT_STARTED` until founder approval.

---

## 8. Recommended later sequence (not authorised)

**Sprint 2 (outline):** Enrolment start integrity and superseded-pin
honesty — IANA timezone on enrol, athlete-visible pinned version versus
catalogue default, retired / superseded copy. Do not change pin rules.

**Sprint 3 (outline):** Programme lifecycle Home and cross-surface
agreement — programme-complete Home, replacement aftermath, Progress /
History using programme name not only `lineageCode`, honest error versus
empty.

These outlines do not authorise work.

---

## 9. Founder decisions still required

1. Approve or reject this milestone definition.
2. Approve, replace, or defer **Programme Discovery and Decision** as
   Sprint 1.
3. Confirm whether replace-active remains an allowed athlete path in
   Sprint 1, or browse/compare only with replacement deferred.
4. Confirm whether coach-only authenticated profiles may keep entering
   `AthleteAppShell` (current `AuthGate` behaviour).
5. Confirm how much testing-access copy may remain on enrol until
   commercial work.

---

## 10. Explicit non-actions

This audit task must not and did not:

- implement athlete features
- create a preview
- change product code
- contact hosted systems
- install or overwrite a phone build
- push any branch
- mutate Field Manual
- change `.env`
- touch WOD Timer / Whiteboard
- start Performance Portfolio
- mark the milestone implemented
