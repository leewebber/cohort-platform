# Phase 2 Compatibility-Path Retirement Decision v1

**Status:** Binding architecture decision for Phase 2.5+  
**Sprint:** Phase 2.5 — Remaining Runtime Caller Inventory and Compatibility-Path Retirement Decision  
**Recorded at:** HEAD preceding this decision commit (baseline `66f14d5`)  
**Decision:**

```text
LEGACY_RUNTIME_DECISION=RETIRE
LEGACY_RUNTIME_DELETED=false
CALLER_MIGRATION_EXECUTED=false
```

`RETIRE` authorises subsequent tightly scoped migration sprints. It does **not**
authorise deletion in Phase 2.5.

Companion contracts:
[`Athlete_Home_Runtime_Authority_v1.md`](./Athlete_Home_Runtime_Authority_v1.md),
[`Phase_2_Consolidation_Safety_Gate_v1.md`](./Phase_2_Consolidation_Safety_Gate_v1.md),
Phase 1 programme / materialisation / acceptance-gated adaptation contracts.

---

## 1. Product constraint (V1)

```text
founder-authored programmes
→ catalogue
→ athlete selects/downloads programme
→ programme is materialised
→ athlete executes authored programme
→ athlete-entered results are recorded
→ descriptive progress/reference
→ policy-gated adaptations require athlete agreement
```

The athlete does not construct a programme. Founder-only **authoring** is not a
founder-only athlete runtime. Coach Brain must not regain authority to rewrite
authored programme intent.

---

## 2. Architectural presumption tested

Working presumption:

```text
Plan Library / Coach Brain should ultimately be retired
as an athlete-facing runtime compatibility path
```

Repository evidence supports that presumption. No concrete current V1 product
capability requires a permanent second athlete runtime.

---

## 3. Remaining caller / runtime graph

### Product shell reachability

```text
AthleteAppShell
├── Home  → AthleteHomeRuntimeAuthorityResolver (Phase 2.4)
│   ├── programme     → AthleteProgrammeTodaySection → ProgrammeAdaptFlow
│   ├── legacyPlanCompatibility → DailyBriefingSection + HomeAdaptFlow
│   ├── loading / unavailable → no adapt activation
│   └── none → ChoosePlanEntryCard → AthleteProgrammeScreen
├── Plans (tab) → PlanLibraryScreen → PlanDetailScreen → PlanStartService
│                 *** still creates new legacy hasActivePlan state ***
├── Progress → ProgressSummaryService (Plan Library–shaped)
└── Profile
```

Founder shell can also open `PlanLibraryScreen` (`founder_workspace_shell.dart`).

### Caller inventory (primary production symbols)

| Caller/symbol | Entry point | Responsibility | Runtime reachable? | Authority implication | Replacement / canonical equivalent | Classification |
| ------------- | ----------- | -------------- | ------------------ | --------------------- | ---------------------------------- | -------------- |
| `AthleteHomeRuntimeAuthorityResolver` | `HomeScreen` | Pure Home authority classification | Yes | Chooses programme vs legacy vs none/loading/unavailable | — (decision owner) | CANONICAL_PROGRAMME |
| `AthleteProgrammeTodaySection` / `ProgrammeAdaptFlow` | Home `programme` | Today + acceptance-gated adapt | Yes | Canonical programme runtime | — | CANONICAL_PROGRAMME |
| `AthleteProgrammeSessionPrepareService` | Home today, controllers, adapt accept/revert | Deterministic prepare/restore from materialised assignment | Yes | Canonical prepare | — | CANONICAL_PROGRAMME |
| `TodaySessionService` / Impl | Loaders, progression | Resolve today from programme assignment | Indirect | Canonical schedule resolve | — | CANONICAL_PROGRAMME |
| `ProgrammeAssignment` + stores | Home gate, prepare, materialisation, progression | Hosted enrolment/materialisation | Yes | Canonical persistence | — | CANONICAL_PROGRAMME |
| `AthleteProgrammeCompletionService` | Performance save coordinator; staging | Atomic complete + advance | Shell path partially unmounted | Canonical completion | Wire product finish onto this path | CANONICAL_PROGRAMME |
| `ProgrammeProgressSummaryService` | HomeTodaySessionLoader / programme models | Programme progress summary | Indirect | Canonical progress facts | Progress tab should consume this | CANONICAL_PROGRAMME |
| `AthletePlanMaterialisationService` | `AthleteProgrammeScreen` Start Programme | Materialise enrolled assignment; client legacy preflight | Yes | Bridge + conflict gate | Keep bridge; retire preflight after legacy starts removed | MATERIALISATION_BRIDGE |
| `HomeAdaptFlow` | Home `legacyPlanCompatibility` only | Legacy Adapt sheet → evaluate → commit | Yes (entry); success UNCERTAIN | Legacy day-of adapt | `ProgrammeAdaptFlow` | LEGACY_RUNTIME |
| `DailyBriefingSection` / `DailyBriefingService` | Home `legacyPlanCompatibility` | Legacy today briefing + execute | Yes | Reads Coach Brain / Plan Library session | `AthleteProgrammeTodaySection` | LEGACY_UI / LEGACY_RUNTIME |
| `PlanLibraryScreen` / `PlanDetailScreen` | Athlete shell Plans tab; founder shell | Browse/start Plan Library plans | Yes | Creates legacy runtime | `AthleteProgrammeScreen` catalogue | LEGACY_UI |
| `PlanStartService` / `PlanAssignmentService` | Plan detail Start | Assign plan + Coach Brain prepare | Yes | Writes local PlanAssignment + session | Enrol + materialise + prepare | LEGACY_RUNTIME |
| `PlanDefinition` / `PlanCatalog` | Plan screens, progress labels, hydrator | Static Plan Library catalogue | Yes | Legacy catalogue | Authored Plan Package catalogue | LEGACY_RUNTIME |
| `AthleteProfileSession.hasActivePlan` | Home, workout complete, materialisation, briefing, progress, adapt | In-memory legacy “active plan” signal | Yes | Legacy eligibility | `ProgrammeAssignment.isMaterialised` | LEGACY_RUNTIME |
| `AthleteProgrammeGenerationService` | PlanStart, AdaptiveProgression, hydrator, onboarding | Coach Brain prepareExecution | Yes | Legacy generative prepare | `AthleteProgrammeSessionPrepareService` | LEGACY_RUNTIME |
| `CoachBrainWorkoutPlanService` (resolve) | Generation / overview / plan start | Generative resolve | Yes (legacy) | Legacy generative authority | Authored `SessionExecutionLoader` | LEGACY_RUNTIME |
| `CoachBrainWorkoutPlan` (DTO) | Canonical `toOpenablePlan` + legacy | Openable plan shape for Workout Player | Yes | Shared transport type | Retain as SHARED_NEUTRAL until rename sprint | SHARED_NEUTRAL |
| `ProgrammedSessionResolver` | Generation / PlanStart | Plan-canonical generative resolve | Yes (legacy) | Legacy prepare | `AthleteProgrammeAuthoredSlotResolver` | LEGACY_RUNTIME |
| `AdaptiveProgressionCoordinator` | `WorkoutCompleteScreen` when `hasActivePlan` | Post-complete plan advance + regenerate | Yes (legacy complete) | Auto progression rewrite | Programme cursor advance via completion RPC; no auto adapt rewrite | LEGACY_RUNTIME |
| `WorkoutCompleteScreen` | Workout Player finish | Dual bookkeeping + `hasActivePlan` adapt gate | Yes (programme and legacy execute) | Mixed authority | Finish review + `AthleteProgrammeCompletionService`; never AdaptiveProgression for programme athletes | LEGACY_RUNTIME + CANONICAL_PROGRAMME (split) |
| `WorkoutPlayerLauncher` | Programme today, DailyBriefing | Navigate Overview→Player→Complete | Yes | Passes optional `programmeContext` | Retain | SHARED_NEUTRAL |
| `HomeTodaySessionLoader` | HomeAdaptFlow; quarantined section | Programme-first today load | Indirect | Canonical loader used by legacy adapt | Programme Home uses prepare service directly | CANONICAL_PROGRAMME (loader) |
| `HomeTodaySessionSection` | **No production mount** | Quarantined today card | No (product UI) | Documented quarantine | `AthleteProgrammeTodaySection` | PROVEN_UNREACHABLE |
| `AthleteGeneratedTodaySection` | **No production mount** (tests) | Legacy today card | No (product UI) | Legacy card dead | Programme today | PROVEN_UNREACHABLE |
| `ChoosePlanEntryCard` | Home `none` | Empty-state → programme catalogue | Yes | Neutral entry | Already points at Programme | SHARED_NEUTRAL |
| `PreparedExecutionReverter` | WorkoutOverview | Legacy revert via Coach Brain regenerate | Yes if legacy adapted session opened | Legacy | `ProgrammeAdaptationReversionService` | LEGACY_RUNTIME |
| `AthleteOnboardingFlow` | Login | Profile → Coach Brain generate | Yes | Generative bind; may not set `hasActivePlan` | Catalogue enrol path | LEGACY_RUNTIME / UNCERTAIN product role |
| `ProgressScreen` + `ProgressSummaryService` | Athlete shell Progress tab | Plan Library–shaped progress | Yes | Reads PlanAssignment / PlanDefinition | `ProgrammeProgressSummaryService` | LEGACY_UI |
| `SessionOverviewScreen` | **No lib callers** | Alternate execution + atomic completion | No (shell) | Canonical-capable, unmounted | Target finish/execution wiring | PROVEN_UNREACHABLE (shell) |
| Staging `main_s13*` PlanLibrary probe; s14/s15/s17 programme | Staging entrypoints | Hosted verification | Tooling | Mix | Keep separate from product runtime | TOOLING_ONLY |

### Classification summary

| Class | Meaning in this decision |
|-------|--------------------------|
| CANONICAL_PROGRAMME | Keep; expand callers toward these |
| LEGACY_RUNTIME / LEGACY_UI | Retire via migration sequence |
| MATERIALISATION_BRIDGE | Keep Start Programme; retire only the legacy preflight once conflict class is empty |
| SHARED_NEUTRAL | Do not delete with Plan Library; rename later if needed |
| PROVEN_UNREACHABLE | Safe cleanup candidates after gate-green, not Phase 2.5 work |
| UNCERTAIN | Documented; do not delete until resolved in a migration sprint |

---

## 4. Detailed findings — Phase 2.4 known callers

### 4.1 `workout_complete_screen.dart`

| Question | Finding |
|----------|---------|
| Chooses runtime authority? | **Yes (partial)** — gates AdaptiveProgression on `hasActivePlan` |
| Reads legacy state? | Yes (`hasActivePlan`) |
| Mutates legacy state? | Yes when `hasActivePlan` → `AdaptiveProgressionCoordinator` |
| Reads canonical programme state? | Via optional `programmeContext` |
| Writes canonical programme state? | Via `WorkoutCompletionService` / progression when context present |
| Canonical equivalent? | `AthleteProgrammeCompletionService` / Self-Test 2 atomic path |
| Would removing legacy change intended V1? | Yes if still used for Plan Library athletes; for materialised athletes legacy adapt must not run |
| Migration required? | **Yes** |
| Invariants at risk | INV-02 completion authority; INV-09/12/14 adaptation; no unrelated mutation |

### 4.2 `daily_briefing_service.dart`

| Question | Finding |
|----------|---------|
| Chooses runtime authority? | No — Home already chose legacy |
| Reads legacy? | Yes (active plan / Coach Brain brief) |
| Mutates legacy? | No (read + launch) |
| Programme read/write? | No |
| Canonical equivalent? | `AthleteProgrammeTodaySection` + prepare service |
| Migration required? | **Yes** — retire with Home legacy branch |
| Invariants at risk | Authored prescription authority if briefing invents sessions |

### 4.3 `athlete_plan_materialisation_service.dart`

| Question | Finding |
|----------|---------|
| Chooses runtime authority? | **Conflict gate only** — blocks Start Programme when local `hasActivePlan` |
| Reads legacy? | Yes (flag only) |
| Mutates legacy? | No |
| Programme write? | Yes — materialises `programme_assignments` |
| Canonical equivalent? | **This service is the canonical Start Programme bridge** |
| Migration required? | Keep bridge; retire/replace preflight after Plans-tab starts removed |
| Do not delete as “legacy” merely because of “plan” naming | **Critical** — MATERIALISATION_BRIDGE |

### 4.4 Progress summary (`ProgressSummaryService` / `ProgressScreen`)

| Question | Finding |
|----------|---------|
| Chooses runtime authority? | Yes for empty-state (`hasActivePlan`) |
| Reads legacy? | Yes (PlanDefinition / PlanAssignment / SessionCompletionStore) |
| Programme path exists? | `ProgrammeProgressSummaryService` already exists |
| Migration required? | **Yes** — Progress tab still Plan-Library-shaped |
| Invariants at risk | INV-02 / descriptive progress; no prescription rewrite |

### 4.5 Plan Library (`PlanLibraryScreen`, `PlanStartService`, …)

| Question | Finding |
|----------|---------|
| Chooses / creates runtime? | **Yes** — Athlete shell Plans tab still starts plans |
| Distinct V1 capability? | **No** — catalogue is `AthleteProgrammeScreen` |
| Migration required? | **Yes** — stop new legacy starts first |
| Invariants at risk | Dual authority; materialisation conflict; Coach Brain prescription |

### 4.6 `HomeAdaptFlow`

| Question | Finding |
|----------|---------|
| Chooses runtime? | Requires `hasActivePlan`; only opened from legacy Home branch |
| Reads/writes? | Loads via `HomeTodaySessionLoader` (programme-first); commits via legacy adapt application |
| Success under only product entry? | **UNCERTAIN** — needs `HomeTodaySessionProgrammeExecutable`, which typically requires materialised programme; Home only opens this flow when **not** materialised |
| Canonical equivalent? | `ProgrammeAdaptFlow` |
| Migration required? | **Yes** — retire with legacy Home branch |

---

## 5. Today / session-preparation authority

| Responsibility | Canonical implementation | Legacy / parallel | Remaining callers | Migration needed? |
| -------------- | ------------------------ | ----------------- | ----------------- | ----------------- |
| Resolve today's session | `TodaySessionService` + `AthleteProgrammeSessionPrepareService` | `AthleteProfileSession.programme` + DailyBriefing | Home programme vs DailyBriefing | Yes — consolidate on prepare |
| Prepare session | Authored slot + `SessionExecutionLoader` | `AthleteProgrammeGenerationService` + `ProgrammedSessionResolver` + Coach Brain resolve | Programme today vs PlanStart / AdaptiveProgression / hydrator / onboarding | Yes |
| Restore / reconstruct | Prepare service local `generated_session` | `AthleteStateHydrator` Coach Brain reconstruct | Both write shared local key | Yes — avoid dual writers |
| Previous performance | `PreviousPerformanceFromResults` / stores | Same stores written from WorkoutComplete | SHARED_NEUTRAL storage | Writers must stay athlete-entered |
| Complete session | Intended: `AthleteProgrammeCompletionService`; Product: WorkoutComplete + `ProgrammeSessionProgressionCoordinator` when context set | SessionCompletionStore + AdaptiveProgression when `hasActivePlan` | WorkoutComplete (both) | Yes — unify finish path |
| Post-completion progression | Programme cursor advance via completion RPC; **no** auto adapt rewrite | `AdaptiveProgressionCoordinator.runAfterCompletion` | WorkoutComplete when `hasActivePlan` | Yes — retire auto rewrite |

`HomeTodaySessionSection` is quarantined / product-unmounted (PROVEN_UNREACHABLE). Do not treat it as a live competing today authority.

---

## 6. Persistence / data implications

| State | Storage | Notes |
|-------|---------|-------|
| Legacy `PlanAssignment` | **Local only** (`AthleteLocalRepository` / KV) | No Supabase Plan Library assignment table found |
| Legacy prepared session | Local `generated_session` | Also used by canonical prepare — collision risk if both paths write |
| `AthleteProfileSession` | Process memory | Bound by PlanStart / generation / hydrator |
| Completions / previous performance | Local KV | Shared |
| `ProgrammeAssignment` | Supabase `programme_assignments` | Canonical enrolment + materialisation |
| Materialisation | RPC/columns on `programme_assignments` | Does **not** import Plan Library assignments |

**Separate:**

```text
runtime retirement  ≠  data/schema deletion
```

After runtime retirement, local Plan Library keys and unused schema may remain
dormant until a separately authorised cleanup sprint. Do not assume persisted
legacy data can be deleted with the first runtime retire commit.

Relevant migrations (programme — retain): catalogue enrolment, materialisation,
complete-and-advance, schedule projection family. No Plan Library hosted schema
to drop for assignments.

---

## 7. Test ownership audit

| Bucket | Examples | Disposition |
|--------|----------|-------------|
| CONTRACT_MUST_SURVIVE | Consolidation safety gate; coaching integrity; programme adapt accept/revert/hardening; Self-Test 2; Home runtime authority tests; materialisation local tests; scheduling ownership | Keep / expand |
| MIGRATE_TO_CANONICAL | Progress empty-state expectations; WorkoutComplete adapt gating tests; any Home legacy routing that becomes obsolete after migrate | Rewrite to programme contracts |
| LEGACY_BEHAVIOUR_ONLY | `test/plans/plan_library_test.dart` start/bind paths; `test/daily_briefing/`; `test/adaptive_progression/` | Retire with path after callers migrated |
| RETIRE_WITH_PATH | HomeAdaptFlow-specific tests once entry removed | Delete with entry-point retirement |
| HISTORICAL/HARNESS | Staging PlanLibrary probes; Journey D harness/diagnosis | Keep tooling-separated |
| UNCERTAIN | Tests that assert HomeAdaptFlow success for pure legacy athletes | Resolve during HomeAdaptFlow migration sprint |

A legacy test must not force retention of a legacy implementation when the
product contract is already protected by the safety gate / programme suites.

---

## 8. Reachability findings

| Finding | Evidence |
|---------|----------|
| Plans tab still creates legacy athletes | `AthleteAppShell` mounts `PlanLibraryScreen` |
| Home dual path frozen but legacy branch live | Phase 2.4 resolver; DailyBriefing + HomeAdaptFlow |
| HomeTodaySessionSection / AthleteGeneratedTodaySection unmounted | No production shell mount; quarantine comments |
| SessionOverviewScreen unmounted | No `SessionOverviewScreen(` callers in lib |
| HomeAdaptFlow success for pure legacy | UNCERTAIN — loader expects programme executable |
| Onboarding generative path | Reachable from login; product necessity vs catalogue UNCERTAIN |

---

## 9. Decision

```text
LEGACY_RUNTIME_DECISION=RETIRE
```

### Rationale

1. Every intentional V1 athlete responsibility (catalogue enrol, materialise,
   prepare, execute, complete, descriptive previous performance, acceptance-gated
   adaptation, programme progress) has a Programme Athlete equivalent or a clear
   migration target.
2. Remaining Plan Library / Coach Brain athlete use is compatibility/historical
   plus an inappropriate **still-open Plans tab start path** — not a distinct
   required V1 capability.
3. Temporary local `hasActivePlan` state is transitional debt. It justifies a
   short migration window, not permanent dual runtime.
4. “Existing code / tests / old docs / founder authored it” are explicitly
   insufficient under Phase 2.5 rules.
5. Retirement can be sequenced without violating Phase 1 invariants if the
   consolidation safety gate runs after every sprint and callers migrate before
   providers delete.

### Rejected retain rationales

Not accepted as reasons for `RETAIN_COMPATIBILITY`:

- it already exists;
- tests exist;
- old docs called Coach Brain canonical;
- founder authored Plan Library content;
- may be useful later / flexibility;
- deleting it feels risky.

---

## 10. Prerequisites for eventual legacy deletion

Before deleting a legacy runtime symbol/path:

```text
all callers identified and migrated or proven unreachable
replacement path proven for that responsibility
tests migrated to contract-level assertions
legacy runtime registrations / navigation entry points removed
no required invariant depends exclusively on deleted code
default suite green
consolidation safety gate green
analyze has no new errors
runtime retirement separated from persistence/schema deletion
```

A green safety gate alone does not prove code is dead.

---

## 11. Ordered remaining Phase 2 plan

| Sprint | Objective | Concrete targets |
|--------|-----------|------------------|
| **2.6** | Stop new legacy runtime creation + consolidate Home today/prepare authority boundary | Replace Athlete shell Plans tab start with Programme catalogue (or hide Plan start); keep materialisation bridge; document device conflict handling |
| **2.7** | Migrate completion / progress / briefing consumers off `hasActivePlan` | `WorkoutCompleteScreen` adapt gate; Progress tab → programme summary; remove AdaptiveProgression from programme athletes |
| **2.8** | Retire Home legacy runtime entry points | Remove `legacyPlanCompatibility` Home branch, `DailyBriefingSection` Home mount, `HomeAdaptFlow` product entry |
| **2.9** | Orphaned Coach Brain / Plan Library service cleanup | `PlanStartService`, generation/resolver athlete runtime, AdaptiveProgression coordinator (after callers gone); PROVEN_UNREACHABLE UI cleanup |
| **2.10** | Naming / package / docs consolidation | SHARED_NEUTRAL renames (e.g. `CoachBrainWorkoutPlan` DTO), doc cross-refs; no semantic change |
| **Phase 2 final gate** | Full suite + safety gate + analyzer + reachability proof | No hosted journeys unless separately authorised |

Persistence/schema dormancy cleanup remains a later, separately authorised step.

---

## 12. Precise next implementation sprint (do not execute in 2.5)

### Phase 2.6 — Stop New Legacy Starts and Align Athlete Shell Catalogue Entry

| Field | Content |
|-------|---------|
| **Name** | Phase 2.6 — Stop New Legacy Starts and Align Athlete Shell Catalogue Entry |
| **Objective** | Prevent creation of new Plan Library / Coach Brain athlete runtime state from the athlete product shell, and point catalogue entry exclusively at Programme Athlete |
| **Exact callers/files** | `lib/features/app_shell/athlete_app_shell.dart` (Plans tab); `PlanLibraryScreen` / `PlanDetailScreen` product mounts; Home `ChoosePlanEntryCard` already programme-pointed — verify; founder shell Plan Library entry inventory only |
| **Canonical replacement** | `AthleteProgrammeScreen` + enrol + `AthletePlanMaterialisationService` + prepare |
| **Legacy dependency removed from those callers** | Athlete-facing Start Plan → Coach Brain prepare path from shell navigation |
| **Invariants at risk** | INV-01 authored authority; INV-07 scheduling/adapt separation; materialisation conflict preflight behaviour |
| **Focused tests** | Shell navigation / catalogue entry; materialisation still works; Home authority matrix still green; safety tripwires |
| **Full verification** | Safety gate, `flutter test`, `flutter analyze`, harness |
| **Rollback boundary** | Restore Plans tab mount; no persistence migration in 2.6 |
| **Completion criteria** | No athlete-shell path creates new `hasActivePlan` via PlanStart; Programme catalogue remains reachable; gate green; `LEGACY_RUNTIME_DELETED=false` still |
| **Explicit exclusions** | Do not delete `HomeAdaptFlow`, Plan Library services, AdaptiveProgression, Coach Brain engines, or local PlanAssignment data; do not migrate WorkoutComplete/Progress yet; no schema deletion |

---

## 13. Uncertainties retained

1. Whether `HomeAdaptFlow` can successfully adapt a pure legacy (non-materialised) athlete given loader requirements.
2. Whether `AthleteOnboardingFlow` generative bind remains a required V1 entry vs catalogue-only.
3. Product completeness of WorkoutComplete programme path vs Self-Test 2 atomic completion wiring.

These do **not** justify `RETAIN_COMPATIBILITY`. They become focused investigation items inside 2.7–2.8.

---

## 14. Authority statement after Phase 2.5

```text
Programme Athlete runtime = canonical
Plan Library / Coach Brain athlete runtime = RETIRE (migration pending)
Home = first migrated caller (Phase 2.4)
legacy deletion = not yet authorised
founder authoring ≠ founder-only athlete runtime
```
