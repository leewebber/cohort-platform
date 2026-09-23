# Complete Athlete Experience Sprint 2 v1

**Status:** Binding architecture for Sprint 2. Founder decisions
**approved**. Local implementation is **awaiting founder approval.**
**Recorded:** 2026-09-23
**Decisions bound:** 2026-09-23
**Evidence:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md)
**Parent:**
[`Complete_Athlete_Experience_v1.md`](./Complete_Athlete_Experience_v1.md)
**Sprint 1 (complete on `origin/main`):** `a3cd3512093f4dc96843e01ab0efe311671e4db9`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
HOSTED_REPAIR_AUTHORISED=false
```

This document binds the approved Sprint 2 product. It is **not** an
implementation licence. A later task must separately authorise code
changes. It does **not** approve a replacement transaction or hosted
timezone repair.

---

## 1. What Sprint 2 is

Sprint 1 closed:

```text
discover → inspect authored detail → compare → explicit enrol
```

Sprint 2, when separately implemented, must make these facts true:

1. Enrolment start date and timezone are IANA-valid and athlete-local.
2. The assignment remains pinned to the exact programme version.
3. A catalogue-default change does not move the athlete.
4. The athlete can understand that their current programme is unchanged.
5. Replacement remains a designed explicit journey — not a hidden reuse
   of enrolment, and not part of this sprint’s implementation.

No automatic programme update. No in-place repin. No assignment rewrite
of `programme_version_id`.

---

## 2. Production enrolment path (proven)

Historical production evidence as of `a3cd351`. Sprint 2 must correct
the dishonest start-date and timezone facts below; it must not reopen
the pin.

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

| Fact | Authority | Current production (pre-Sprint 2) |
|------|-----------|-----------------------------------|
| Programme version | Catalogue `programme_versions.id` chosen on detail/review | Exact UUID through RPC. Never “latest”. |
| Athlete identity (mutation) | `auth.uid()` + `cohort_auth_is_athlete()` | Hosted. Client `athleteId` is not sent to the enrol RPC. |
| Enrol start date | **Must become** IANA-local date in the enrol transaction | RPC `CURRENT_DATE` today. Review `startedAt: DateTime.now()` is **not persisted**. |
| Schedule start date | Existing Start Programme `p_start_date` | Device-local date picker. Sprint 2 must **not** add a new future-date product. |
| Timezone at enrol | **Must become** validated IANA | `DateTime.now().timeZoneName` abbreviation. Enrol RPC does not validate. |
| Timezone at Start / calendar | `programme_assignments.timezone` | Validated against `pg_timezone_names`. Invalid → fail closed. |
| Occurrence dates | `started_at + day_offset` | Consecutive DATE math. Timezone labels “today”; it does not place hours. |
| Pin | `programme_assignments.programme_version_id` | Immutable. `content_graph_prevent_assignment_repin`. |
| Catalogue default | Single eligible version per lineage after atomic archive/approve | List filter only. Execution never follows default. |

Client `'athlete.local'` fallbacks exist on Home / Profile / Progress /
shell **reads**. They are never enrolment mutation identity. They remain
Sprint 3 launch blockers.

---

## 3. Founder decisions (2026-09-23)

These replace the audit’s unresolved list. They do not erase the
production-path evidence.

### 3.1 Sprint 2 boundary — approved, not started

**Included**

- Validated IANA timezone capture during enrolment.
- Truthful athlete-local enrolment start date.
- Server validation and persistence.
- Pinned programme version versus catalogue-default status projection.
- Truthful current / default / superseded / unavailable messaging.
- Unified fail-closed unavailable-pin handling across affected athlete
  surfaces.

**Excluded**

- Replacement transaction
- Assignment repin
- Automatic upgrade
- Programme completion work
- Progress / History work
- Travel rescheduling
- General profile / settings redesign
- Programme matching
- Adaptation
- Payments
- Wearables
- Offline completion queue

**Flag:** `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL`.
Local implementation is **not** complete until founder approval.

### 3.2 Timezone authority

- Persist **validated IANA identifiers only**.
- Bali example: `Asia/Makassar`.
- UK example: `Europe/London`.
- Device IANA is a **suggested default**, not unquestioned authority.
- Enrolment review must **visibly show** the selected training timezone.
- The athlete may change it before confirmation.
- The server validates against PostgreSQL timezone authority
  (`pg_timezone_names`).
- Invalid or missing timezone **fails closed** and requires explicit
  selection.
- Never persist or infer from `BST`, `GMT`, `WITA`, `KST`, UTC offsets,
  or similar abbreviations.
- Never guess a geographic zone from an abbreviation or offset.

### 3.3 Start-date authority

This **overrides** the 2026-09-23 audit recommendation that enrol
`CURRENT_DATE` remain inert.

- The server derives the enrolment start date in the **validated
  selected IANA timezone**.
- Do **not** use database-session `CURRENT_DATE` as a timezone-neutral
  proxy.
- Do **not** treat the existing decorative client `DateTime.now()`
  review value as persisted authority.
- At confirmation, derive the local calendar date using the validated
  zone **inside the authoritative transaction**.
- Return or project the persisted `started_at` so the success state can
  truthfully confirm it.
- Enrolment review must show:
  - selected training timezone
  - intended athlete-local start date
  - exact programme / version commitment in product language
- If the date cannot be determined consistently, **fail closed** before
  creating an assignment.
- Do **not** add arbitrary future start-date selection. The existing
  Start Programme date control is historical production, not a new
  Sprint 2 date product. Review previews the IANA-local date the server
  will persist; it is not a future-date picker.

### 3.4 Travel policy

- An active programme remains **anchored** to the timezone selected at
  enrolment.
- Device timezone changes do **not** silently modify the assignment
  timezone.
- Travel does **not** silently move scheduled sessions between calendar
  days.
- The UI may explain that programme dates remain on the training
  timezone.
- Changing an active programme timezone is a **future explicit
  rescheduling product** and is outside Sprint 2.

### 3.5 Existing invalid timezone data

- Existing missing, abbreviated, offset-only, or invalid assignment
  timezone values require **explicit repair**.
- No guessed conversion (`BST` ↛ `Europe/London`, `WITA` ↛
  `Asia/Makassar`).
- Repairs must be separately inventoried and authorised before any
  hosted mutation (`HOSTED_REPAIR_AUTHORISED=false`).
- Sprint 2 **may** implement a fail-closed repair-required state and
  the safe repair mechanism. It **must not** perform hosted repairs
  without separate founder approval.
- Preserve assignment identity, programme-version pin, history, and
  occurrence integrity during any eventual repair.
- The implementation plan must determine whether occurrences require
  controlled regeneration or whether timezone-only repair is
  sufficient. **Do not assume.**

### 3.6 Pinned version and catalogue default

- Assignment `programme_version_id` is **execution authority**.
- Catalogue default is **discovery / listing authority only**.
- A catalogue-default change never upgrades, repins, or rewrites an
  athlete assignment.
- Home, Calendar, programme overview, and Daily Journey must
  consistently present the **pinned** version.
- The product must distinguish:
  - current and current-default
  - current but not current-default
  - newer / different version available
  - superseded but still executable
  - unavailable / withdrawn pinned version
- Do not use internal terms such as hash, manifest, graph, or
  superseded unless translated into athlete-facing language.
- Never mix newer catalogue metadata with sessions from the pinned
  version.
- Unavailable pinned execution fails closed with **one consistent,
  honest recovery message**.

### 3.7 Future replacement model — architecture only

**Approved as architecture, not as a product or transaction:**

- End the current assignment.
- Preserve it and its history.
- Create a new assignment pinned to the explicitly reviewed programme
  version.
- Link the transition through reassignment lineage such as
  `superseded_by_assignment_id`.
- Never mutate the old assignment’s programme-version pin.
- Replacement must eventually be athlete-authorised, explicit, and
  idempotent.

**Still unresolved and not approved for implementation:**

- Mid-programme eligibility
- Draft / adaptation aftermath
- Future occurrence cancellation
- Return-to-old-programme rules
- Replacement RPC / schema
- Commercial entitlement
- Replacement UI

Do not create any replacement implementation in Sprint 2.

---

## 4. Timezone and start-date design (binding)

Persisted field: `programme_assignments.timezone` (TEXT). Persist only
validated IANA names.

### Capture strategy (implementation, when authorised)

| Platform | Strategy |
|----------|----------|
| iOS | Device IANA via a validated platform API / plugin. Use as suggested default only after `pg_timezone_names` (or an equivalent published IANA list the server will accept) matches. |
| Android | Same. |
| Web | Same. Browser abbreviations (`BST`, `GMT`) are **never** persisted. |
| Missing / invalid / abbreviation | Fail closed. Explicit validated zone picker. No offset or city-name guess. |

A new column is **not** required if Sprint 2 validates IANA into the
existing `timezone` TEXT. Enrol RPC **does** need validation. Client-only
correction is **not** sufficient.

### Start date in the transaction

```text
validated IANA zone
  → (transaction_now AT TIME ZONE selected_zone)::date
  → persist as programme_assignments.started_at
  → return started_at + timezone + programme_version_id
```

If zone validation fails, create **no** assignment.

The existing Start Programme path may still materialise occurrences.
Sprint 2 must not let that path silently rewrite the enrol timezone or
move days because the device zone changed. It must not invent a new
enrolment-review future-date picker.

---

## 5. Pinned version versus catalogue default

**Authoritative version for a current athlete is always the assignment
pin.** Catalogue default is the unique currently eligible published
version for new enrolment. There is no production `catalogue_default`
column; eligibility is `published` + `cohort_global` + approved + not
archived.

| State | Authoritative version | Home | Programmes | Calendar | Compare | Actions | Sessions |
|-------|----------------------|------|------------|----------|---------|---------|----------|
| Pin == current default | Pin | Pin today | Current and current-default | Pin name + occurrences | Current vs Available | Train / inspect | Unchanged |
| Current but not current-default | Pin | Pin today | Current; other row may be default | Pin | Aligned facts | Inspect / compare only | Unchanged |
| Newer / different version available | Pin | Pin today | Current on pin; Available on other | Pin | Authored facts of selected ids only | No auto-update | Unchanged |
| Superseded but still executable | Pin | Pin today | Honest “your programme is unchanged” | Pin | Do not mix metadata | Train on pin | Unchanged |
| Pin withdrawn / unavailable | Pin | Fail closed | Same recovery copy | Fail closed | Absent / unavailable | No enrol, no hidden repair | Unchanged; no silent default |
| Default changes mid-programme | Pin | Unchanged if pin executable; fail closed if withdrawn | Catalogue shows new default | Pin or fail closed | New Available | No auto-update | Unchanged |
| Later version title/metadata changes | Pin metadata | Pin title | Overview pin title; catalogue new title | Pin title | Different titles | Do not imply the athlete moved | Unchanged |
| Assignment exists, graph/manifest missing | Pin + programme tree | Execution uses version tree, not M9 manifest | Normal if version loads | Normal if version valid | Normal if listed | Graph is not athlete authority | Unchanged |
| Programme completes; newer default exists | Completed pin | Out of Sprint 2 (Sprint 3 Home) | Catalogue default for new enrol | Historical pin occurrences | N/A | Completion aftermath is Sprint 3 | History stays on pin |
| No assignment; latest default | None | Choose programme | Catalogue list (athlete picks exact id) | Empty | Two explicit versions | Enrol exact version | N/A |
| Offline; default metadata changes | Server pin unchanged | Stale or error | Error / stale | Error | Stale | Retry. No local enrol | Unchanged on server |

**Must fail closed:** archived/withdrawn pin on prepare, calendar, start
session, and completion. **Must not** resolve catalogue default as a
substitute.

Athlete-facing copy (product language, not internal terms):

- This is your current programme, and it is the current offering
- This is your current programme; a different version is now listed
- A newer version exists; your scheduled sessions are unchanged
- This programme version is no longer available to train

---

## 6. Replacement journey — architecture only

**Not authorised for implementation.**

Existing hosted model (evidence, not a product CTA):

`enrol_athlete_in_catalogue_programme_version(..., p_replace_active true)`
ends the active row (`reassigned` + `superseded_by_assignment_id`) and
**inserts** a new assignment. `content_graph_prevent_assignment_repin`
forbids in-place pin mutation.

| Model | Evidence | Verdict |
|-------|----------|---------|
| 1. Mutate current assignment pin | Trigger forbids `programme_version_id` UPDATE | **Rejected** |
| 2. End current + create new | Enrol RPC + local `cancelOrReplaceActiveAssignment` | **Approved architecture** |
| 3. Versioned assignment epochs | Not present in production identity | Unnecessary; assignment rows already chain |
| 4. Other | M9 local `catalogueDefault` enrol is not the athlete shell | Do not adopt as production authority |

Keep history on the old `assignment_id`. Do not migrate outcomes.
Draft / adaptation / occurrence aftermath remain **unbound** and are
not Sprint 2 work.

---

## 7. Cross-surface honesty

| Surface | Sprint 2 effect | Risk if ignored |
|---------|-----------------|-----------------|
| Discovery | Show pin vs default; do not hide the athlete’s version | Catalogue lists only the new default; Current chip vanishes |
| Detail / compare | Authored facts of the **selected version id** | Mixing new title with pinned sessions |
| Enrolment review | Visible IANA + intended local date + exact version; no replace | Abbreviation persist; dead `startedAt` |
| Current overview | Pin metadata + honesty if not current-default | Overview succeeds while Calendar fails |
| Home Today | Pin calendar today; fail closed if pin unavailable | Looks like no programme, or wrong day |
| Calendar | Same RPC today as Home | Device zone vs assignment zone disagreement |
| Session detail / Daily Journey restore | Pin + package identity | Never follow newer default |
| Completion | Pin + package identity | Do not complete onto a default |
| Progress / History | Out of Sprint 2 except they must not gain a default-follow | Error-as-empty and `athlete.local` remain Sprint 3 |
| Offline | No local catalogue mutation | Stale list; server pin unchanged |
| Profile timezone | No general settings redesign. Repair-required state only | Do not invent a settings product |
| Coach / M10 | No enrolment or switch authority | Catalogue visibility ≠ assignment mutation |

Daily Journey execution authority is **unchanged**: exact pin + package
identity. Sprint 2 must not open a path that prepares a newer default.

---

## 8. Security and tenant boundaries

- Mutation identity: `auth.uid()` only.
- Coach-only identity does not authorise athlete enrolment or replace.
- Publisher ownership and M10 membership do not enrol or switch.
- Catalogue eligibility is visibility, not assignment authority.
- Display-name / email / `athlete.local` are never identity.
- Any future replace requires athlete authority, exact version id, and
  idempotency.

---

## 9. Approved implementation boundary (not started)

**Goal:** An enrolled athlete’s start day and timezone are IANA-true, and
every athlete-visible surface tells the truth about the pinned version
versus the catalogue default — without moving the pin.

**Anticipated changes when a later task implements this**

- Client: validated IANA capture (device suggestion + explicit change);
  review copy (zone, intended local date, version commitment); pin vs
  default status; unified unavailable-pin copy; fail-closed
  repair-required state.
- RPC: validate `p_timezone` against PostgreSQL timezone authority;
  derive `started_at` as `(now AT TIME ZONE validated_zone)::date`;
  reject and create no row on failure; return persisted `started_at`.
- Migration: likely a function change only. **Stop** if a new column or
  occurrence rewrite is required without a separate founder decision.
- Compatibility: existing invalid timezone rows fail closed with
  repair-required. No silent remap. No hosted repair apply.
- Local DB Gate AY extension if schema/RPC changes are required.
- Fixture preview of honesty, timezone-repair-required, and
  unavailable-pin states.

**Do not include:** the excluded list in §3.1, `replaceActive: true`
product path, hosted data repair, or occurrence date rewrite on travel.

---

## 10. Acceptance gates (when implementation is authorised)

1. **iOS IANA capture** — device IANA may prefill; only a validated
   IANA name is confirmable.
2. **Android IANA capture** — same.
3. **Web IANA capture** — same; abbreviations never persist.
4. **Server-side IANA validation** — enrol RPC rejects unknown,
   empty, abbreviation, and offset values; no assignment is created.
5. **UTC-midnight local date** — a confirmation near UTC midnight
   persists the athlete-local calendar date in the selected zone, not
   the database session `CURRENT_DATE`.
6. **DST for `Europe/London`** — “today” and `started_at` remain the
   London civil date across a BST/GMT transition; sessions do not jump
   a day.
7. **Non-DST for `Asia/Makassar`** — Bali civil date is stable; no
   offset guess.
8. **Invalid / missing timezone** — fail closed; explicit selection
   required; no row.
9. **Travel / device-zone change** — assignment timezone and scheduled
   days do not silently move.
10. **Idempotent enrolment** — repeat confirm of the same version does
    not create a second assignment.
11. **No assignment on validation failure.**
12. **No pin mutation** — `programme_version_id` remains immutable.
13. **Catalogue-default change without execution change** — Home,
    Calendar, overview, and Daily Journey stay on the pin.
14. **No cross-version metadata / session composition.**
15. **Consistent unavailable-pin handling** — one honest recovery
    message on Home, Calendar, overview, and prepare.
16. **320 / 390 and large-text review layout** — timezone, intended
    date, and version commitment remain readable; no overflow.
17. **Accessible timezone / status wording** — not colour-only; names
    the state in words.
18. **Local DB Gate AY** — required if schema/RPC changes; no hosted
    apply.
19. **No hosted apply or data repair** without separate founder
    approval.

---

## 11. Explicit non-actions

This decision task must not and did not implement Sprint 2, start
implementation, approve the replacement transaction, change production
Dart/SQL, contact Field Manual, install a phone build, apply hosted
repairs, or push.
