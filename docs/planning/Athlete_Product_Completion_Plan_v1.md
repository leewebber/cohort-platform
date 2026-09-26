# Athlete Product Completion Plan v1

**Status:** Binding athlete-launch doctrine and milestone plan
**Recorded:** 2026-09-20
**Does not start:** the next implementation sprint, Build Your Own, coaching
platform, B2B, hosted catalogue mutations, or Field Manual writes

```text
ATHLETE_PRODUCT_COMPLETION_PLAN=v1
ATHLETE_FIRST_LAUNCH=true
COACH_PLATFORM_FROZEN=true
M10_CLOSED=true
DAILY_JOURNEY_INTEGRITY=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE
HOSTED_MIGRATION_APPLIED=true
SPRINT_2_HOSTED_MIGRATION_APPLIED=true
SPRINT_3_HOSTED_MIGRATION_APPLIED=true
NEXT_MILESTONE=LAUNCH_PROGRAMME_LIBRARY
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=B1_COMPLETE
RUNNING_WORKOUT_B1=COMPLETE
LEE_BALI_HYBRID_BASE=INFRASTRUCTURE_IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
FOUNDER_ROADMAP_APPROVAL_REQUIRED=true
```

Binding parents:
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md),
[`../checkpoints/PRIVATE_PROGRAMME_INFRASTRUCTURE_HANDOFF.md`](../checkpoints/PRIVATE_PROGRAMME_INFRASTRUCTURE_HANDOFF.md),
[`../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md`](../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md),
[`../checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md`](../checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md),
[`../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md`](../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md),
[`../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md`](../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md),
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md),
[`../architecture/Programme_Studio_v1.md`](../architecture/Programme_Studio_v1.md),
[`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md),
[`../architecture/Programme_Performance_Metrics_Profile_v1.md`](../architecture/Programme_Performance_Metrics_Profile_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md),
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md),
[`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md),
[`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md),
[`../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md),
[`../checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md`](../checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md),
[`../checkpoints/ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md`](../checkpoints/ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md),
[`../architecture/Canonical_Programme_Architecture_Freeze_v1.md`](../architecture/Canonical_Programme_Architecture_Freeze_v1.md),
[`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md),
[`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md),
[`../architecture/Phase_1_Implemented_Architecture_v1.md`](../architecture/Phase_1_Implemented_Architecture_v1.md),
[`Delivery_Roadmap_v1.md`](./Delivery_Roadmap_v1.md).

This plan is architecture and product authority. It is not an implementation
licence.

---

## 1. Opening doctrine

Cohort is an **athlete-first hybrid training platform**.

It is not a generic workout tracker, a static programme PDF, a coach
marketplace, or an AI workout generator.

Positioning: **Runna-level product quality for complete hybrid performance.**

The launch product must combine strength, running, endurance, conditioning,
mobility/recovery, race preparation, useful adaptation, truthful progression,
and premium daily usability.

Cohort is not a quick fitness-app MVP. It must look, feel, and behave like a
product built by a well-funded, multi-million-dollar software company.

The launch product must be:

- genuinely useful
- visually premium
- fast
- stable
- secure
- accessible
- explainable
- trustworthy with long-term training history
- differentiated for hybrid athletes
- capable of scaling globally

### Binding development order

1. Safely close M10 infrastructure — **done**
2. Freeze deeper coach-platform development — **now**
3. Complete the athlete experience
4. Build the launch programme library
5. Complete the adaptation engine
6. Mature progression and performance tracking
7. Build the exercise knowledge/video layer
8. Integrate watches, health platforms and external services
9. Complete onboarding and programme matching
10. Complete subscriptions, analytics, support and commercial systems
11. Run progressively larger closed betas
12. Launch to individual hybrid athletes
13. Build Your Own Programme **after** athlete launch
14. Full coaching/publisher platform **after** Build Your Own
15. B2B / B2B2C and white-label expansion **later**

### Non-negotiable principles

| Principle | Meaning |
|-----------|---------|
| Athlete usefulness over feature count | Ship fewer things that complete a real week of training |
| Quality over arbitrary launch date | No date justifies a “mostly works” release |
| Authored training intent is authoritative | Adaptation never becomes a second prescription authority |
| Adaptations require athlete acceptance | Detect → explain → propose → preview → accept/decline → apply atomically → audit |
| Progression claims require evidence | No inferred PRs, capability, or “you’re fitter” without comparable facts |
| Status is never colour alone | Every state has a label, icon or text, and a next action |
| No data loss | Drafts, results, schedule, and history survive crash, offline, and correction |
| No launch-critical placeholder | Neutral labels only; no invented coaching copy |
| No hidden technical complexity | Athletes see today, schedule, session, history — not RPCs, pins, or hashes |
| Privacy and tenant isolation by design | Enrolment is not membership; RLS/RPC remain fail-closed |
| Truthful history | Scheduled / performed / recorded remain distinct (including Backfill) |
| Reliable interruption | Offline, weak network, backgrounding, and resume are first-class |
| Consistent product language and design | One vocabulary across Home, Calendar, Progress, Programmes, Profile |
| Every error gives a safe next action | Retry, save draft, go Home, or contact support — never a dead end |
| No “mostly works” launches | Exit criteria are binary for launch-critical paths |

### Destination ownership (unchanged)

| Destination | Owns |
|-------------|------|
| Home | Today only |
| Calendar | Schedule, move/skip/Train today, Incomplete recovery |
| Progress | History, trends, radar, programme review |
| Programmes | Discovery, comparison, enrolment |
| Profile | Account, help, settings, legal, subscription later |

---

## 2. Current athlete-product audit

Readiness scores use **production `lib/main.dart`** (`AuthGate` →
`AthleteAppShell`), hosted Field Manual architecture, and tests. Fixture
previews and unit tests alone do **not** award Complete. Phase 1 closeout
still records `PUBLIC_LAUNCH_READY=false`.

**Production execution spine:** programme sessions launch through
`ProgrammeSessionExecutionLauncher` → `ActiveSessionScreen` (block cards +
performance capture). Dedicated `StrengthSessionView` / `IntervalSessionView`
/ `CircuitSessionView` are **not** the athlete-shell path. Do not score those
preview players as production completeness.

Score vocabulary: **Complete** · **Strong foundation** · **Functional but
incomplete** · **Prototype-only** · **Missing** · **Blocked**.

### 2.1 Scoreboard

| # | Area | Score | Launch criticality |
|---|------|-------|--------------------|
| 1 | Authentication / account lifecycle | Functional but incomplete | Critical |
| 2 | Athlete onboarding | Functional but incomplete | Critical |
| 3 | Programme discovery / catalogue | Functional but incomplete | Critical |
| 4 | Programme detail / comparison | Missing (athlete side-by-side) | High |
| 5 | Enrolment / start | Strong foundation | Critical |
| 6 | Home / today | Strong foundation | Critical |
| 7 | Calendar / schedule | Strong foundation | Critical |
| 8 | Incomplete-session recovery | Strong foundation | Critical |
| 9 | Workout preparation | Strong foundation | Critical |
| 10 | Strength execution | Strong foundation | Critical |
| 11 | Running / endurance execution | Functional but incomplete | Critical |
| 12 | Interval execution | Functional but incomplete | Critical |
| 13 | EMOM / circuit / for-time | Strong foundation | Critical |
| 14 | Rest / recovery sessions | Prototype-only | High |
| 15 | Adapt Session | Functional but incomplete | Critical |
| 16 | Draft / offline / crash recovery | Functional but incomplete | Critical |
| 17 | Results / corrections | Strong foundation | Critical |
| 18 | Previous performance | Strong foundation | Critical |
| 19 | Progression comparisons | Functional but incomplete | Critical |
| 20 | Progress destination | Functional but incomplete | Critical |
| 21 | Capability radar | Prototype-only | Medium (truthful) |
| 22 | Notifications / reminders | Missing | High |
| 23 | Exercise knowledge / media | Prototype-only | High |
| 24 | Wearables / health integrations | Missing | Critical (launch bar) |
| 25 | Profile / settings / help | Functional but incomplete | High |
| 26 | Accessibility | Prototype-only | Critical |
| 27 | Performance / responsiveness | Functional but incomplete | Critical |
| 28 | Subscription / entitlements | Missing | Critical before public |
| 29 | Analytics / observability | Missing | High |
| 30 | Support / operations | Prototype-only | Critical before public |
| 31 | Privacy / legal / account deletion | Missing | Critical before public |
| 32 | Android readiness | Prototype-only | High (after iOS dogfood) |
| 33 | App Store / Play Store readiness | Missing | Critical before public |
| 34 | Programme library depth | Prototype-only | Critical |
| 35 | Beta / distribution tooling | Prototype-only | High |

No area is **Complete** against the funded-product bar. Architecture integrity
and the programme-athlete execution spine are the strongest assets.

### 2.2 Area dossiers

Each dossier uses: authority · readiness · gaps · criticality · dependency ·
evidence · recommended milestone · exit criteria.

#### 1. Authentication / account lifecycle

- **Authority:** `AuthGate`, `AuthService` / Supabase Auth; `profiles.id` =
  `auth.users.id`. Authenticated athletes resolve to `AthleteAppShell` (or
  founder workspace).
- **Readiness:** Email sign-up, verification, session restore work on Field
  Manual. Role chips still expose coach-era identity. No account deletion,
  export, or SSO suite.
- **Gaps:** `AuthGate` can mount `AthleteAppShell` **unauthenticated** when
  local `AthleteProfileSession.hasCompletedOnboarding` is true — not a
  public-launch path. Password reset UX; session expiry copy; account
  deletion; social sign-in research; coach-role suppression.
- **Criticality:** Critical.
- **Dependency:** Hosted Auth; later commercial identity.
- **Evidence:** `auth_gate.dart`; `PHASE_1_INTEGRATION_CLOSEOUT.md`
  (`PUBLIC_LAUNCH_READY=false`). Founder phone build 7 login is not a store
  lifecycle proof.
- **Milestone:** Athlete Experience Completion, then Commercial.
- **Exit:** Production shell requires a real session; athlete can create,
  verify, restore, reset, and (before public launch) delete an account
  without founder intervention.

#### 2. Athlete onboarding

- **Authority:** Profile setup after auth. Login **START TRAINING** still
  runs local `AthleteOnboardingFlow` and can generate a programme through
  `AthleteProgrammeGenerationService` (legacy Coach Brain) — **not**
  catalogue enrolment.
- **Readiness:** Functional but incomplete.
- **Gaps:** Must not remain a launch path. Need goal, event date, days/week,
  equipment, limitations; explainable **authored** recommendation;
  insufficient-match state.
- **Criticality:** Critical for catalogue matching; founder dogfood may keep
  a pinned assignment.
- **Dependency:** Launch library families; not Build Your Own; not Coach
  Brain assembly.
- **Evidence:** `LoginScreen` start-training; generation service. Planning
  Engine / Coach Brain must not assemble unverified plans for launch.
- **Milestone:** Onboarding and Personalisation (after library skeleton);
  AEC must hide or fail-closed the generative path in production.
- **Exit:** Athlete receives one explainable authored recommendation or an
  honest insufficient-match, with manual catalogue override. No generative
  programme reaches Home.

#### 3. Programme discovery / catalogue

- **Authority:** `AthleteProgrammeSelectionScreen`, catalogue enrolment
  services, M9 published versions + eligibility.
- **Readiness:** Browse/enrol primitives exist; commercial catalogue UX does
  not. Hosted published athlete programmes are **Apollo** and **Spartan**
  only.
- **Gaps:** Family taxonomy, filters, empty/offline, comparison-from-list,
  imagery, copy quality.
- **Criticality:** Critical once more than two families exist.
- **Dependency:** M9 publication; launch library.
- **Evidence:** `athlete_programme_selection_screen.dart`; two Field Manual
  manifests. Previews are not production depth.
- **Milestone:** Programme Library + Catalogue productisation.
- **Exit:** Athlete can filter 8–12 families, understand fit, and enrol an
  exact immutable version.

#### 4. Programme detail / comparison

- **Authority:** Catalogue row metadata + `AthleteProgrammeScreen` week
  view. `lib/features/programme_comparison/` is **coach-studio**
  intelligence, not mounted on `AthleteAppShell`.
- **Readiness:** **Missing** as an athlete product (detail is thin; no
  side-by-side).
- **Gaps:** Family comparison (duration, days/week, equipment, race vs
  general); athlete-readable week structure beyond the active pin.
- **Criticality:** High once more than two families exist.
- **Dependency:** Authored metadata on programme versions.
- **Evidence:** No athlete comparison screen on the production shell.
- **Milestone:** Catalogue productisation (`M-LIB` / AEC catalogue slice).
- **Exit:** Athlete can compare two families without founder explanation.

#### 5. Enrolment / start

- **Authority:** Catalogue enrolment + `programme_assignments` pin; Start
  Programme; schedule apply. M9 pin ≠ latest.
- **Readiness:** Strong foundation.
- **Gaps:** Schedule-setup UX at enrol; switch-programme consequences;
  entitlement gate later.
- **Criticality:** Critical.
- **Dependency:** M9 pin; Sprint 1.7 scheduling.
- **Evidence:** Enrolment services; Field Manual Lee Apollo pin
  `2ba018bd-…` unchanged by M10.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Enrol, pin, choose days, start first today without dual
  assignment or inferred membership.

#### 6. Home / today

- **Authority:** `AthleteHomeRuntimeAuthorityResolver` → Programme Athlete
  runtime only. `home_today_session_*`. Today-only.
- **Readiness:** Strong foundation.
- **Gaps:** Premium empty/rest/travel/offline; no-programme Home; visual
  polish vs funded-product bar.
- **Criticality:** Critical.
- **Dependency:** Schedule occurrences; prepared package provenance.
- **Evidence:** Home widgets; Phase 1 closeout; dogfood on build 7.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Every today state has a label, next action, and no calendar
  leakage.

#### 7. Calendar / schedule

- **Authority:** Month grid, occurrences, move/swap/skip/undo, Train today.
  Scheduling ≠ adaptation.
- **Readiness:** Strong foundation.
- **Gaps:** Event-date shift; pause/return; multi-session visual density;
  accessibility of grid.
- **Criticality:** Critical.
- **Dependency:** Sprint 1.7 architecture.
- **Evidence:** `athlete_calendar_month_grid.dart`; calendar architecture
  doc.
- **Milestone:** Athlete Experience Completion, then Adaptation (date
  change).
- **Exit:** Athlete can reschedule without fabricating completion or
  rewriting the Plan Package.

#### 8. Incomplete-session recovery

- **Authority:** Calendar Incomplete + resume RPC / local draft.
- **Readiness:** Strong foundation.
- **Gaps:** Multi-incomplete explanation; when to adapt vs resume; weak
  network.
- **Criticality:** Critical.
- **Dependency:** Atomic create/resume; drafts.
- **Evidence:** Calendar + session draft save path.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Two incompletes never lose capture; athlete chooses resume or
  adapt.

#### 9. Workout preparation

- **Authority:** Session overview / workout overview; prepared
  `SessionExecutionPlan`; Adapt entry.
- **Readiness:** Strong foundation.
- **Gaps:** Equipment/time preview; media; substitution preview before
  start.
- **Criticality:** Critical.
- **Dependency:** Adaptation metadata; exercise knowledge later.
- **Evidence:** `session_overview_screen.dart`, `workout_overview_screen.dart`.
- **Milestone:** Athlete Experience + Adaptation Engine.
- **Exit:** Athlete understands intent, duration, equipment, and whether
  Adapt is available before Start.

#### 10. Strength execution

- **Authority:** Production: `ActiveSessionScreen` + strength accordion /
  capture coordinator. `StrengthSessionView` is **not** the programme
  launcher path.
- **Readiness:** Strong foundation on the production capture path.
- **Gaps:** Tempo/RIR consistency; rest UX; media; load unit prefs; do not
  dual-maintain a second player as launch authority.
- **Criticality:** Critical.
- **Dependency:** Authored loads; previous actuals.
- **Evidence:** Strength accordion/completion tests; preview mains are not
  the shell.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Complete a prescribed strength session on `ActiveSessionScreen`,
  save all sets, survive interruption.

#### 11. Running / endurance execution

- **Authority:** Interval/endurance hydrators and capture; no HealthKit /
  GPS watch loop.
- **Readiness:** Functional but incomplete.
- **Gaps:** Outdoor run start, pace/HR import, treadmill vs outdoor,
  splits, watch handoff.
- **Criticality:** Critical for hybrid claim.
- **Dependency:** Wearables milestone; authored run prescriptions.
- **Evidence:** Interval hydrator; no `health` / Garmin packages in
  `pubspec.yaml`.
- **Milestone:** Wearables + running execution slice.
- **Exit:** Athlete can record a prescribed run with truthful pace/distance
  (manual or imported) without inventing GPS quality.

#### 12. Interval execution

- **Authority:** Production block-aware interval capture on
  `ActiveSessionScreen`. Dedicated `IntervalSessionView` is preview/dev
  (`SessionPlayerScreen`).
- **Readiness:** Functional but incomplete (capture contracts exist; player
  chrome is split).
- **Gaps:** One production interval experience; watch sync; outdoor cueing.
- **Criticality:** Critical.
- **Dependency:** Timer + later wearables.
- **Evidence:** Interval capture tests; router dual path.
- **Milestone:** Athlete Experience, then Wearables.
- **Exit:** Complete authored intervals on the production launcher with
  work/rest actuals retained.

#### 13. EMOM / circuit / for-time

- **Authority:** Production: `BlockTimerScreen` + EMOM/circuit/for-time
  capture widgets on the active-session path. `CircuitSessionView` is not
  the shell launcher.
- **Readiness:** Strong foundation for capture contracts.
- **Gaps:** AMRAP polish; for-time edge states; premium timer chrome.
- **Criticality:** Critical (HYROX-style work).
- **Dependency:** Authored circuit metadata.
- **Evidence:** `Athletic_Circuit_and_EMOM_Capture_v1.md`; capture tests.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Circuit/EMOM/for-time save scores that remain comparable later.

#### 14. Rest / recovery sessions

- **Authority:** Calendar rest days. `SessionExecutionMode.recoveryFlow`
  exists; `SessionPlayerScreen` still falls back to a legacy step card
  (`TODO: Replace with RecoverySessionView`).
- **Readiness:** **Prototype-only** for executed recovery sessions.
- **Gaps:** Dedicated recovery player; authored mobility sessions as
  first-class today states; check-in without fake PRs.
- **Criticality:** High.
- **Dependency:** Library rest/mobility weeks; not colour-only “recovery”.
- **Evidence:** Router + TODO; no recovery-specific tests found.
- **Milestone:** Library + Experience.
- **Exit:** Rest days and authored recovery sessions are first-class today
  states, not empty holes or placeholder players.

#### 15. Adapt Session

- **Authority:** `ProgrammeAdaptFlow` → proposal →
  `programme_adaptation_proposal_sheet` → explicit accept. Pipeline via
  Plan-Package-native adapter. No Coach Brain Home.
- **Readiness:** **Strong foundation** for day-of,
  acceptance-gated Adapt (`time`, `equipment`, `environment`, `recovery`).
  **Functional but incomplete** against the full §6 launch-trigger list.
  Policy gate already prohibits rewrite/later-session/periodisation
  invention.
- **Gaps:** See §6 (missed session, event date, pause/return, deload, …);
  confidence/insufficient-evidence UI; consequence preview completeness.
- **Criticality:** Critical.
- **Dependency:** Authored adaptation metadata; evidence inputs.
- **Evidence:** `programme_adapt_flow.dart`; adaptation architecture docs;
  internal metadata completeness tool (not athlete UX).
- **Milestone:** Adaptation Engine.
- **Exit:** Every launch v1 trigger follows the eight-step contract; dismiss
  is a no-op.

#### 16. Draft / offline / crash recovery

- **Authority:** Local execution draft + atomic resume RPC; provenance
  fail-closed.
- **Readiness:** Functional but incomplete. Local snapshot + atomic resume
  RPC exist; shell recovery does **not** always restore full player state.
- **Gaps:** Full in-progress restore; weak-network messaging; two-device
  conflict; guest persistence desync from hosted assignment.
- **Criticality:** Critical.
- **Dependency:** Atomic resume checkpoint; `AthletePersistence`.
- **Evidence:** `athlete_app_shell` recovery dialog; hydrator tests.
- **Milestone:** Athlete Experience Completion.
- **Exit:** Kill-app mid-set restores the same session and capture; no
  duplicate `training_sessions`.

#### 17. Results / corrections

- **Authority:** Completion screens; result views; Backfill
  `entry_mode`.
- **Readiness:** Strong foundation for hosted save + completed-session
  correction.
- **Gaps:** Athlete-facing chronology labels (scheduled vs performed vs
  recorded); what is immutable vs correctable after Backfill.
- **Criticality:** Critical (history trust).
- **Dependency:** Backfill schema (applied).
- **Evidence:** `completed_session_result_view.dart`; Backfill architecture.
- **Milestone:** Progression and tracking.
- **Exit:** Correction never silently mutates scheduled date or
  comparability without an audit trail.

#### 18. Previous performance

- **Authority:** Previous performance resolver / shell on strength and
  circuit.
- **Readiness:** Strong foundation where comparable actuals exist.
- **Gaps:** First-performance empty state; mixed-mode; run/endurance
  previous.
- **Criticality:** Critical.
- **Dependency:** Actuals tree; comparability rules.
- **Evidence:** `previous_performance_resolver.dart`; strength/circuit
  shells.
- **Milestone:** Progression and tracking.
- **Exit:** Previous is shown only when comparable; otherwise “first
  recorded” — never a guessed load.

#### 19. Progression comparisons

- **Authority:** Circuit result comparison and strength capture completion
  helpers; not a full longitudinal engine.
- **Readiness:** Functional but incomplete.
- **Gaps:** Weekly/programme review; regression language; personal-best
  rules.
- **Criticality:** Critical.
- **Dependency:** Evidence hierarchy in §7.
- **Evidence:** `circuit_result_comparison.dart`; progress screen.
- **Milestone:** Progression and tracking.
- **Exit:** Improvement/regression claims cite comparable sessions only.

#### 20. Progress destination

- **Authority:** `progress_screen.dart` + programme progress summary.
- **Readiness:** Functional but incomplete.
- **Gaps:** Discipline based on sessions **due**; rest days excluded;
  premium review; history filters.
- **Criticality:** Critical.
- **Dependency:** Actuals + schedule.
- **Evidence:** Progress screen; radar empty scaffold path.
- **Milestone:** Progression and tracking.
- **Exit:** Progress never shows calendar or today as primary jobs.

#### 21. Capability radar

- **Authority:** `CapabilityRadarProjectionService` / chart; empty scaffold
  when insufficient.
- **Readiness:** Prototype-only for launch truthfulness.
- **Gaps:** Availability rules; no false inference from one session;
  athlete explanation.
- **Criticality:** Medium — hide rather than lie.
- **Dependency:** Evidence hierarchy.
- **Evidence:** Progress radar widgets.
- **Milestone:** Progression (radar may remain hidden until rules pass).
- **Exit:** Radar renders only when each axis meets evidence rules;
  otherwise omitted with explanation.

#### 22. Notifications / reminders

- **Authority:** None in production `pubspec`.
- **Readiness:** Missing.
- **Gaps:** Local notifications, permission lifecycle, quiet hours,
  timezone.
- **Criticality:** High for adherence; not a substitute for Home.
- **Dependency:** OS permissions; later calendar integration.
- **Evidence:** No OneSignal/FCM/awesome_notifications dependency.
- **Milestone:** Wearables / integrations (notifications slice) or
  Experience late slice.
- **Exit:** Opt-in reminder for today’s session; revocation respected.

#### 23. Exercise knowledge / media

- **Authority:** `exercises_v2` identities; Phase 3.2D text-only eight-
  exercise pilot; application read projection **not** composed into
  production UI (`9bc5cd7`).
- **Readiness:** Prototype-only.
- **Gaps:** 60–100 film library; player; offline cache; production
  composition.
- **Criticality:** High for quality bar; technique-sensitive moves are
  launch-critical.
- **Dependency:** Phase 3.2E/F/G remain **unallocated** until this plan
  authorises the media milestone (not a numerical Phase 3 reopen).
- **Evidence:** Catalogue 132 rows; `OperationalExerciseTextGuidance` is
  **not** imported under `lib/features/`; `ExerciseDetailScreen` still uses
  the legacy protocol `Exercise` model. No video player package. Projection
  must not change prescription.
- **Milestone:** Exercise knowledge and media.
- **Exit:** Launch programmes resolve `EX-*` to owned or licensed demo
  media without rewriting history when URLs change.

#### 24. Wearables / health integrations

- **Authority:** None. `pubspec.yaml` has no HealthKit, Garmin, WHOOP, or
  Health Connect packages.
- **Readiness:** Missing. APIs/permissions **not verified** in-repo.
- **Gaps:** Entire §9. Commercial Garmin/WHOOP access may be required.
- **Criticality:** Critical for the stated launch bar; do not promise
  unverified vendors.
- **Dependency:** Apple developer capabilities; vendor programmes.
- **Evidence:** Dependency scan 2026-09-20.
- **Milestone:** Wearables and integration (starts with research spike).
- **Exit:** At least one verified import path (HealthKit or documented
  fallback) with precedence, revocation, and no auto-adapt.

#### 25. Profile / settings / help

- **Authority:** Profile tab exists; Join-coach / legacy coach surfaces
  still present. Internal tools are not athlete help.
- **Readiness:** Functional but incomplete.
- **Gaps:** Help centre, units, notifications, legal, coach CTA hidden for
  launch.
- **Criticality:** High.
- **Dependency:** Commercial + support.
- **Evidence:** `AthleteProfileScreen`; `BetaSupportScreen`;
  `join_coach_card.dart`. Wearables row is already “Coming later”.
- **Milestone:** Experience + Commercial.
- **Exit:** Profile explains account, programme, legal, and support
  without exposing coach-platform internals.

#### 26. Accessibility

- **Authority:** Partial `Semantics` on nav, calendar, some capture.
- **Readiness:** Prototype-only as a programme (scattered `Semantics` only).
- **Gaps:** Full VoiceOver pass; Dynamic Type; colour-not-only; reduce
  motion; focus order on timers.
- **Criticality:** Critical.
- **Dependency:** Design system discipline.
- **Evidence:** ~20 widget files; no dedicated a11y suite.
- **Milestone:** Every athlete milestone includes a11y exit criteria.
- **Exit:** Launch paths usable with VoiceOver; status never colour-only.

#### 27. Performance / responsiveness

- **Authority:** Flutter app; no published frame budget.
- **Readiness:** Functional but incomplete.
- **Gaps:** Cold start, calendar scroll, image later, jank budget.
- **Criticality:** Critical for premium feel.
- **Dependency:** Profiling on device (build 7+).
- **Evidence:** Dogfood subjective; no CI performance gate.
- **Milestone:** Experience + beta gates.
- **Exit:** Written budgets (e.g. today interactive, calendar 60fps target)
  met on target devices.

#### 28. Subscription / entitlements

- **Authority:** Catalogue comments state non-commercial test enrolment.
- **Readiness:** Missing.
- **Gaps:** StoreKit 2 / Play Billing, trial, restore, grace period.
- **Criticality:** Critical before public; not required for founder
  dogfood.
- **Dependency:** Founder pricing approval (**not** chosen here).
- **Evidence:** No `in_app_purchase` / RevenueCat.
- **Milestone:** Commercial.
- **Exit:** Purchase, restore, cancel, and entitlement-gated enrol work
  on sandbox.

#### 29. Analytics / observability

- **Authority:** None product-grade (no Sentry/Firebase in pubspec).
- **Readiness:** Missing.
- **Gaps:** Crash reporting, funnels, feature flags.
- **Criticality:** High before structured beta.
- **Dependency:** Privacy policy; consent.
- **Evidence:** Dependency scan.
- **Milestone:** Commercial / operations.
- **Exit:** Crashes attributable; launch funnels defined in §5.

#### 30. Support / operations

- **Authority:** Informal founder support.
- **Readiness:** Prototype-only.
- **Gaps:** Help centre, incident runbook, in-app feedback.
- **Criticality:** Critical before public.
- **Dependency:** Website / email.
- **Evidence:** No support product surface.
- **Milestone:** Commercial / operations + beta.
- **Exit:** Severity definitions and a reachable support entry from every
  error class.

#### 31. Privacy / legal / account deletion

- **Authority:** Isolation architecture (M10) is infrastructure, not
  athlete legal UX.
- **Readiness:** Missing.
- **Gaps:** Privacy, terms, consent logs, deletion, export.
- **Criticality:** Critical before store/public.
- **Dependency:** Legal review (founder).
- **Evidence:** No deletion RPC/UI found.
- **Milestone:** Commercial.
- **Exit:** Athlete can export and delete; deletion completes hosted data
  in a documented SLA.

#### 32. Android readiness

- **Authority:** Default Flutter `android/` scaffold.
- **Readiness:** Prototype-only.
- **Gaps:** `applicationId` is still `com.example.cohort_platform`; debug
  signing used for release; Health Connect; Play listing.
- **Criticality:** High after iOS journey is solid.
- **Dependency:** iOS proof first recommended.
- **Evidence:** `android/app/build.gradle.kts`; founder workflow is iPhone
  `uk.cohortperformance.cohort` build 7.
- **Milestone:** Late Experience / store readiness.
- **Exit:** Real applicationId, release signing, and parity on
  launch-critical journeys on a defined device set.

#### 33. App Store / Play Store readiness

- **Authority:** iOS project + `ReleaseConfigurationPolicy`; no listing pack.
- **Readiness:** Missing as a submission package.
- **Gaps:** Listings, review notes, privacy nutrition, age rating, IAP
  screenshots.
- **Criticality:** Critical before public.
- **Dependency:** Commercial + legal + screenshots.
- **Evidence:** iOS bundle `uk.cohortperformance.cohort`;
  `PUBLIC_LAUNCH_READY=false`; no store metadata pack in-repo.
- **Milestone:** Commercial + public launch gate.
- **Exit:** Submission assets complete; sandbox IAP reviewed.

#### 34. Programme library depth

- **Authority:** Field Manual published: Apollo v2, Spartan v3. 132-row
  exercise catalogue. Plan Package v1 **without** exercise IDs.
- **Readiness:** Prototype-only vs 8–12 families.
- **Gaps:** See §4. Two programmes ≠ a launch library.
- **Criticality:** Critical.
- **Dependency:** Founder authorship; M9 publish; quality gate.
- **Evidence:** Two manifests; reconstruction jobs 0.
- **Milestone:** Launch programme library.
- **Exit:** 8–12 families pass the quality gate; each is an immutable
  published version with a content-graph manifest.

#### 35. Beta / distribution tooling

- **Authority:** Founder phone sideload / local install; no TestFlight
  programme documented in-repo.
- **Readiness:** Prototype-only.
- **Gaps:** TestFlight/Play internal, crash groups, feedback forms.
- **Criticality:** High before 5–10 trusted athletes.
- **Dependency:** Apple/Google accounts.
- **Evidence:** Build 7; no CI distribute pipeline claimed here.
- **Milestone:** Beta and launch gates.
- **Exit:** Stage 2 athletes install without a founder laptop.

---

## 3. Launch athlete

### Primary launch user

An **individual hybrid athlete** who trains strength and endurance, may be
preparing for HYROX or general hybrid performance, wants a complete authored
plan, wants schedule flexibility without losing programme intent, wants
previous-performance guidance and understandable progress, may use a
watch/health platform, and **does not require an assigned coach**.

### Boundaries

| Band | Include | Exclude |
|------|---------|---------|
| Beginner | New to concurrent training; can jog/run easy ~20–30 min; can squat, hinge, push, pull with coaching; no current injury needing clinical rehab | First-ever gym session with zero movement competence; return-to-sport rehab |
| Intermediate | ≥ ~6 months consistent training or a prior HYROX / similar finish; 4+ days/week available | Specialists who refuse one discipline |
| Advanced | Race-specific; high load tolerance; sub-75 / sub-60 pathway **if** the family exists and is tested | Elite qualification coaching as a service |

### Supported at launch (intent)

| Dimension | Launch support |
|-----------|----------------|
| Goals | General hybrid performance; HYROX race (selected distances/lengths); running-quality for hybrid; strength-quality for runners |
| Equipment | Full gym; limited gym; home dumbbell/kettlebell **as authored variants**, not dynamic invention |
| Frequency | Typically 3–6 sessions/week as authored |
| Duration | Primary 8–12 weeks; 6-week race-specific where a family earns it |
| Regions / platforms | English; iOS first; timezones already required by calendar; Android after iOS journey proof |
| Coach | Not required; M10 unused |

### Not yet served

Youth athletes; pregnancy-specific programming; clinical rehab; coach-led
teams; marketplace coaching; Build Your Own; ultra/trail-only; powerlifting
meet prep; B2B/white label; non-English; athletes who need a human coach in
the loop to train safely.

Cohort does **not** claim to serve every athlete at launch.

---

## 4. Launch programme library

Target **approximately 8–12 programme families**, with structured variants
only when prescription, volume, or equipment **actually differ**. Do not pad
the catalogue with title-only clones.

Assessments, transitions, and deloads are **structured weeks inside
families**, not separate SKUs, unless a standalone deload product later
earns a slot.

### Quality gate (every published family)

Complete authored progression · canonical `EX-*` exercises · structured
prescriptions · substitutions · adaptation policy · test/assessment weeks ·
truthful progress evidence · exercise demonstrations (owned or licensed) ·
editorial review · technical compilation · real-world testing · published
immutable version · content-graph manifest · programme-support documentation.

Plan Package v1 remains frozen (no manufactured exercise-ID dependency).
Graph manifests stay derived. Identity mapping stays founder-approved.

### Proposed families

| Family | Target | Prerequisite | Goal | Duration | d/w | Formats | Equipment | Assessment | Progression | Adaptation | Evidence | Media | Variants | vs BYO later | Priority |
|--------|--------|--------------|------|----------|-----|---------|-----------|------------|-------------|------------|----------|-------|----------|--------------|----------|
| Hybrid Foundation | Beginner hybrid | Movement competence | Concurrent base | 12w | 4 | Strength, easy run, cond., mobility | Full or limited gym | Wk 1 + mid + end | Linear then wave | Time, kit, miss | Completion + selected lifts/runs | High-use lifts + run A | Full / limited kit | Component source | **Launch** |
| HYROX Foundation | Beginner race | Foundation or equivalent | First HYROX finish | 12w | 4–5 | Strength, run, station cond., brick | Gym + sled/row/ski **or** substitutes | Race sim + stations | Race-specificity ↑ | Event date, miss, kit | Station + run facts | Stations + running | 8w compress if tested | Race template | **Launch** |
| HYROX Intermediate | Intermediate | Prior finish or Foundation | Faster finish | 12w | 5 | Higher run + stations | Full HYROX-like | Timed sims | Performance-based | Fatigue, strong week | Comparable sims | Same + intensity | Event-date length | Race template | **Launch** |
| HYROX Advanced / sub-60 | Advanced | Proven intermediate | Sub-60 pathway | 12w | 5–6 | High specificity | Full | Frequent sims | Aggressive only with evidence | Must fail closed if recovery poor | High comparability | Full station set | Reject if untested | Later | **Post-launch** until quality gate |
| Hybrid Strength Emphasis | Intermediate | Foundation | Strength up, run maintained | 12w | 4–5 | Strength-primary, run maintenance | Full gym | Lift tests + easy run | Strength block | Kit, time | Lift comparability | Strength-heavy | Home DB variant if authored | Strength block kit | **Launch** |
| Hybrid Endurance Emphasis | Intermediate | Foundation | Run/endurance up | 12w | 4–5 | Run/endurance-primary | Gym + run | Time trials | Endurance block | Volume, event | Run facts | Run + strength maintain | Treadmill notes | Endurance kit | **Launch** |
| Running Development (hybrid) | Beginner–int. | Can run 20–30 min | Economy + volume for hybrid | 8–12w | 3–5 | Easy, intervals, long, strength maintain | Run + minimal gym | 5k / easy-pace | Run progression | Missed runs, time | Pace/distance | Run drills | 3 vs 4 run days | Run components | **Launch** |
| Strength for runners | Runner / endurance | Run habit, low strength | Injury-resilient strength | 8–12w | 3–4 | Strength + easy run | Gym or home | Lift standards | Conservative | Pain, kit | Lift + adherence | Technique-sensitive | Home vs gym | Strength components | **Launch** |
| Tactical / hybrid conditioning | Intermediate | Foundation | Work capacity | 8w | 4 | Circuits, carries, intervals | Gym / field | Work-capacity tests | Density | Kit, fatigue | Circuit scores | Carries/circuits | Reject if overlaps HYROX | Cond. kit | **Post-launch** if distinct |
| Mobility / recovery support | All launch users | Enrolled in a primary family | Recovery quality | 4–8w companion or embedded | 2–3 + inside plans | Mobility, breathe, walk | Minimal | Check-ins not fake PRs | Not load progression | Poor recovery trigger | Adherence only | Setup/cautions | Embedded preferred | Recovery blocks | **Launch** (embedded; standalone only if it stays a real product) |

**Reject:** title-only “HYROX but Tuesday start”; untested sub-60; AI-assembled
hybrids; programmes that cannot name substitutions and assessment weeks.

Race-specific lengths (6/8/12) are **authored variants** of a family, not new
families, and only when volume and key sessions are rewritten — not scaled in
the client.

### Relationship to Build Your Own (Phase B)

Launch families become the **approved component library**. BYO later
assembles from those components with progression/recovery constraints. It
does not invent sessions the quality gate never saw.

---

## 5. Athlete Experience Completion milestone

Complete journey (every step needs happy, loading, empty, offline, error,
accessibility, analytics, support, exit).

| Step | Screen / state | Happy path | Loading / empty / offline / error | A11y | Analytics (intent) | Support | Exit |
|------|----------------|------------|-----------------------------------|------|--------------------|---------|------|
| 1 Discover | Website / store (later) | Understand hybrid offer | Offline site; region | Store a11y | `app_store_view` | Site FAQ | Honest positioning live |
| 2 Create account | Sign up / verify | Email verify → shell | Exists, invalid, offline | Labels on fields | `sign_up_*` | Auth help | Session persisted |
| 3 Onboard | Onboarding graph | Inputs saved | Skip later? insufficient | Grouped fields | `onboarding_*` | Why we ask | Structured profile |
| 4 Recommend | Recommendation | Best family + why | No match | Why not colour | `recommend_*` | Change plan | Override allowed |
| 5 Compare / select | Catalogue + detail | Choose version | Empty catalogue | List semantics | `catalogue_*` | Fit help | Exact version chosen |
| 6 Enrol + schedule | Enrol + days | Pin + occurrences | Conflict, entitlement | Date widgets | `enrol_*` | Schedule help | One active pin |
| 7 Understand today | Home | Do / rest / done | No programme; offline | Today label | `home_today_*` | What’s due | Today-only |
| 8 Prepare / adapt | Overview + Adapt | Start or accepted adapt | Ineligible adapt | Proposal text | `adapt_*` | Why adapt | Accept/decline audited |
| 9 Perform | Format player | Capture actuals | Timer fail; background | Timer a11y | `session_start/progress` | Form help | Prescription unchanged unless accepted |
| 10 Save / recover | Complete / draft | Durable results | Crash, 409, offline | Confirm | `session_complete_*` | Lost workout | No duplicate session |
| 11 Missed / disrupted | Calendar | Move/skip/adapt | Multi-miss | Status text | `schedule_*` | Caught up? | No fabricated complete |
| 12 Review progress | Progress | Facts + trends | Insufficient evidence | Radar hidden | `progress_*` | What improved | No false PR |
| 13 Complete programme | Progress + Home | Completion state | Failed write | Status text | `programme_complete` | What’s next | Cursor honest |
| 14 Next programme | Catalogue | Re-enrol | Still pinned | | `reenrol_*` | Deload? | New pin explicit |
| 15 Subscription / account | Profile | Manage / delete | Billing error | | `billing_*` `account_*` | Cancel help | Legal + restore |

Home remains today-only. Calendar owns schedule. Progress owns history.
Programmes owns discovery. Profile owns account/help/settings.

---

## 6. Adaptation Engine milestone

### Launch-critical triggers

Missed session · multiple incompletes · changed training day · changed event
date · shortened time · unavailable equipment · exercise substitution ·
pain/movement restriction · poor recovery · accumulated fatigue · repeated
underperformance · unexpectedly strong performance · travel/disrupted
schedule · programme pause/return · deload recommendation.

### Contract (every adaptation)

1. Detect evidence
2. Explain why it matters
3. Propose a specific adjustment
4. Preview consequences
5. Athlete accepts or declines
6. Apply atomically to the **current prepared executable session** (or
   explicit schedule operation when the change is placement — scheduling
   remains Sprint 1.7 authority, not silent adaptation)
7. Audit the decision
8. Support reversal where safe

**Never** auto-apply. **Never** punish or use failure language. **Never**
invent coaching outside authorised content. Dismissal is a durable no-op.

### Design rules

| Topic | Launch v1 |
|-------|-----------|
| Evidence inputs | Schedule dispositions, actuals, athlete-declared reasons, later wearable **signals** (never sole auto-trigger) |
| Authored constraints | Adaptation metadata on package; missing metadata fails closed |
| Key sessions | Race sims / tests not silently dropped |
| Recovery spacing | Preserve authored rest; do not stack key sessions |
| Progression preservation | Do not “make up” volume that breaks the next key session |
| Race-specificity | Event-date change may propose a published variant or honest insufficient |
| Confidence | Insufficient evidence → explain and offer keep-original |
| Later (not v1) | Multi-week reperiodisation, generative swaps, coach-in-the-loop review |

Changed **training day** is primarily a **schedule** operation. Adaptation
may propose content change if the new day breaks recovery spacing.

---

## 7. Progression and tracking milestone

### Evidence hierarchy (strict)

1. Participation
2. Completion / adherence (sessions **due**, not rest)
3. Performance facts
4. Comparable performance
5. Personal best (same test, conditions)
6. Improvement / regression (requires 4)
7. Capability evidence (requires repeated comparable facts)
8. Insufficient evidence (default honest state)

Cover strength, running, steady-state, intervals, EMOM, circuits, for-time,
AMRAP, mobility/recovery (adherence, not fake load PRs), assessments,
programme completion.

### Rules

- **Comparability:** same movement identity, format, and enough shared
  constraints; document exceptions.
- **Chronology:** scheduled ≠ performed ≠ recorded (`entry_mode`,
  `performed_on`).
- **Backfill:** visible as recorded later; not a live PR without label.
- **Corrections:** audited; may break comparability.
- **First performance:** no previous; no implied target beyond authored.
- **Mixed performance:** do not average incompatible scores into a PR.
- **No false capability.**
- **Radar:** omit until axis rules pass.
- **Summaries:** weekly and end-of-programme reviews from this hierarchy.
- **Validation:** 6–12 weeks real-world on launch families before public
  claims.

### Deferred capability — Athlete-defined Performance Portfolio

Recorded at Daily Journey closeout. **Not authorised for implementation
now.** Binding:
[`../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md).

Athletes may later track Cohort-authored HYROX / Hybrid / Tactical packs
**and** athlete-created metric portfolios (name, protocol, unit, direction,
baseline, current, personal best, target, history, optional category,
configurable radar, coverage, later neglected-capability suggestions).

Integrity (must survive any later design):

1. Incompatible units must never share one raw radar axis system.
2. Radar values require an explicit normalisation model.
3. Training coverage and measured performance change are separate.
4. Sessions targeting a capability are not proof of improvement.
5. Programme-to-metric links must be authored / canonical, not name
   similarity or unconstrained AI inference.
6. History stays truthful when portfolios change.
7. User-created metrics must not alter canonical programme content.

Do not implement schema, UI, radar maths, or mappings in this closeout.

---

## 8. Exercise knowledge and media milestone

Canonical layer: identity · aliases · pattern · equipment · setup ·
execution · cues · errors · substitutions · regression/progression ·
cautions · demo media · thumbnail · aspect/duration · licensing ·
offline/cache · version history.

Programmes model **exercise identity**, not media URL. Media may be replaced
without rewriting programme history.

### Owned filming library

- Derive shot list from **launch** families (not the whole 132-row
  catalogue).
- Target **~60–100** high-use, technique-sensitive, or Cohort-specific
  movements.
- Licensed fallback only where commercially safe.
- Workflow: shot list → film → edit → QA (identity, cues, safety) → upload
  → version → app cache policy → replace-in-place.

Phase 3.2D pilot remains local/in-memory. Production composition is this
milestone, under new authority — not a silent Phase 3.2E start.

---

## 9. Wearables and integration milestone

Treat integrations as **launch-critical research + implementation**, not
marketing promises.

| Surface | Plan | Verification status |
|---------|------|---------------------|
| Apple Health / HealthKit | Primary iOS research; workout write + read HR/workouts | **Unverified** in-repo |
| Health Connect | Android counterpart | Unverified |
| Garmin | Import activities / HR; **commercial API access** may be required | Unverified; mark vendor lead time |
| WHOOP or equivalent | Recovery/sleep/HRV if commercially available | Unverified; do not promise |
| Session export | Write Cohort workout to Health | After HealthKit spike |
| Activity import | Dedupe vs prescribed session | After spike |
| HR, pace, distance | Import with source labels | After spike |
| Sleep, HRV, RHR, readiness | Evidence for **proposals only** | After spike |
| VO2 max | Display only if vendor reliability documented | Likely later |
| Calendars | Optional; timezone explicit | Research |
| Notifications | Local first | Missing |

### Platform rules

Source-of-truth precedence (proposal): **authored prescription** >
**athlete-confirmed in-app actuals** > **imported activity** (labelled) >
**inferred wearable**. Permission lifecycle and revocation must be visible.
Duplicates detected by time window + type. Reconciliation never silently
overwrites in-app confirmed sets. Timezone = occurrence local date.
Offline retry + background sync with rate limits. Retention/privacy in
legal. Stale/missing data explained. **Never auto-apply adaptation.**

---

## 10. Onboarding and personalisation milestone

Inputs: goal · experience · training background · event type/date ·
days/week · preferred days · session duration · equipment · running volume ·
strength experience · limitations · recovery constraints.

Launch personalisation **recommends the best authored programme/variant**.
It does **not** dynamically assemble an unverified bespoke plan.

- Recommendation: deterministic mapping from inputs → family/variant with
  reasons.
- Manual override: full catalogue.
- Insufficient match: say so; offer closest + constraints.
- Schedule setup immediately after enrol.
- Later BYO migration: reuse the same inputs; do not re-invent identity.

---

## 11. Commercial and operational milestone

Define (no **final pricing** without founder approval):

Subscription tiers · trial · entitlement · purchase/restore · cancellation ·
account deletion · data export · privacy/terms/consent · analytics · crash
reporting · feature flags · help centre · feedback · incident response ·
backups/recovery · admin ops · store requirements · product website ·
onboarding communications · customer lifecycle.

Founder dogfood may remain entitlement-free. Public launch may not.

---

## 12. Beta and launch gates

| Stage | Entry | Personas / devices | Programmes | Duration | Metrics | Feedback | Bug bar | Data-loss | Crash-free | Retention | Exit | Rollback |
|-------|-------|--------------------|------------|----------|---------|----------|---------|-----------|------------|-----------|------|----------|
| 1 Founder dogfood | M10 closed; Experience slice usable | Founder iPhone build N | Apollo/Spartan then new families | Continuous | Complete sessions / week | Direct | No P0 | Zero known | Subjective | Adherence | Slice exit criteria | Revert app; DB forward-only |
| 2 Trusted 5–10 | Stage 1 exit; TestFlight | Hybrid beginners/int.; iOS | ≥ 2 launch families | 4+ weeks | Completion, crashes | Interview + notes | No P0; limited P1 | Zero | ≥ ~99% sessions* | Week-4 return | Written issues closed | Disable build |
| 3 Structured 25–50 | Stage 2; analytics on | Mix + 1 Android later | ≥ 50% launch library | 6+ weeks | Funnels | Form + reports | No launch-blockers | Zero | Target written | D30 signal | Gate review | Flag off |
| 4 Launch-candidate 100–250 | Stage 3; IAP sandbox | Broader hybrid | Full launch library | 6–12 weeks | Store-like | Support queue | Public bar | Zero | Public bar | D30/D60 | Launch review | Store halt |
| 5 Public athlete | Stage 4 + public gates | Individual hybrid | Gated library | — | Business + quality | Support | Public bar | Zero | Public bar | — | Ship | Incident plan |

\*Crash-free percentages are **targets to set after observability exists**,
not current measurements.

### Public launch gates

No known data-loss · no programme-blocking defect · acceptable crash-free
rate · drafts/recovery proven · adaptation explanations validated ·
progression claims trustworthy · launch programmes tested · integrations
stable · subscriptions tested · account deletion/export working ·
support/incident capability · accessibility review · performance budget ·
privacy/security review · store assets ready.

---

## 13. Post-launch sequence (locked)

| Phase | Name | Not before |
|-------|------|------------|
| **A** | Athlete launch | This plan’s public gates |
| **B** | Build Your Own Programme | Phase A |
| **C** | Coaching / publisher product | Phase B |
| **D** | B2B / B2B2C / white label | Phase C |

**Build Your Own** must assemble from approved authored components; respect
programme/session/exercise relationships; preserve progression/recovery;
explain structure; create a versioned immutable plan; avoid unconstrained AI
workout invention.

**Coaching platform later:** invitations/consent · roster · assignment ·
monitoring · authoring/publishing · adaptation review · messaging · teams ·
billing · analytics · white labelling. M10 schema exists; product is frozen.

---

## 14. Prioritised implementation roadmap

Effort bands: **XS / S / M / L / XL**. No false dates.

| ID | Milestone | Outcome | Workstreams | Deps | User value | Tech risk | Content risk | External | Founder input | Tests | Preview/beta | Hosted migration | Phone | Exit | Deferred | Effort |
|----|-----------|---------|-------------|------|------------|-----------|--------------|----------|---------------|-------|--------------|------------------|-------|------|----------|--------|
| M-AEC | Athlete Experience Completion | Remaining athlete-experience quality after Daily Journey close | Remaining Home/Calendar polish; **close leftover guest + Coach Brain generate paths**; hide coach chrome; programme comparison only after audit | M10 closed; DJ closed | Immediate | Medium | Low | — | Copy/design | Focused Flutter + device | Founder dogfood | Unlikely | Likely | §5 exits for remaining 6–14 | Coach UI; preview players as second authority | **L–XL** |
| M-LIB | Launch programme library | 8–12 families through quality gate | Authorship, compile, manifest, editorial | M9; exercises | Core offer | Medium | **High** | Filming later | Every family | Import + graph tests | Founder then 5–10 | Publish only when approved | After content | Quality gate | Sub-60 until ready | **XL** |
| M-ADP | Adaptation Engine v1 | All launch triggers on contract | Evidence, UI, metadata, audit | AEC; metadata | Trust | High | Medium | Wearables later as signals | Copy tone | Adaptation + a11y | Dogfood + 5–10 | Only if audit tables needed | Yes | §6 | Multi-week AI | **L–XL** |
| M-PRG | Progression & tracking | Honest hierarchy in Progress | Comparability, reviews, radar rules | AEC; actuals | Trust | Medium | Medium | — | What “better” means | Progress tests + 6–12w | 5–10 / 25–50 | Unlikely | Yes | §7 | Fancy social PRs | **L** |
| M-MED | Exercise knowledge / media | 60–100 demos on identities | Film, player, cache, QA | LIB shot list | Quality | Medium | **High** | Licensing | Shot approval | Player + offline | After first films | Media storage TBD | Yes | §8 | Full 132 film | **XL** |
| M-INT | Wearables & integrations | Verified import/export | Research spike then HealthKit first | AEC | Hybrid truth | **High** | Low | Apple/Garmin/WHOOP | Vendor spend | Contract tests; **no exploit PoCs** | Device matrix | Possibly | Yes | §9; unverified = not promised | Exotic VO2 | **L–XL** |
| M-ONB | Onboarding & matching | Recommend authored variant | Graph, mapping, override | LIB metadata | Activation | Medium | Medium | — | Question set | Mapping tests | 5–10 | Profile columns maybe | Yes | §10 | BYO assembly | **M–L** |
| M-COM | Commercial & operations | Pay, legal, support, telemetry | IAP, deletion, flags, Sentry | Privacy | Scale | High | Low | Stores, legal | **Pricing** | Store sandbox | Stage 3–4 | Entitlements | Yes | §11 | Complex plans | **L–XL** |
| M-BET | Staged betas | Stages 1–4 | Distro, metrics, support | Prior | Learning | Medium | Medium | TestFlight | Criteria | Crash + funnel | Yes | No | Yes | Stage exits | Public ads | **M** (ongoing) |
| M-PUB | Public athlete launch | Phase A | Stores, comms, incident | All gates | Revenue | High | High | Apple/Google | Go/no-go | Gate checklist | Stage 4 | Production ops | Release | §12 public gates | Coach | **L** |

### Critical path

`M-AEC` (Daily Journey Integrity **closed**; Complete Athlete Experience
**complete** at `fc73ae0`; next `M-LIB` strategy approved,
infrastructure approved, Studio Stage 1 COMPLETE, Sprint B1 approved
not started; B2–D not authorised)
→ (`M-LIB` parallel with founder authorship) → `M-ADP` + `M-PRG` →
`M-MED` (film parallel earlier) → `M-INT` (research **now**) → `M-ONB` →
`M-COM` → `M-BET` → `M-PUB`.

### Parallelisable now

- Founder: family specs, editorial voice, pricing **research**, legal
  counsel, store account hygiene, HYROX/equipment decisions.
- Content: shot list from Apollo/Spartan + draft families; film planning.
- External: HealthKit entitlement research; Garmin/WHOOP access lead times.

### Decide early

iOS-first confirmation · HYROX equipment substitution policy · whether
standalone mobility SKU exists · radar hidden-until-honest · first wearable
vendor · deletion SLA · crash vendor.

### Wait

Coach invitations UX · roster assignment · messaging · BYO · B2B · Phase
3.2E as a numbered science project · Plan Package v2 exercise IDs · Product-
UI Gate 2 as a substitute for this plan · hosted consent smoke.

---

## 15. Readiness scorecard

Bands, not false precision. Evidence date: 2026-09-20 repository + Field
Manual read-only confirmation.

| Theme | Band | Evidence | Largest gap | Next measurable gate |
|-------|------|----------|-------------|----------------------|
| Architecture / integrity | **70–85%** | Freeze, Programme Athlete runtime, M9/M10 hosted, atomic resume | Athlete-facing complexity still leaks in places | AEC: no dual authority regressions |
| Workout execution | **55–70%** | Production `ActiveSessionScreen` capture; dedicated modality views are preview | Dual player stacks; outdoor run + watch | One launcher path; device complete-session matrix |
| Daily athlete experience | **50–65%** | Today-only Home, dogfood | Guest/local bypass; premium empty/error/offline | Auth-required shell; every today state has next action |
| Calendar / recovery | **65–80%** | Month grid, Incomplete, Train today | Pause/event-date | Multi-incomplete + move without data loss |
| Progression | **35–50%** | Previous performance; partial comparisons | Honest reviews + radar rules | Insufficient-evidence default in UI |
| Adaptation | **35–50%** | Day-of accept-gate is real; many §6 triggers are not | Trigger coverage | All v1 triggers on 8-step contract |
| Programme library | **15–30%** | Two published programmes | 8–12 gated families | First new family through quality gate |
| Exercise knowledge / media | **10–25%** | Identities + text pilot | Film + production UI | Shot list locked; 10 exercises filmed |
| Wearables / integrations | **0–10%** | No packages | All vendors unverified | Written HealthKit spike result |
| Onboarding | **15–30%** | Local START TRAINING can still generate Coach Brain plans | Authored recommendation; kill generative path | Mapping table on real families; no generative Home |
| Commercial systems | **0–15%** | Explicitly non-commercial enrol | Entire stack | Sandbox IAP + deletion |
| Beta / operations | **15–30%** | Founder build 7 | Distro + observability | TestFlight + crash reporting |

---

## 16. Decision filter (permanent)

Before work enters the athlete-launch roadmap, ask:

1. Does it materially improve the athlete experience or required launch platform?
2. Is it on the athlete-launch critical path?
3. Does it reuse canonical architecture?
4. Can an athlete understand it without founder explanation?
5. Is it trustworthy enough for years of history?
6. Does it meet an elite funded-product quality bar?
7. Should it be built now or deferred to Build Your Own / coaching?

If the answer to 7 is “defer”, it does not enter M-AEC–M-PUB except as an
explicit footnote.

---

## 17. Immediate next sprint (recommendation only)

Daily Journey Integrity is **COMPLETE**. Binding:
[`../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](../checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md).

Complete Athlete Experience is **complete**. Closeout:
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md).
Sprint 1 `a3cd351`, Sprint 2 `8405421`, Sprint 3 `8dcf58e`, cleanup
`fc73ae0`. Binding:
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md),
[`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md).

```text
DAILY_JOURNEY_INTEGRITY=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE
HOSTED_MIGRATION_APPLIED=true
SPRINT_2_HOSTED_MIGRATION_APPLIED=true
SPRINT_3_HOSTED_MIGRATION_APPLIED=true
NEXT_MILESTONE=LAUNCH_PROGRAMME_LIBRARY
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=B1_COMPLETE
RUNNING_WORKOUT_B1=COMPLETE
LEE_BALI_HYBRID_BASE=INFRASTRUCTURE_IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

The next sequenced item is **launch programme library**. Strategy and
infrastructure architecture are **approved**. Programme Studio Stage 1
is **COMPLETE**. Sprint B1 is **COMPLETE**. Private programme
infrastructure is **implemented, awaiting founder approval**. Binding:
[`../checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md`](../checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md),
[`../checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md`](../checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md),
[`../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md`](../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md),
[`../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md`](../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md),
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md),
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md).
B2–D remain unauthorised. This does
**not** make Cohort launch-ready.
Active-programme replacement remains future work.

**Standalone WOD Timer and Whiteboard** is a pre-launch utility candidate
**after** the core athlete journey is complete. Do not promote it ahead of
remaining AEC sequencing without a later founder decision.

**Athlete-defined Performance Portfolio** belongs to **Progression and
tracking** (`M-PRG`). Not this closeout.

Out of scope now: M10 Sprint 3, programme comparison implementation,
Android release, wearables, offline completion queue, blue brand, Field
Manual mutation, treating preview players as production authority.

Scores are not Complete.
