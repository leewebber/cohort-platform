# Complete Athlete Experience Sprint 2 v1

**Status:** Binding architecture for Sprint 2. Audited. **Not approved.
Not started. Not implemented.**
**Recorded:** 2026-09-23
**Evidence:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md)
**Parent:**
[`Complete_Athlete_Experience_v1.md`](./Complete_Athlete_Experience_v1.md)
**Sprint 1 (complete on `origin/main`):** `a3cd3512093f4dc96843e01ab0efe311671e4db9`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=AUDITED_AWAITING_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
```

This document binds the truthful production design for enrolment start
integrity and programme continuity. It is **not** an implementation
licence and does **not** approve a replacement transaction.

---

## 1. What Sprint 2 is

Sprint 1 closed:

```text
discover → inspect authored detail → compare → explicit enrol
```

Sprint 2 must make the next facts true:

1. Enrolment start date and timezone are IANA-valid and honest.
2. The assignment remains pinned to the exact programme version.
3. A catalogue-default change does not move the athlete.
4. The athlete can understand that their current programme is unchanged.
5. Replacement, if later permitted, is a designed explicit journey —
   not a hidden reuse of enrolment.

No automatic programme update. No in-place repin. No assignment rewrite
of `programme_version_id`.

---

## 2. Production enrolment path (proven)

```text
Programmes (AthleteProgrammeSelectionScreen)
  → detail (AthleteProgrammeDetailScreen)
  → review (AthleteProgrammeEnrolmentReviewScreen._confirm)
  → AthleteProgrammeSelectionController.confirmEnrol
       (replaceActive forced false)
  → AthleteCatalogueEnrolmentService.enrol
  → AthleteCatalogueEnrolmentSupabaseStore
  → RPC enrol_athlete_in_catalogue_programme_version
       auth.uid() athlete; p_programme_version_id exact pin;
       p_timezone stored unvalidated; started_at = CURRENT_DATE
  → programme_assignments.programme_version_id pin
  → Start Programme (separate)
       AthleteProgrammeScreen._startProgramme
       → start_fixed_programme_from_enrolment
       → materialise + ensure_programme_schedule_projection
  → Home / Calendar
       resolve_active_fixed_programme_calendar
       today = (now AT TIME ZONE assignment.timezone)::date
  → Daily Journey
       create_or_resume_fixed_programme_occurrence_session
       prepare/restore use assignment.programmeVersionId + hash
```

| Fact | Authority | Current production |
|------|-----------|--------------------|
| Programme version | Catalogue `programme_versions.id` chosen on detail/review | Exact UUID through RPC. Never “latest”. |
| Athlete identity (mutation) | `auth.uid()` + `cohort_auth_is_athlete()` | Hosted. Client `athleteId` is not sent to the enrol RPC. |
| Enrol start date | RPC `CURRENT_DATE` | Review `startedAt: DateTime.now()` is **not persisted**. |
| Schedule start date | Start Programme `p_start_date` | Device-local date picker, not assignment-zone “today”. |
| Timezone at enrol | `DateTime.now().timeZoneName` | Abbreviation (`BST`, `WITA`), **not** IANA. Enrol RPC does not validate. |
| Timezone at Start / calendar | `programme_assignments.timezone` | Validated against `pg_timezone_names`. Invalid → fail closed. |
| Occurrence dates | `started_at + day_offset` | Consecutive DATE math. Timezone labels “today”; it does not place hours. |
| Pin | `programme_assignments.programme_version_id` | Immutable. `content_graph_prevent_assignment_repin`. |
| Catalogue default | Single eligible version per lineage after atomic archive/approve | List filter only. Execution never follows default. |

Client `'athlete.local'` fallbacks exist on Home / Profile / Progress /
shell **reads**. They are never enrolment mutation identity. They remain
Sprint 3 launch blockers.

---

## 3. Timezone verdict

Persisted field: `programme_assignments.timezone` (TEXT). Documented as
IANA. Production enrol currently writes a device abbreviation.

### Candidate authorities

| Source | Verdict |
|--------|---------|
| Device IANA identifier | **Preferred capture hint** if a real IANA name is available (`flutter_timezone` / platform API). Must be validated against `pg_timezone_names` before persist. Not yet in the repo. |
| Hosted athlete-profile timezone | **Missing.** `AthleteProfile` has no timezone. |
| Explicit athlete choice at enrol/onboarding | **Strongest confirmation.** Required when device IANA is missing, ambiguous, or disagrees with a prior assignment zone. |
| Platform abbreviation (`BST`, `GMT`, `WITA`, `KST`) | **Not authoritative.** Ambiguous, DST-unsafe, rejected by Start/calendar IANA checks. |
| UTC offset only | **Not authoritative.** Loses DST and location identity. |

### Required persisted values

| Athlete | Persist |
|---------|---------|
| Bali (WITA) | `Asia/Makassar` |
| United Kingdom | `Europe/London` |

Do not persist `WITA`, `BST`, `GMT`, or a numeric offset as the programme
timezone.

### Travel and device change

- A programme remains **anchored to the assignment timezone** captured
  (after Sprint 2: validated IANA) at enrol / Start.
- Device timezone change **must not** silently rewrite `started_at`,
  occurrence dates, or “today”.
- Travel after enrolment does **not** move scheduled days. A later
  explicit “move my programme days” product — if ever approved — is
  scheduling authority, not silent enrol mutation.
- If the device cannot provide a valid IANA zone: **fail closed** at
  enrol. Offer an explicit validated zone picker. Do not guess from
  offset or city name similarity.

### Existing invalid rows

Assignments already storing abbreviations, offsets, empty, or unknown
names:

- Treat as **`timezone_unavailable`** at Start and calendar resolve
  (already fail-closed when `pg_timezone_names` rejects the value).
- Do not auto-map `BST` → `Europe/London` or `WITA` → `Asia/Makassar`.
- Surface an honest repair: athlete confirms a validated IANA zone
  before Start / before calendar can label TODAY.
- Do not invent a silent migration of occurrence dates.

### Schema

A new column is **not** required if Sprint 2 validates IANA into the
existing `timezone` TEXT. Enrol RPC **does** need validation (today it
accepts any trimmed string, including NULL). Client-only correction is
**not** sufficient: Start and calendar already require IANA, and enrol
can persist a value those RPCs will later reject.

---

## 4. Pinned version versus catalogue default

**Authoritative version for a current athlete is always the assignment
pin.** Catalogue default is the unique currently eligible published
version for new enrolment. There is no production `catalogue_default`
column; eligibility is `published` + `cohort_global` + approved + not
archived.

| State | Authoritative version | Home | Programmes | Calendar | Compare | Actions | Sessions |
|-------|----------------------|------|------------|----------|---------|---------|----------|
| Pin == current default | Pin | Pin today | Current chip on that row | Pin name + occurrences | Current vs Available | Train / inspect | Unchanged |
| Pin older, still eligible | Pin | Pin today | Current on pin; other Available | Pin | Aligned facts | Inspect/compare only | Unchanged |
| Pin older, superseded (archived after replacement) | Pin (still the assignment) | Calendar/prepare **fail closed** (`exact_version_missing`) | Current card can still show **old title** via `getVersionById`; catalogue lists **new** default with no Current chip | Unavailable + Retry | New default Available; pin often **absent** | No switch. No honest “your version was retired” | Must not be rewritten |
| Pin executable but not listed | Pin | May fail at prepare/calendar | Current card shows pin | Error | Pin not listed | Inspect pin on overview only | Unchanged until fail-closed |
| Pin withdrawn / unavailable | Pin | Fail closed | Overview may still name pin | Fail closed | Absent / unavailable | No enrol, no hidden repair | Unchanged; no silent default |
| Default changes mid-programme | Pin | Unchanged if pin still published; fail closed if archived | Catalogue shows new default | Pin or fail closed | New Available | No auto-update | Unchanged |
| Later version title/metadata changes | Pin metadata | Pin title | Overview pin title; catalogue new title | Pin title | Different titles, no version number | Do not imply the athlete moved | Unchanged |
| Assignment exists, graph/manifest missing | Pin + programme tree | Execution uses version tree, not M9 manifest | Normal if version loads | Normal if version valid | Normal if listed | Graph is not athlete authority | Unchanged |
| Programme completes; newer default exists | Completed pin | Plan Complete (pin name); no next-programme CTA | Active may end; catalogue shows default | Historical pin occurrences | N/A | Completion aftermath is Sprint 3 | History stays on pin |
| No assignment; latest default | None | Choose programme | Catalogue list (athlete picks exact id) | Empty | Two explicit versions | Enrol exact version | N/A |
| Offline; default metadata changes | Server pin unchanged | Stale or error | Error / stale | Error | Stale | Retry. No local enrol | Unchanged on server |

**Must fail closed:** archived/withdrawn pin on prepare, calendar, start
session, and completion. **Must not** resolve catalogue default as a
substitute.

**Truthful copy (Sprint 2 product, not yet implemented):**

- Current programme (this exact version)
- Catalogue default for new athletes (not your programme)
- A newer version exists; your scheduled sessions are unchanged
- This version is no longer available to train

Current chips are only Current / Available / Not available. That is
**misleading after catalogue replacement**.

---

## 5. Replacement journey — design only

**Not authorised.** Sprint 2 may specify the journey. It must not
implement RPC, schema, or UI for replacement.

Existing hosted model (evidence, not a product CTA):

`enrol_athlete_in_catalogue_programme_version(..., p_replace_active true)`
ends the active row (`reassigned` + `superseded_by_assignment_id`) and
**inserts** a new assignment. `content_graph_prevent_assignment_repin`
forbids in-place pin mutation.

### Models compared

| Model | Evidence | Verdict |
|-------|----------|---------|
| 1. Mutate current assignment pin | Trigger forbids `programme_version_id` UPDATE | **Rejected** |
| 2. End current + create new | Enrol RPC + local `cancelOrReplaceActiveAssignment` | **Recommended if later approved** |
| 3. Versioned assignment epochs | Not present in production identity | Unnecessary; assignment rows already chain |
| 4. Other | M9 local `catalogueDefault` enrol is not the athlete shell | Do not adopt as production authority |

**Recommended model (unresolved founder decision for the transaction):**
end the current assignment and create a new one. Keep history on the old
`assignment_id`. Do not migrate outcomes.

### Design answers (binding if the transaction is later approved)

| Question | Binding answer |
|----------|----------------|
| Where may it begin? | Explicit action on another programme’s detail or a dedicated review — never catalogue-default change, never comparison winner, never Home today. |
| Prerequisites | Authenticated athlete; active assignment; target version catalogue-eligible; no in-flight uncertain prior replace. |
| Mid-programme? | Yes only as an explicit product; history stays on the old assignment. |
| Completed history | Remains on old assignment / version. |
| Future occurrences | Old projection stays historical; new assignment gets a new baseline after Start. |
| In-progress draft | Must be discarded or fail closed before replace. Unbound in current enrol path — must be specified before any transaction. |
| Accepted adaptations | Prepared-session only; must not follow the new assignment. Unbound today. |
| New start date | New assignment Start Programme date — not silent `CURRENT_DATE` reuse. |
| Timezone | Validated IANA; default to current assignment zone unless the athlete confirms another. |
| Old assignment | `reassigned` + `superseded_by_assignment_id`. |
| Idempotency | Same target + already active → `already_enrolled`. Uncertain RPC → reconcile to pin; do not double-insert. |
| Confirmation | Name exact target version; state that scheduled future days restart; state history is kept; no “upgrade”. |
| Uncertain RPC | Honest failure + retry; reconcile by reading active pin. |
| Return to old programme | Only if that version is still catalogue-eligible; otherwise fail closed. |
| Completed vs mid-programme | Completed programme is a **new enrol** after completion (Sprint 3 Home), not this replace path. |
| Default moves between review and confirm | Confirm the reviewed `programme_versions.id` only. No silent fallback. |

---

## 6. Cross-surface honesty

| Surface | Sprint 2 effect | Risk if ignored |
|---------|-----------------|-----------------|
| Discovery | Show pin vs default; do not hide the athlete’s version | Catalogue lists only the new default; Current chip vanishes |
| Detail / compare | Authored facts of the **selected version id** | Mixing new title with pinned sessions |
| Enrolment review | IANA + exact version; no replace | Abbreviation persist; dead `startedAt` |
| Current overview | Pin metadata + honesty if superseded | Overview succeeds while Calendar fails |
| Home Today | Pin calendar today; fail closed if pin archived | Looks like no programme, or wrong day |
| Calendar | Same RPC today as Home | Device picker vs assignment zone disagreement |
| Session detail / DJ restore | Pin + hash | Never follow newer default |
| Completion | Pin + hash | Do not complete onto a default |
| Progress / History | Out of Sprint 2 except they must not gain a default-follow | Error-as-empty and `athlete.local` remain Sprint 3 |
| Offline | No local catalogue mutation | Stale list; server pin unchanged |
| Profile timezone | Missing; do not invent a settings product in Sprint 2 unless required for IANA repair | — |
| Coach / M10 | No enrolment or switch authority | Catalogue visibility ≠ assignment mutation |

Daily Journey execution authority is **unchanged**: exact pin + package
hash. Sprint 2 must not open a path that prepares a newer default.

---

## 7. Security and tenant boundaries

- Mutation identity: `auth.uid()` only.
- Coach-only identity does not authorise athlete enrolment or replace.
- Publisher ownership and M10 membership do not enrol or switch.
- Catalogue eligibility is visibility, not assignment authority.
- Display-name / email / `athlete.local` are never identity.
- Any future replace requires athlete authority, exact version id, and
  idempotency.

---

## 8. Recommended Sprint 2 implementation boundary

**Goal:** An enrolled athlete’s start day and timezone are IANA-true, and
every athlete-visible surface tells the truth about the pinned version
versus the catalogue default — without moving the pin.

**Include**

- Validated IANA capture at enrol (device IANA if valid, else explicit
  picker). Persist only `pg_timezone_names` names.
- Enrol RPC rejects non-IANA / empty timezone.
- Honest start-date story: enrol `CURRENT_DATE` remains inert; Start
  Programme date is assignment-zone today unless the athlete picks
  another date in that zone.
- Pin-versus-default status on Programmes overview, discovery, detail,
  and comparison (no winner, no recommendation).
- Unified fail-closed copy when the pin is withdrawn/unavailable.
- Fixture preview of honesty and timezone-repair states.
- Replacement journey remains **architecture only**.

**Required changes (if later implemented)**

- Client: IANA source + validation; review/start copy; status projection.
- RPC: validate `p_timezone` on enrol (existing column).
- Migration: likely a function change only; **stop** if a new column or
  occurrence rewrite is required without a separate founder decision.
- Compatibility: existing abbreviation rows fail closed with explicit
  repair; no silent remap.

**Do not include**

- Replacement transaction or `replaceActive: true` product path
- In-place repin
- Automatic default follow
- Occurrence date rewrite on travel
- Progress/History identity/error-as-empty (Sprint 3)
- Coach-shell routing
- Profile/settings product beyond the minimum IANA repair
- Matching, adaptation, payments, WOD Timer, Performance Portfolio

**Founder decisions required before implementation**

1. Approve this Sprint 2 boundary (IANA + honesty, not replacement).
2. Confirm persist values `Asia/Makassar` / `Europe/London` and
   fail-closed invalid capture.
3. Confirm travel does not move scheduled days without a later explicit
   scheduling product.
4. Confirm replacement remains design-only (recommended model: end+create).
5. Confirm existing abbreviation assignments require explicit IANA repair
   rather than guessed mapping.

---

## 9. Explicit non-actions

This architecture task must not and did not implement Sprint 2, approve
the replacement transaction, change production Dart/SQL, contact Field
Manual, install a phone build, or push.
