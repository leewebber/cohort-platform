# Complete Athlete Experience Sprint 3 v1

**Status:** Binding architecture for Sprint 3. Founder decisions
**approved**. Implementation is **approved, not started**.
**Recorded:** 2026-09-24
**Decisions bound:** 2026-09-24
**Parent:**
[`Complete_Athlete_Experience_v1.md`](./Complete_Athlete_Experience_v1.md)
**Evidence:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md)
**Integrated Sprint 2 HEAD:** `840542170137c4e75ffe663bbc08d7b98be3faac`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=APPROVED_NOT_STARTED
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
PERFORMANCE_PORTFOLIO_AUTHORISED=false
```

This document binds the approved Sprint 3 product. It is **not** an
implementation licence. A later task must separately authorise code
changes. Sprint 3 is **not** implemented. Complete Athlete Experience
is **not** closed.

---

## 1. What Sprint 3 is

Sprint 1 closed discovery → inspect → compare → explicit no-active
enrol. Sprint 2 closed IANA enrol, athlete-local `started_at`, and
pinned-versus-default honesty.

Sprint 3 exists because those journeys still collapse after the last
session is completed, and because Progress / History can lie about
emptiness and identity. The four named launch blockers are **one
authority problem**, not four independent tickets:

```text
assignment lifecycle (active | completed | none | error)
  + authoritative athlete identity
  → Home, Calendar, Programmes, Progress, History must agree
```

When Sprint 3 is later implemented, these facts must become true:

1. Completing the final authored session persists assignment
   `status = completed` and Home tells the truth about that completion.
2. Completed is **not** treated as “never enrolled”.
3. Completed is **not** treated as an active assignment for enrolment.
4. Progress empty means the query succeeded and no qualifying evidence
   exists.
5. History and Progress query only the signed-in athlete id. No
   `athlete.local` or other fallback identity.
6. Home, Calendar, Programmes, Progress, and History agree on the
   matrix in §7.

---

## 2. Production authority (as of `8405421`)

### 2.1 Identity path

```text
lib/main.dart
  → CohortPlatformApp
    → AuthGate
         ProductionAuthAuthority + AuthController + CurrentUserSession
         AppExperienceResolver (founder email → FounderWorkspaceShell;
                                 every other authenticated email → AthleteAppShell)
      → AthleteAppShell
           athleteId := AthleteProfileSession.profile?.athleteId
                     ?? CurrentUserSession.maybeInstance?.athleteId
                     ?? 'athlete.local'
           Home / Calendar / Programmes / Progress / Profile
```

Authoritative athlete id is `CurrentUserSession.athleteId` (`userId`).
`AuthenticatedIdentity.requireAthleteId()` already fail-closes when the
session is missing or `!isAthlete`. Production Home, Progress, Profile
History, Calendar, and Programmes **do not** use that helper. They use
the `'athlete.local'` fallback.

`athlete.local` is **not** a hosted athlete. It is a client string.
On a signed-in production path `CurrentUserSession` is normally bound,
so History usually queries the real user id. The fallback is still
reachable when session and profile are both absent (widget tests,
founder tools, mid-shell session clear, preview). Profile **displays**
the fallback as “Athlete ID”. That is forbidden identity.

Coach-only: `AppExperienceResolver` has no coach role. A coach-only
account enters `AthleteAppShell`. Coach role alone must not authorise
athlete History or Progress. Dual-role may use the athlete profile
only.

### 2.2 Assignment and completion path

```text
Active Session
  → AthleteProgrammeCompletionService.submit
  → complete_programme_session_and_advance (existing RPC)
       writes training_session_records + programme_slot_outcomes
       if no next cursor:
         programme_assignments.status = 'completed'
         completed_at = now
         terminal_programme = true
  → Home / Calendar / Programmes / Progress all re-read through
       ProgrammeAssignmentStore.getActiveAssignment
         .eq('status', 'active')
```

Completion is **persisted** at assignment level by the existing RPC.
It is also **derived** for Continuity (`AthleteProgrammeContinuity`)
when a completed assignment is supplied. Production loaders never
supply that row: `getActiveAssignment` and
`resolve_active_fixed_programme_calendar` both filter `status = 'active'`.

`listForAthlete` already returns completed and reassigned rows.
`resolve_fixed_programme_calendar(assignment_id)` already exists and
does not require the row to be active. Production Calendar / Home do
not call either after completion.

Enrolment eligibility already treats completed as inactive: the
catalogue RPC and `canEnrol` look only at an **active** row. A
completed athlete may use the existing no-active-programme enrol
transaction. Sprint 3 must not add a second enrol RPC or a replacement
path.

### 2.3 Surface reads today

| Surface | Assignment read | After programme complete |
|---------|-----------------|--------------------------|
| Home | `getActiveAssignment` → runtime `none` | `ChoosePlanEntryCard` (looks like never enrolled) |
| Calendar | `resolve_active_fixed_programme_calendar` → `no_active_assignment` | “No programme scheduled” |
| Programmes | `getActiveAssignment` → catalogue | Discovery as if unassigned; Continuity `completed` never mounts |
| Progress | `getActiveAssignment` miss → `emptySummary()` then history merge | If history works: sessions exist, `planName` null, “No active programme”; if history fails: genuine-empty copy |
| History | `listHistory(athleteId)` | Results remain if athlete id is real; empty if fallback or query fail |

`AthleteHomeRuntimeAuthority` has `programme | none | loading | unavailable`.
It has **no completed** classification. Completing the last session
therefore cannot produce a Home complete card.

Continuity already has `AthleteProgrammeContinuityStatus.completed` and
`AthleteProgrammeStatusState.fromContinuity` renders “This programme is
complete.” That widget is dead on production after completion because
the assignment is never loaded.

### 2.4 Progress empty versus error (production)

`ProgressScreen._bootstrap` (`lib/features/progress/screens/progress_screen.dart`):

| Condition | Current behaviour |
|-----------|-------------------|
| Injected summary | Success |
| Builder success | Success |
| Builder throws | **`emptySummary()`** — error presented as empty |
| Loading | Empty scaffold + “Loading recorded sessions…” |
| Assignment fetch throws | Authority `unavailable` → `emptySummary()` + optional history merge |
| Programme tree/outcomes throw | `programmePlaceholder` (0 sessions, `hasActivePlan: true`) then history merge |
| History list throws | Evidence dropped to `[]`; no error |
| Refresh while failed | Last truthful data replaced by empty |
| Retry | None |

Empty copy (“Complete your first session to begin”, “Awaiting evidence”)
is therefore reachable after auth, network, parse, and authority
failures.

Progress is **functional but incomplete**. Some failure paths are
**unsafe if believed**.

### 2.5 History identity (production)

`AthleteProfileScreen` pushes
`TrainingHistoryScreen(athleteId: _athleteId)` with the fallback chain
above. The screen itself distinguishes loading, `snapshot.hasError`
(retry via pull-to-refresh), and genuine empty. The defect is the
**caller identity**, not the list UI.

History list is athlete-scoped `training_session_records` (not
assignment-scoped). Completed-programme results remain after a later
enrol if the athlete id is unchanged. Foreign-athlete rows cannot be
returned by RLS for another `auth.uid()`, but a fallback id can hide
the signed-in athlete’s rows or show none. Sign-out clears
`CurrentUserSession`, process caches, and local persistence for the
captured id. Shell widgets that still hold `'athlete.local'` after
sign-out would query the wrong key.

---

## 3. Programme-complete journey (intended)

**Authoritative completion event.** The existing completion RPC
commits the final slot outcome and, when no next cursor exists, sets
`programme_assignments.status = 'completed'`. That write is the
assignment-complete authority. Occurrence completion alone is not
programme completion. Client `terminalProgramme` is a projection of
that write, not a second authority.

**Persisted and derived.** Status and `completed_at` persist.
Continuity, Home, Calendar, and Programmes derive presentation from
that row plus authored title. Do not infer completion from “no active
assignment” or “no today session”.

**Home.** After the final session, Home may still show the completed
today card until the assignment refresh lands. After refresh, Home
must **not** become `ChoosePlanEntryCard`. It must show a factual
completed-programme state:

```text
You finished {authored programme title}.
```

Primary action: **View results** (authoritative completed evidence).
Secondary action: **Browse programmes** (existing no-active-programme
journey). No Begin. Do not claim improvement, transformation, goal
achievement, readiness, fitness gain, or personal best unless
separately supported by authoritative evidence. Do not recommend a
programme or create urgency.

**Calendar.** The completed assignment’s occurrences remain
inspectable (completed / rest). No new scheduled Begin. Empty
“Choose a programme” is reserved for **no assignment history**, not
for a just-finished programme.

**Progress.** Historical evidence for the completed version remains.
Current-programme block names the completed programme as completed,
or states there is no active programme **and** that the last programme
finished — never “first session to begin” if qualifying records exist.

**History.** Same athlete id; completed sessions stay attached to
their `assignment_id` / programme version on the record. Later enrol
does not rewrite or hide them.

**Programmes.** Continuity `completed` mounts. Catalogue browse
remains allowed. Enrol uses the existing no-active-programme
transaction only.

**Inspection.** Yes — completed programme title, Calendar, History,
and last-session results remain readable.

**Return to discovery.** Allowed, not forced. Home must not pretend
the athlete was never enrolled.

**Delayed assignment-complete.** If the session record is committed
and `terminal_programme` is delayed or unseen: keep the completed
today / last-session truth; do not flip to no-programme; do not invent
assignment-complete. Retry assignment read. Fail closed if assignment
evidence is unavailable (`unavailable`), not `none`.

**Restart / offline / partial failure.** Restart re-reads hosted
assignment + records. Offline with previously loaded complete-state
keeps that state and marks refresh failure. Partial repository
failure is error, not empty.

**Stale local drafts.** Hosted completion remains authority.
`WorkoutProgressSnapshotPolicy` already clears snapshots on
`completedHosted` or foreign athlete. Sprint 3 must not resume a
local draft for a completed assignment. Discard is best-effort and
must not rewrite hosted results.

---

## 4. Progress integrity (binding)

1. Genuine empty = query succeeded and no qualifying completed
   evidence exists for this athlete.
2. Auth, network, repository, parse, and authority failures render as
   typed error with retry where safe.
3. Refresh failure keeps last truthful data and shows an error; it
   does not replace success with empty.
4. No invented percentages, trends, scores, personal bests, or
   “you’re fitter” claims. Coverage ≠ improvement.
5. Incompatible units must not be combined.
6. Historical results stay tied to authored programme / session /
   version.
7. No Performance Portfolio implementation.

Reuse `AthleteSafeErrorPresenter` already used by History. Do not
reuse `emptySummary()` as an error sink.

---

## 5. History identity (binding)

Production athlete id for History, Progress, Home, Calendar, and
Programmes:

```text
AuthenticatedIdentity.requireAthleteId()
  or an equivalent that:
    requires CurrentUserSession
    requires profile.isAthlete
    never returns 'athlete.local'
    never uses display name, email, or previous-user cache
```

Missing identity → fail closed (re-authenticate). Coach-only → fail
closed on athlete History / Progress (and must not enter those tabs
with a synthetic id). Dual-role uses the athlete context only.

Removing the fallback is a **client + test** change. Tests that seed
`athlete.local` as a fixture athlete id remain valid only as explicit
test data, not as a production default.

After a later enrol, History remains the union of that athlete’s
terminal records. Do not filter to the current active assignment.

---

## 6. Shared projection Sprint 3 must add

Introduce one read model used by Home, Calendar, Programmes, and
Progress. Suggested name: **current assignment projection**.

| Field | Meaning |
|-------|---------|
| `active` | `status = active` row from `getActiveAssignment` |
| `completedLatest` | newest `status = completed` row when `active` is null |
| `load` | success / loading / unavailable |
| `continuity` | existing `AthleteProgrammeContinuity.project` |

Rules:

- Enrolment eligibility still uses **only** `active`.
- Home complete uses `completedLatest`, not `none`.
- Calendar after complete resolves
  `resolve_fixed_programme_calendar(completedLatest.id)` — existing
  RPC, no new table.
- `none` means no active **and** no completed assignment, after a
  successful read.
- `unavailable` is not `none`.
- Reassigned (superseded) rows stay historical. They are not Home
  today. History keeps their results.
- Unavailable pin and timezone repair remain Sprint 2 states and apply
  only while an **active** assignment exists.

Do not change pin immutability. Do not add assignment repin. Do not
apply hosted repairs.

`AthleteHomeRuntimeAuthority` needs a `completed` value **or** Home
must branch on the projection before calling today’s resolver. Do not
overload `none`.

---

## 7. Cross-surface agreement matrix

| State | Home | Calendar | Progress | History | Programmes |
|-------|------|----------|----------|---------|------------|
| Active + upcoming / today session | Today Begin/Resume | Month with that pin | Active programme + evidence | Athlete records | Continuity current |
| Active + today complete (more remain) | Completed-today card | Completed occurrence | Unchanged programme | New record visible | Current |
| Final session just completed (assignment still active for one refresh) | Completed-today card; no Begin | Last occurrence complete | Evidence includes last session | Last record | Current until refresh |
| Programme fully completed | **Complete state**, not Choose Plan | Completed schedule inspectable | Evidence + completed programme label | Same athlete records | Continuity `completed`; catalogue allowed |
| Completed + historical results | Complete state | Historical month | Not “first session” | Records present | Completed + browse |
| No programme, no history | Choose Plan | No programme scheduled | Genuine empty | Genuine empty | Catalogue |
| No active, existing history (completed or reassigned) | Complete **or** no-active-with-history — never first-run empty if history exists | Completed/historical if completedLatest exists; else empty + history lives on History | Evidence without claiming an active plan | Records | Catalogue; completed chip if completedLatest |
| Superseded (reassigned) + new active | Today of **new** pin | New pin calendar | Active = new; history includes old | All athlete records | Current = new pin |
| Unavailable pinned version | Sprint 2 unavailable | Sprint 2 unavailable | Error or last good; not empty-as-none | Unchanged | Unavailable |
| Missing/invalid timezone | Sprint 2 repair-required; no launch | Same | Last good / repair, not empty | Unchanged | Repair-required |
| Authenticated athlete context missing | Fail closed | Fail closed | Fail closed | Fail closed | Fail closed |
| Coach-only account | Must not authorise athlete History/Progress; fail closed | Fail closed | Fail closed | Fail closed | Fail closed |
| Progress repository failure | Home unchanged if its read succeeded | Unchanged | Typed error + retry; keep last good | Unchanged | Unchanged |
| History repository failure | Unchanged | Unchanged | Must not inherit History failure as empty if Progress assignment read succeeded | Typed error + retry | Unchanged |
| Offline + previously loaded | Keep last Home truth + refresh error | Keep last calendar + error | Keep last Progress + error | Keep last History + error | Keep last + error |
| Stale local draft after hosted completion | No resume; discard draft | Completed occurrence | Hosted records | Hosted records | Completed or current from hosted |

**Current contradictions Sprint 3 must close**

1. Completed assignment → Home `none` / Calendar empty / Programmes
   unassigned / Progress maybe empty or history-only.
2. Progress catch-all → empty.
3. Identity fallback → `'athlete.local'`.
4. Home runtime has no completed class.

**Authoritative resolution:** hosted assignment status + hosted
session records + `CurrentUserSession` athlete id. Never infer
no-programme from a failed read. Never infer empty Progress from a
failed read.

---

## 8. Scope decision

**Sprint 3 name:** Programme Completion and History Integrity
**(approved 2026-09-24)**

**Approved implementation boundary**

- Current-assignment projection (active vs completed vs none vs error)
- Programme-complete Home (and Programmes Continuity `completed`)
- Calendar inspect of the completed assignment via existing
  assignment-id calendar RPC
- Progress typed load / empty / error; keep last good data
- Remove production `'athlete.local'` fallback; fail closed
- History fail-closed identity; keep its existing error UI
- Coach-only must not authorise athlete History / Progress
- Cross-surface agreement tests for the matrix above

This boundary is **approved**. Production tracing confirmed it.
The Home gap is caused by the same active-only read that empties
Calendar and Programmes. Progress empty-as-error and History fallback
are the integrity half of the same athlete-context contract.

| Item | Classification |
|------|----------------|
| Honest programme-complete Home | **Required in Sprint 3** |
| Consistent completed-assignment projection | **Required in Sprint 3** |
| Calendar inspect of completed programme | **Required in Sprint 3** |
| Progress error-versus-empty | **Required in Sprint 3** |
| Keep last good Progress/History on refresh fail | **Required in Sprint 3** |
| Remove `athlete.local` production fallback | **Required in Sprint 3** |
| History fail-closed / retry | **Required in Sprint 3** |
| Coach-only fail-closed on athlete History/Progress (and no synthetic shell identity) | **Required in Sprint 3** |
| Cross-surface agreement tests | **Required in Sprint 3** |
| Enrol in another programme via existing no-active RPC | **Required to remain available**; no new mutation |
| Programme title instead of `lineageCode` on Progress | **Deferred non-blocking** (honesty improvement; not a named launch blocker) |
| Active-programme replacement transaction | **Out of Complete Athlete Experience** until separately approved |
| Hosted data repair / migration apply | **Out** |
| Athlete-defined Performance Portfolio | **Out of Complete Athlete Experience** |
| Radar / trends / invented PRs | **Out**; do not expand in Sprint 3 |
| Settings / timezone repair apply | **Out** (Sprint 2 repair-required remains) |
| Field Manual, phone, WOD Timer, Whiteboard, wearables, payments, Android, offline completion queue, blue brand | **Out** |
| Full coach product shell | **Deferred**; coach platform frozen. Sprint 3 only fail-closes athlete surfaces |
| Programme library authorship | **Out** (next roadmap item after CAE) |

**Included when implementation is later authorised**

- Authoritative current-assignment projection: active, most-recent
  completed, and none
- Completed-programme Home state with View results / Browse programmes
- Assignment-specific completed Calendar inspection using existing
  `resolve_fixed_programme_calendar(assignment_id)`
- Completed continuity on Programmes
- Progress error-versus-empty correction and safe last-good retention
- Removal of production `athlete.local` fallbacks
- Fail-closed History and Progress identity; coach-only denial
- Sign-out and account-switch isolation
- Cross-surface agreement and restart tests

**Excluded**

- New completion mutation authority
- Replacement or repinning
- Programme recommendation or matching
- Automatic next programme
- Progress metric redesign
- Athlete-defined Performance Portfolio
- Adaptation, payments, offline completion queue, wearables
- WOD Timer, Whiteboard, blue-brand work
- Hosted data repair

**Can Sprint 3 close Complete Athlete Experience?** **Yes**, if the
required row is implemented and tested. A Sprint 4 is **not** required
for this milestone. Remaining athlete-launch gaps (library depth,
adaptation engine, wearables, commercial) are **later roadmap items**,
not a fourth CAE sprint. Sprint 3 is **not** implemented and the
milestone is **not** closed.

---

## 9. Founder decisions

### 9.1 Historical options (audit, 2026-09-24)

The audit listed three product choices. They are preserved here and
are superseded by §9.2.

| # | Choice | Then recommended |
|---|--------|------------------|
| 1 | Home complete primary action | View results; secondary Browse programmes |
| 2 | Immediate new enrol from Home | Allow, do not force |
| 3 | Celebration level | Factual “You finished {authored title}.” |

Identity, error-versus-empty, completed≠active for enrol, and no
replacement transaction were already repository authority, not
founder options.

### 9.2 Resolved (2026-09-24)

| Decision | Binding |
|----------|---------|
| Architecture | **Approved.** `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=APPROVED_NOT_STARTED` |
| Sprint name | **Programme Completion and History Integrity** |
| Implementation | **Approved, not started.** `NEXT_IMPLEMENTATION_AUTHORISED=false` until a later implementation task |
| Completed Home | Factual state: “You finished {authored programme title}.” Primary **View results**. Secondary **Browse programmes**. No improvement, transformation, goal, readiness, fitness, or personal-best claims unless separately supported by authoritative evidence |
| Next programme | Completed assignment is **not** active. Immediate browse/enrol through the **existing** no-active-programme flow is allowed. Do **not** force enrol, auto-enrol, recommend a programme, repin/replace, create urgency, or hide completed results behind enrolment |
| Completion continuity | Completed assignment remains the current historical programme context until a later **active** assignment exists. Home complete; View results → authoritative completed evidence; Calendar inspect via existing assignment-specific resolver; Programmes completed continuity; Progress keeps that assignment’s evidence; History keeps athlete-scoped records; later enrol creates a **new** active assignment and must not rewrite the completed assignment or its history |
| Identity and errors | Architectural requirements, not options: remove production `athlete.local`; authoritative athlete identity only; coach-only does not authorise athlete Progress/History; absent context fails closed; genuine empty only after successful empty read; loading/auth/repository/parse/offline failures must not masquerade as empty; retain last truthful Progress/History on refresh failure where safe; never mix athletes, assignments, sessions, or programme versions |

---

## 10. Explicit non-goals

- Replacement / repin / automatic upgrade
- Hosted migration apply or data repair
- New completion RPC
- Progress composition as a portfolio product
- Daily Journey contract reopen
- Preview-as-production credit
- Field Manual, phone installation, real athlete mutation

---

## 11. Acceptance gates (when implementation is authorised)

1. Final-session completion persists `status = completed` and Home
   shows programme-complete, not Choose Plan.
2. Calendar after complete shows the completed assignment, not
   first-run empty, when that assignment exists.
3. Programmes Continuity `completed` mounts from the completed row.
4. No-active enrol remains the only new-programme mutation.
5. Completed assignment does not block that enrol.
6. Progress failure ≠ empty; retry present; last good data retained.
7. Genuine Progress empty only after successful empty evidence query.
8. Production surfaces never select `'athlete.local'`.
9. Missing athlete identity fail-closes; coach-only cannot open
   athlete History / Progress.
10. History after later enrol still lists prior programme records.
11. Offline/refresh failure does not erase last truthful state.
12. Stale local draft after hosted completion does not resume.
13. Cross-surface matrix tests cover the rows in §7 that Sprint 3
    owns.
14. No hosted apply. No pin mutation. No Performance Portfolio.

---

## 12. Explicit non-actions

This approval task must not and did not implement Sprint 3, change
Dart/SQL/fixtures, create a preview, contact hosted systems, install a
phone build, push, or mark Sprint 3 implemented.
