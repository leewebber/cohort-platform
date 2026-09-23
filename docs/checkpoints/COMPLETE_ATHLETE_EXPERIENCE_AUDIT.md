# Complete Athlete Experience — production audit

**Recorded:** 2026-09-22
**Live pointer (2026-09-23):** Sprint 1 is **complete** at `a3cd351`.
Sprint 2 audit:
[`Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md),
[`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md).
Historical flags below remain the 2026-09-22 audit record.
**Status:** Read-only production audit retained. Architecture **approved**.
Sprint 1 **approved, not started**. Milestone **not** implemented.
**Architecture binding:**
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md)
**Audit HEAD / `origin/main`:** `c4d3dcbb2656c99e0773427ca6f31944d8ca1e73`
**Decision record:** 2026-09-22 (this file’s §11). Evidence in §§1–8 is
unchanged production-route audit.
**Branch:** `docs/complete-athlete-experience-audit` (local only)

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=APPROVED_NOT_STARTED
DAILY_JOURNEY_INTEGRITY=COMPLETE
NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE
NEXT_IMPLEMENTATION_AUTHORISED=false
HOSTED_SYSTEMS_CONTACTED=false
PRODUCT_CODE_CHANGED=false
PUSHED=false
```

Classifications used below are only:

- Production-complete
- Strong foundation
- Functional but incomplete
- Prototype-only
- Missing
- Unsafe / launch blocker
- Out of milestone scope

Intended architecture is not evidence. Preview, coach-studio, and
test-only surfaces receive no readiness credit.

---

## 1. Preflight

| Check | Result |
|-------|--------|
| `git fetch origin` | Performed |
| `origin/main` | `c4d3dcbb2656c99e0773427ca6f31944d8ca1e73` |
| Worktree at branch start | Clean; branch from `origin/main` |
| Repo `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` |
| `DAILY_JOURNEY_INTEGRITY` | `COMPLETE` ([DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md](./DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md)) |
| `NEXT_MILESTONE` | `COMPLETE_ATHLETE_EXPERIENCE` |
| Complete Athlete Experience implementation | Not started (no product-code sprint; this audit is docs only) |

Binding documents read: Athlete Product Completion Plan, Daily Journey
closeout, current checkpoint, Delivery Roadmap, Phase 1 implemented
architecture / freeze, adaptation and scheduling authorities, M9/M10
closeouts.

---

## 2. Method

1. Trace `lib/main.dart` → `CohortPlatformApp` → `AuthGate` →
   `AthleteAppShell` destinations.
2. Read production widgets, stores, RPCs, and authority resolvers on those
   routes.
3. Confirm `lib/features/programme_comparison/` is not imported by the
   athlete shell.
4. Confirm Daily Journey preview
   (`lib/main_daily_journey_integrity_preview.dart`) is not imported by
   `lib/main.dart`.
5. Classify each surface and each end-to-end scenario at the first
   production stopping point.
6. Rank launch-critical gaps; select one Sprint 1 from evidence.

Hosted systems were not contacted. No phone build. No Field Manual read
beyond already-closed Daily Journey evidence.

---

## 3. Production route inventory

**Entry:** [`lib/main.dart`](../../lib/main.dart) initialises Supabase and
`AthletePersistence`, then `CohortPlatformApp`.

**Gate:** [`lib/features/auth/screens/auth_gate.dart`](../../lib/features/auth/screens/auth_gate.dart)

| Phase (`ProductionAuthAuthority`) | Production widget |
|-----------------------------------|-------------------|
| authenticating / hydrating | `_AuthLoadingScreen` (“Restoring your session”) |
| unauthenticated / invalidIdentity | `LoginScreen` |
| awaitingEmailConfirmation | `EmailVerificationScreen` |
| profileRequired | `ProfileSetupScreen` |
| authenticatedOnline / authenticatedOffline | founder email → `FounderWorkspaceShell`; else `AthleteAppShell` |

**Shell destinations**
([`lib/features/app_shell/athlete_app_shell.dart`](../../lib/features/app_shell/athlete_app_shell.dart)):

| Index | Label | Widget |
|-------|-------|--------|
| 0 | Home | `HomeScreen` |
| 1 | Calendar | `AthleteCalendarScreen` |
| 2 | Programmes | `AthleteProgrammeScreen` |
| 3 | Progress | `ProgressScreen` |
| 4 | Profile | `AthleteProfileScreen` |

**Not on the production athlete map:**

- `lib/features/programme_comparison/` (coach-studio / migration)
- `lib/features/home/widgets/home_today_session_section.dart`
  (`HomeTodaySessionLoader` quarantined; Home uses
  `AthleteProgrammeTodaySection`)
- Daily Journey Integrity preview main
- Plan Library / Coach Brain Home (deleted in Phase 2.9)

---

## 4. Surface audit

### 4.1 Authentication and shell entry

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Signed-out | `LoginScreen`. Guest / START TRAINING is not on this route (closed in Daily Journey Integrity). | Production-complete |
| Authenticated athlete entry | `AuthGate` → `AthleteAppShell` when `AppExperienceResolver` is not founder. | Strong foundation |
| Unavailable / expired session | No dedicated expired-session surface. Failure / invalid identity returns `LoginScreen`. | Functional but incomplete |
| No assignment | Shell still mounts. Home uses `AthleteHomeRuntimeAuthority.none`. | Strong foundation |
| With assignment | Home `programme` authority; Calendar / Programmes / Progress consume the same assignment store. | Strong foundation |
| Local cache vs hosted | `LastVerifiedAuthProfileStore` is process-local. Cold start offline cannot restore a previous profile and falls through to login. `AthletePersistence.hydrate` is identity-scoped. | Functional but incomplete |
| Loading / retry / failure | Auth loading copy is honest. Home unavailable offers `VIEW PROGRAMMES`. Progress can collapse hosted failure to `emptySummary()`. | Functional but incomplete; Progress error path is a trust risk |
| Coach-only profile | Non-founder authenticated users enter the athlete shell. | Unresolved founder decision, not a separate product |

Sign-out from Profile is production-complete (`AuthController` +
`LastVerifiedAuthProfileStore.forgetIfUser`).

**Integrity notes.** `AthleteProfileScreen` falls back to athlete id
`athlete.local` when both `AthleteProfileSession` and
`CurrentUserSession` are missing. History is then opened with that id
([`athlete_profile_screen.dart`](../../lib/features/app_shell/screens/athlete_profile_screen.dart)).
That is a privacy / integrity risk if the fallback is ever reachable with
stale local rows.

### 4.2 Home

Production: [`lib/features/home/home_screen.dart`](../../lib/features/home/home_screen.dart)
+ [`athlete_programme_today_section.dart`](../../lib/features/home/widgets/athlete_programme_today_section.dart).
Authority:
[`AthleteHomeRuntimeAuthorityResolver`](../../lib/features/home/services/athlete_home_runtime_authority.dart).

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Today | Fixed-schedule projection or `AthleteProgrammeTodaySection`. | Strong foundation |
| Next session | Shown on rest-day card (`AthleteHomeRestDayCard`). | Strong foundation |
| Rest / recovery | Rest card is guidance-only (no Begin). `restGuidance` helper exists; unused on the mounted card. | Strong foundation |
| Programme identity | Greeting + assignment-backed today. Name quality depends on assignment fields. | Functional but incomplete |
| Begin / Resume / Complete | Present on today session. Completed today uses View results. | Strong foundation |
| Overdue / backfill | Not mounted on Home. Backfill is Calendar, capability-gated. | Functional but incomplete |
| Empty programme | `ChoosePlanEntryCard`. | Strong foundation |
| Programme completion | No dedicated Home complete-programme card. Lifecycle formatter can mark upcoming; end-of-programme Home is thin. | Functional but incomplete |
| Navigation | Open Calendar from Home; unavailable / none open Programmes. | Strong foundation |

Daily Journey handoff from Home is production-complete for the execution
spine (closed milestone). Home as a *product* around empty, complete, and
overdue states is not.

### 4.3 Programmes and catalogue

Production list / enrol:
[`athlete_programme_selection_screen.dart`](../../lib/features/programme/screens/athlete_programme_selection_screen.dart)
opened from
[`athlete_programme_screen.dart`](../../lib/features/programme/screens/athlete_programme_screen.dart).

Enrolment authority:
[`athlete_catalogue_enrolment_supabase_store.dart`](../../lib/features/programme/services/athlete_catalogue_enrolment_supabase_store.dart)
RPC `enrol_athlete_in_catalogue_programme_version`.

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Catalogue discovery | Published versions as a list on Programmes. | Functional but incomplete |
| Filter / search | Absent on the athlete catalogue. | Missing |
| Programme cards | Name + enrol. Authored equipment / frequency / goals are not presented as a product card. | Functional but incomplete |
| Programme detail | No athlete detail route. | Missing |
| Intended athlete / prerequisites | Not shown. | Missing |
| Duration / frequency | On model; not shown on athlete list. | Missing (presentation) |
| Equipment | On model; not shown. | Missing (presentation) |
| Goals / format | Not shown as athlete-facing facts. | Missing (presentation) |
| Version / default visibility | Enrol pins exact version. UI does not explain default vs pinned. | Functional but incomplete |
| Enrolment | `AlertDialog` confirm. Already-enrolled snackbar. Testing-access copy (“not a purchase”). | Strong foundation (authority); Functional but incomplete (product) |
| Active assignment | Replace-active copy is explicit; `replaceActive` passed to RPC. | Strong foundation |
| Retired / superseded | Pin holds. Athlete is not told the catalogue default moved. | Functional but incomplete |
| Empty / error / loading | List loading / empty exist at controller level; not a designed product empty. | Functional but incomplete |
| Timezone | `DateTime.now().timeZoneName` passed as enrol timezone. Device abbreviations are not IANA and can fail start. | Unsafe / launch blocker for enrol start |

### 4.4 Athlete programme comparison

**Classification: Missing.**

Coach-studio comparison
(`lib/features/coach_studio/programmes/widgets/intelligence/`,
`lib/features/programme_comparison/`) is not imported by `AuthGate`,
`AthleteAppShell`, `HomeScreen`, `AthleteProgrammeScreen`, or
`AthleteProgrammeSelectionScreen`. Architecture previews, impact tools,
and content-graph diffs receive no credit.

| Audit question | Production athlete answer |
|----------------|---------------------------|
| Comparison entry point | None |
| Selection | None |
| Dimensions compared | None |
| Authored vs calculated | N/A (missing) |
| Mobile usability | N/A |
| Choose / enrol from comparison | N/A — enrol exists only on the list dialog |
| Unavailable / unsupported | N/A |

### 4.5 Current programme experience

`AthleteProgrammeScreen` is the current-programme surface plus catalogue
entry. Session detail / prepare / launch reuse Daily Journey authorities.

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Overview | Current assignment on Programmes. | Functional but incomplete |
| Structure / week-day | Calendar is the placement surface; Programmes is not a week browser. | Functional but incomplete |
| Session detail | Prepare / preview / Active Session (Daily Journey). | Strong foundation (execution) |
| Progression visibility | Not an athlete product; Progress tab is assignment summary only. | Out of milestone scope for advanced mechanics; current visibility Functional but incomplete |
| Pinned version | Durable via enrolment RPC + `content_graph_prevent_assignment_repin`. | Strong foundation (integrity); Functional but incomplete (athlete understanding) |
| Status / completion | Occurrence states on Calendar; programme-complete product path thin. | Functional but incomplete |
| Change / replacement | Enrol-another with replace-active. Explicit, but from a list without detail. | Functional but incomplete |
| History after change | Completions remain on prior assignment; Progress / History do not narrate the change. | Functional but incomplete |
| Silent repin | Prevented at hosted pin invariant. | Production-complete (integrity) |

### 4.6 Calendar and scheduling

[`athlete_calendar_screen.dart`](../../lib/features/programme/screens/athlete_calendar_screen.dart)
+ month grid.

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Current week / month | Month grid. | Strong foundation |
| Past / future sessions | Visible as occurrences. | Strong foundation |
| Rest days | Represented. | Strong foundation |
| Completion / missed | Occurrence states; Incomplete / overdue language on calendar. | Strong foundation |
| Reschedule vs adapt | Train today is placement, not adaptation. Adaptation remains review-gated elsewhere. | Strong foundation (boundary) |
| Backfill | Separate flow, capability-gated. | Strong foundation |
| Timezone / local date | Calendar uses local date helpers; enrol timezone is a different clock (`timeZoneName`). | Functional but incomplete |
| Offline | No calendar occurrence cache for cold offline. Authenticated-offline shell can mount; data refresh fails. | Functional but incomplete |

### 4.7 Progress and training history

Progress: [`progress_screen.dart`](../../lib/features/progress/screens/progress_screen.dart)
+ [`athlete_progress_summary_builder.dart`](../../lib/features/progress/services/athlete_progress_summary_builder.dart).

History: Profile push →
`TrainingHistoryScreen(athleteId: _athleteId)`.

Performance Portfolio concepts are **not** implemented and are out of
milestone scope.

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Completed sessions | History list of records for the resolved athlete id. | Functional but incomplete |
| Recorded results | Present on result projection / completed-today View results. | Strong foundation (today); Functional but incomplete (history composition) |
| Previous performance | Wired in execution (Daily Journey). Not a Progress product. | Strong foundation (in-session); Missing (Progress trends) |
| Charts / trends | Radar / timeline empty or unused. | Missing |
| Discipline / compliance | Occurrence-backed counts in summary. | Functional but incomplete |
| Programme progress | `planName: assignment.lineageCode` — technical, not athlete name. | Functional but incomplete |
| Performance metrics / tests | Not an athlete product. | Missing / Out of milestone scope |
| Empty states | Empty summary; failure can look like empty (`emptySummary()`). | Unsafe / launch blocker if treated as “no training” |
| Freshness | Rebuilds on shell progress epoch; no explicit stale label. | Functional but incomplete |
| Workout → results | Home completed-today View results. History is a separate Profile push. | Functional but incomplete |

### 4.8 Profile, settings, and support

[`athlete_profile_screen.dart`](../../lib/features/app_shell/screens/athlete_profile_screen.dart)

| Topic | Production behaviour | Classification |
|-------|----------------------|----------------|
| Athlete identity | Display name, email, athlete id. Id is technical. | Functional but incomplete |
| Sign-out | Present and authoritative. | Production-complete |
| Timezone / units | No athlete preference controls. | Missing |
| Accessibility settings | No in-app a11y settings (production a11y is Daily Journey Sprint 3). | Missing (settings exposure) |
| Privacy / data controls | Absent. | Missing |
| Help / support | `BetaSupportScreen` — prototype / beta. | Prototype-only |
| Account deletion | Absent. | Missing |
| Legal | Absent. | Missing |
| Dead / prototype | Wearables “Coming later” row. | Prototype-only |

### 4.9 Cross-surface consistency

Shared assignment store + `AthleteProgrammeSurfaceRefreshScope` keep Home,
Calendar, and Programmes closer than Progress / History.

| Risk | Evidence |
|------|----------|
| Duplicate authorities | Home quarantines `HomeTodaySessionLoader`; Progress uses its own builder. |
| Stale caches | Process-local auth profile; Progress empty on error. |
| Display-name joins | Progress `lineageCode`; Profile `athlete.local` fallback. |
| Inconsistent labels | Testing-access enrol copy vs production Home. |
| Alternate mutation | Enrol / replace-active is the assignment mutation. Train today and Backfill must not enrol. Observed: they do not. |
| Contradictory status | Programme-complete vs “today” is under-specified on Home. Pinned vs catalogue default is invisible. |

---

## 5. End-to-end scenarios

Readiness is the production stopping point, not the intended journey.

### 1. New authenticated athlete with no programme

- **Entry:** `AuthGate` → `AthleteAppShell` → Home
- **Authority:** `AthleteHomeRuntimeAuthority.none`
- **Screens:** Home `ChoosePlanEntryCard` → Programmes catalogue
- **Success:** They reach a list of published versions
- **Missing:** What Cohort offers; programme detail; comparison
- **Risk:** Enrol from a name-only list
- **Readiness:** Functional but incomplete

### 2. Athlete browsing the catalogue

- **Entry:** Programmes tab or Home CTA
- **Authority:** Catalogue published versions
- **Screens:** `AthleteProgrammeSelectionScreen` list
- **Success:** See names and enrol
- **Missing:** Filter, search, cards with authored facts, detail
- **Risk:** Low integrity; high decision error
- **Readiness:** Functional but incomplete

### 3. Athlete deciding between two programmes

- **Entry:** Same list
- **Authority:** None for comparison
- **Screens:** None
- **Success:** Cannot
- **Missing:** Entire comparison journey
- **Risk:** Blind enrol or replace-active
- **Readiness:** Missing

### 4. Athlete enrolling in a programme

- **Entry:** List tap → `AlertDialog`
- **Authority:** `enrol_athlete_in_catalogue_programme_version`
- **Screens:** Confirm → snackbar / return
- **Success:** Explicit pin of exact version; history preserved on replace
- **Missing:** Detail-informed decision; IANA timezone; launch product copy
- **Risk:** `timeZoneName` start failure; replace from incomplete inspect
- **Readiness:** Strong foundation (transaction); Unsafe if timezone fails closed poorly

### 5. Athlete returning after enrolment

- **Entry:** Home / Calendar
- **Authority:** `AthleteHomeRuntimeAuthority.programme` + assignment store
- **Screens:** Today / month grid
- **Success:** Next action on Home when schedule projects
- **Missing:** “You just enrolled in X (version)” confirmation product
- **Risk:** Low if refresh scope fires; confusion if calendar still loading
- **Readiness:** Strong foundation

### 6. Athlete completing today’s session

- **Entry:** Home Begin / Resume
- **Authority:** Daily Journey restore + `ActivePerformanceDraft`
- **Screens:** Active Session → complete → Home completed-today
- **Success:** Closed Daily Journey Integrity path
- **Missing:** None for the spine
- **Risk:** Already bound and closed
- **Readiness:** Production-complete (execution spine)

### 7. Athlete viewing the result and previous performance

- **Entry:** Home View results; in-session previous performance
- **Authority:** Completed session result projection / athlete actuals
- **Screens:** Result from today; History only via Profile
- **Success:** Today’s result
- **Missing:** Progress charts; History from the result; programme-named Progress
- **Risk:** Error shown as empty Progress
- **Readiness:** Functional but incomplete

### 8. Athlete missing a session

- **Entry:** Calendar occurrence state; not Home overdue
- **Authority:** Fixed occurrence store
- **Screens:** Calendar; Backfill if capability on
- **Success:** See missed / incomplete on Calendar
- **Missing:** Home overdue; athlete-facing Backfill when capability off
- **Risk:** Scheduling vs adaptation confusion (boundary is correct)
- **Readiness:** Strong foundation (Calendar); Functional but incomplete (Home)

### 9. Athlete encountering a rest / recovery day

- **Entry:** Home rest card / Calendar rest
- **Authority:** Occurrence rest state
- **Screens:** `AthleteHomeRestDayCard` (no Begin)
- **Success:** No accidental training start from rest card
- **Missing:** Richer rest guidance unused (`restGuidance`)
- **Risk:** Low
- **Readiness:** Strong foundation

### 10. Athlete completing a programme

- **Entry:** Last occurrence complete
- **Authority:** Assignment + occurrence projection
- **Screens:** Home today / Calendar; no complete-programme product
- **Success:** Sessions can be complete; programme-complete journey stops
- **Missing:** Home complete card, next-programme CTA, truthful “you finished X”
- **Risk:** Athlete looks like no-programme or empty today
- **Readiness:** Functional but incomplete

### 11. Athlete considering a different programme

- **Entry:** Programmes list while assigned
- **Authority:** Replace-active enrol
- **Screens:** Same name-only list + stronger dialog
- **Success:** Explicit replace; history preserved (copy + new assignment)
- **Missing:** Detail, compare, aftermath narration
- **Risk:** Accidental replace from list; still explicit confirm
- **Readiness:** Functional but incomplete

### 12. Pinned version is no longer catalogue default

- **Entry:** Home / Programmes
- **Authority:** Pin invariant holds
- **Screens:** No superseded-default explanation
- **Success:** They stay on the pinned version
- **Missing:** Honesty that the catalogue moved
- **Risk:** Low integrity; high trust if they re-browse and re-enrol
- **Readiness:** Strong foundation (pin); Functional but incomplete (UX)

### 13. Offline while browsing non-execution surfaces

- **Entry:** `authenticatedOffline` same shell
- **Authority:** Process-local auth if still in process; no catalogue cache
- **Screens:** Shell mounts; lists / Progress fail or empty
- **Success:** Execution drafts stay user-scoped (Daily Journey)
- **Missing:** Honest offline catalogue / Progress / Calendar
- **Risk:** Empty mistaken for no data
- **Readiness:** Functional but incomplete

### 14. Recoverable hosted error

- **Entry:** Home unavailable; auth failure; Progress build failure
- **Authority:** Varies
- **Screens:** Home “Unable to confirm programme” + VIEW PROGRAMMES; login on invalid identity; Progress empty
- **Success:** Home unavailable is retry-shaped
- **Missing:** Progress distinguishes error vs empty
- **Risk:** Swallowed Progress error
- **Readiness:** Functional but incomplete; Progress path Unsafe if believed

### 15. Sign out and return

- **Entry:** Profile sign-out → `LoginScreen` → AuthGate
- **Authority:** `AuthController` clears session + last-verified profile
- **Screens:** Login → shell
- **Success:** Identity resets
- **Missing:** Cold offline return
- **Risk:** Low online
- **Readiness:** Production-complete (online sign-out / sign-in)

---

## 6. Readiness scoreboard

Every score cites production code or observed production behaviour.

| Surface | Score | Evidence |
|---------|-------|----------|
| Authenticated shell | Strong foundation | `AuthGate` + `AthleteAppShell` five destinations; founder split; no guest start |
| No-programme experience | Strong foundation | `AthleteHomeRuntimeAuthority.none` → `ChoosePlanEntryCard`; tests in `test/features/home/athlete_home_runtime_authority_test.dart` |
| Catalogue discovery | Functional but incomplete | `AthleteProgrammeSelectionScreen` list; `test/features/app_shell/athlete_shell_catalogue_entry_test.dart` |
| Programme detail | Missing | No athlete detail route from Programmes / Home |
| Programme comparison | Missing | `programme_comparison` unused by athlete shell |
| Enrolment | Strong foundation | Explicit dialog + `enrol_athlete_in_catalogue_programme_version`; `test/programme/athlete_catalogue_enrolment_test.dart` |
| Assignment pin integrity | Production-complete | Exact version pin; `content_graph_prevent_assignment_repin` in migration tests |
| Current programme overview | Functional but incomplete | `AthleteProgrammeScreen` without product structure / version honesty |
| Calendar | Strong foundation | Month grid, rest, completion, Train today ≠ adapt, gated Backfill |
| Home | Strong foundation | Today Begin/Resume/Complete/rest/View results; no overdue or programme-complete card |
| Session detail | Strong foundation | Daily Journey prepare / Active Session |
| Daily Journey handoff | Production-complete | Closed at `c4d3dcb`; launcher + restore resolver |
| Completion / result handoff | Strong foundation | Completed-today View results; History not composed from that path |
| History | Functional but incomplete | Profile → `TrainingHistoryScreen`; `athlete.local` fallback |
| Progress | Functional but incomplete | `lineageCode` name; empty radar; `emptySummary()` on failure |
| Programme completion | Functional but incomplete | Occurrences can complete; no programme-complete product |
| Programme change / replacement | Functional but incomplete | Explicit replace-active; no inspect/compare/aftermath |
| Errors and empty states | Functional but incomplete | Home loading/unavailable honest; Progress error-as-empty |
| Offline non-execution behaviour | Functional but incomplete | Same shell offline; no catalogue/calendar cache; cold auth process-local |
| Settings / profile / support | Functional but incomplete | Sign-out complete; timezone/units/privacy/legal/deletion missing; BetaSupport prototype; Wearables dead |
| Accessibility consistency | Strong foundation | Daily Journey Sprint 3 on execution; shell/settings a11y incomplete |

---

## 7. Product-quality review

Assessed against the funded-product standard. Colour system is not
redesigned; visual-system debt is recorded separately.

| Standard | Finding |
|----------|---------|
| Clear next action | Strong on assigned today. Weak on no-programme (list only) and programme-complete. |
| Low cognitive load | Five-tab shell is clear. Catalogue and Progress leak technical language (`lineageCode`, athlete id). |
| No technical / internal language | Enrol “programme access for testing”, Profile athlete id, Progress lineage code. |
| No dead ends | Comparison is a dead end (absent). Wearables row is a dead control. |
| No launch-critical placeholders | Wearables “Coming later”; BetaSupport; empty Progress visuals. |
| No contradictory CTAs | Train today ≠ adapt holds. Enrol vs replace-active is explicit. Home unavailable still pushes Programmes. |
| Honest loading / error / offline | Auth and Home loading honest. Progress and cold offline are not. |
| Consistent hierarchy | Home / Calendar stronger than Programmes / Progress / Profile. |
| Useful empty states | Choose-plan is useful. Progress empty is not trustworthy. |
| Mobile ergonomics | List + dialog enrol is usable; comparison cannot be judged (missing). |
| Accessibility | Execution Sprint 3; catalogue/detail/compare/settings not at that bar. |
| Visual consistency | Shared Cohort cards / type. Visual-system debt: mixed technical copy, dead rows, unused rest guidance. |
| Athlete trust | Pin integrity and explicit enrol help. Swallowed errors, testing copy, and name-only enrol hurt. |
| Usefulness to hybrid athletes | Execution spine is useful. Decision and long-horizon Progress are not yet a hybrid-athlete product. |

**Visual-system debt (do not implement in this audit):** dead Wearables
row, testing-access enrol voice, technical ids in Profile/Progress, unused
`restGuidance`, empty radar/timeline chrome.

---

## 8. Gap ranking (launch-critical)

Ranked by athlete value, journey blockage, safety/integrity, dependency
order, reuse, size, testability, library effect, Build Your Own effect.

| Rank | Gap | Why first-order |
|------|-----|-----------------|
| 1 | Inspect / compare / enrol from authored facts | Blocks every new or switching athlete. Reuses catalogue + existing RPC. Comparison is missing; detail is missing; list exists. Highest journey blockage. Does not require library authorship. |
| 2 | Enrol start IANA timezone + superseded-pin honesty | Integrity of start and version trust. Depends on a decision surface existing, but can follow immediately. |
| 3 | Programme-complete Home + replacement aftermath | Lifecycle after a real programme. Depends on athletes being able to enrol and train. |
| 4 | Progress / History composition | Trust after sessions exist. Daily Journey already records actuals. |
| 5 | Offline / errors / settings | Real, but not the first journey blockage for a new athlete. |

Programme comparison does **not** win merely because it was previously
named. It wins as part of rank 1 because the production athlete cannot
complete the decision that the rest of the product assumes.

---

## 9. Selected Sprint 1

**Programme Discovery and Decision** is **approved, not started**. Binding
detail:
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md)
§7.

```text
discover
  → inspect authored programme detail
  → compare candidates
  → make an explicit enrolment decision
```

Layers (do not collapse):

1. Programme discovery (existing list + authored facts already on the model)
2. Programme detail (missing)
3. Side-by-side comparison (missing)
4. Enrolment decision (existing explicit RPC; **no-programme athletes
   only** in Sprint 1)

**Rationale (audit, unchanged).** Rank 1 is the only gap that stops a new
authenticated athlete from starting the closed Daily Journey spine
honestly. Enrolment authority and pin integrity are already strong; the
missing product is inspection.

**Founder-bound Sprint 1 limit.** Assigned athletes may inspect and
compare. Sprint 1 must not replace, rewrite, or repin. The existing
replace-active dialog remains audit evidence of current production, not a
Sprint 1 product path. Sprint 1 must also replace production-visible
testing-access copy on this route.

**Sprint 2 outline (not authorised):** IANA enrol timezone, pinned-versus-
default honesty, and explicit replacement **design**. Replacement is not
approved by being listed.

**Sprint 3 outline (not authorised):** Programme-complete Home and
Progress / History agreement, including the Progress error-as-empty and
History fallback launch blockers.

---

## 10. Launch blockers

Treat as launch-critical for Complete Athlete Experience, not for Daily
Journey Integrity (already closed):

1. No athlete programme detail — **Sprint 1**.
2. No athlete programme comparison — **Sprint 1**.
3. Production-visible testing-access enrol copy — **Sprint 1** (copy only).
4. Enrol timezone may not be IANA (`DateTime.now().timeZoneName`) —
   **Sprint 2 architecture work**.
5. Superseded-default / programme-complete honesty — Sprint 2 design and
   Sprint 3 Home, respectively.
6. Progress hosted failure can present as empty training — **Sprint 3
   launch blocker**. Milestone cannot close until corrected and tested.
7. Profile History athlete-id fallback `athlete.local` — **Sprint 3
   launch blocker**. Milestone cannot close until corrected and tested.
8. Active-programme replacement UX — **out of Sprint 1**; Sprint 2
   architecture work only; transaction **not approved**.

---

## 11. Resolved founder decisions

Replaces the unresolved list from the original audit commit. Production
evidence in §§1–8 is not rewritten.

| # | Original question | Founder binding |
|---|-------------------|-----------------|
| 1 | Approve architecture + Sprint 1? | Architecture v1 **approved**. Sprint 1 is **Programme Discovery and Decision**, `APPROVED_NOT_STARTED`. Implementation not started until separately authorised. |
| 2 | Replace-active in Sprint 1? | **No.** No-programme enrol only. Assigned athletes may inspect/compare. No replace, rewrite, repin, or hidden switch. Truthful “switching not available” CTA if another programme is shown. No dead replacement CTA. Replacement listed in Sprint 2 design only; **not approved**. |
| 3 | Coach-only users in `AthleteAppShell`? | Coach role alone does **not** authorise the athlete shell. Fail closed. Dual-role only via authoritative athlete context. No synthetic, display-name, or fallback identity. Later coach product uses its own shell. Launch-integrity requirement. Not this docs task. Not silently Sprint 1 unless an implementation plan proves the `AuthGate` boundary is touched. |
| 4 | Testing-access copy? | Internal fixtures / internal builds only. External beta and production must be product-neutral, or explicitly beta access. Do not imply payment, subscription, entitlement, or permanence. Sprint 1 must audit and replace production-visible testing language on discovery/detail/comparison/enrolment. Commercial design remains later. |
| 5 | Progress error-as-empty / History fallback in Sprint 1? | **No.** Keep Sprint 1 bounded. Both are launch blockers in Sprint 3. Progress must not present hosted/query failure as empty. History must not use `athlete.local` or another fallback as authority. Failure honest and retryable; missing identity fails closed. Complete Athlete Experience cannot close until both are corrected and tested. |

---

## 12. Verification (original audit task)

Recorded on the documentation audit commit worktree (docs only).

| Check | Result |
|-------|--------|
| Production-entry / route scan | `lib/main.dart` does not import the Daily Journey preview. `AthleteAppShell` mounts Home, Calendar, Programmes, Progress, Profile. `programme_comparison` is not imported by `app_shell`, `home`, `programme/screens`, or `auth`. |
| Focused tests | `flutter test` on home authority, catalogue enrolment, shell catalogue entry, content-graph pin migration, and enrolment migration: **43 passed** |
| Relative links | 204 links on changed pointer + new docs: **ok** |
| Flag consistency (audit commit) | Then `AUDITED_AWAITING_APPROVAL` / `SPRINT_1=NOT_STARTED` / DJ `COMPLETE` / `NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE` |
| `git diff --check` | clean |
| Phase 2 consolidation safety gate | **PASS** (`groups_passed=6`) |

No full Flutter suite. No DB gate. No hosted contact.

---

## 13. Explicit non-actions

The original audit and this decision-binding correction did not implement
athlete features, create a preview, change product code, schema, or
fixtures, contact hosted systems, install a phone build, push, mutate
Field Manual, change `.env`, touch WOD Timer / Whiteboard, start
Performance Portfolio, start Sprint 1, authorise Sprint 2/3, or mark the
milestone implemented.

## 14. Decision-binding verification

Recorded on the founder-decision documentation worktree (docs only).

| Check | Result |
|-------|--------|
| Relative links | 204 links on changed pointer + binding docs: **ok** |
| Flag consistency | `ARCHITECTURE_APPROVED` / `APPROVED_NOT_STARTED` on live pointers; prior audit-commit flags retained only as historical evidence in §12 |
| `git diff --check` | clean |
| Focused authority / pin / enrol tests | **43 passed** |
| Phase 2 consolidation safety gate | **PASS** (`groups_passed=6`) |

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=APPROVED_NOT_STARTED
```
