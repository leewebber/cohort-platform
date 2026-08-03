# Athlete-Controlled Programme Scheduling v1 — Sprint 1.7A

**Status:** Binding for Phase 1 athlete-controlled programme scheduling  
**Sprint:** 1.7A discovery and binding contract only  
**Depends on:** Sprint 1.4A materialisation, Sprint 1.4B prepared session,
Sprint 1.5A completion/advancement, Sprint 1.6A–1.6E acceptance-gated adaptation  
**Companions:** [Authored_Plan_Package_v1.md](./Authored_Plan_Package_v1.md),
[Athlete_Plan_Materialisation_v1.md](./Athlete_Plan_Materialisation_v1.md),
[Athlete_First_Prepared_Session_v1.md](./Athlete_First_Prepared_Session_v1.md),
[Athlete_Programme_Completion_Advancement_v1.md](./Athlete_Programme_Completion_Advancement_v1.md),
[Athlete_Programme_Acceptance_Gated_Adaptation_v1.md](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md),
[Session_Authority_Model_v1.md](./Session_Authority_Model_v1.md),
[Coaching_Constitution_v1.md](./Coaching_Constitution_v1.md),
[Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md),
ADR-017 (SessionOccurrence identity), ADR-020, ADR-022

**Authority:** This document is the sole binding contract for Sprint 1.7
implementation. Sprint 1.7A authorises documentation, checkpoint alignment, and
architecture-boundary tests only. No athlete-facing scheduling behaviour, UI,
migrations, RPCs, repositories, or Supabase contact are authorised in 1.7A.

---

## Purpose and problem statement

Athletes on a materialised Authored Plan Package need lawful control over
**when** authored programme occurrences are intended to be performed, without
rewriting **what** those occurrences prescribe.

Today Cohort advances programmes by **authored cursor order** after atomic
completion (Sprint 1.5A). There is no durable per-occurrence calendar schedule,
no athlete preview/confirm path for date movement, and no contract-safe skip,
push, swap, or undo authority. Adaptation (Sprint 1.6) deliberately changes only
the current prepared executable prescription and must never become a scheduling
mechanism.

Sprint 1.7 introduces a distinct **assignment scheduling authority** with
explicit preview → confirm → atomic apply semantics.

---

## Repository findings (Sprint 1.7A discovery)

### Current production model

1. **Authored prescription** lives in the pinned programme version tree
   (`programme_version_weeks` / `days` / `session_slots`). Day keys are ordinal
   (`day_N`), not calendar weekdays. Slot `timeOfDay` is informational only.
2. **Assignment** (`programme_assignments`) stores:
   - `started_at` (DATE schedule anchor after materialisation);
   - `timezone` (IANA string);
   - cursor: `current_week_number`, `current_day_key`, `current_slot_order`;
   - materialisation provenance: hash, schema version, materialised_at;
   - lifecycle status including `paused`.
3. **Cursor advancement** is owned exclusively by
   `complete_programme_session_and_advance` (Sprint 1.5A). Traversal uses authored
   package order with **no calendar inference**.
4. **Prepared execution** is local
   (`PreparedExecutionPackage` / `GeneratedSessionRecord`) keyed by
   programme-shaped `ProgrammedSessionKey` provenance. Restore requires matching
   assignment/version/hash/key/day/slot.
5. **Adaptation** mutates only the current prepared executable plan after
   explicit accept; reversion reconstructs via bank/compiler prepare path.
6. **Slot outcomes** (`programme_slot_outcomes`) already include statuses
   `scheduled`, `in_progress`, `completed`, `completed_partial`, `skipped`,
   `rescheduled`, `replaced` — but there is no athlete-controlled scheduling
   product path that lawfully writes skip/reschedule with preview/audit.

### Existing but non-authoritative surfaces

| Surface | Finding |
|---------|---------|
| `SessionOccurrence` domain (`lib/domain/session_occurrence/`) | Canonical workout identity (ADR-017) with in-memory reschedule/skip transitions; **no durable programme schedule port** |
| `ProgrammeOccurrenceMaterializer` / Home bridge | Materialises the **already-current cursor slot** onto `DateTime.now()` in memory; date is not schedule authority |
| `ProgrammedSessionKey.scheduleDate` | Defaults to `assignment.startedAt`; not a computed per-occurrence calendar date |
| Legacy `ProgrammeProgressionService.skipSession` | Writes skipped outcome + direct cursor update; **unsafe** after materialisation RPC hardening; not athlete scheduling UX |
| `ProgrammeAssignmentService.pause/resume` | Status API exists; post-materialisation status writes are RPC-protected; no dedicated pause/resume scheduling RPC found |
| Adaptation 1.6 contract proposed Sprint 1.7 principles | Confirmed distinct authority; listed move/swap/push/skip/undo/preview as non-goals of adaptation |

### Persistence gap

No durable table or RPC today stores a per-occurrence **scheduled calendar date**,
schedule revision, or scheduling operation log. Sprint 1.7 therefore requires a
new durable schedule projection (documented below; not implemented in 1.7A).

---

## Terminology

| Term | Meaning |
|------|---------|
| **Authored occurrence** | One immutable programme version session slot in authored order |
| **Scheduled occurrence** | An authored occurrence plus an athlete-intended calendar date |
| **Authored order** | Fixed package order: week → day_order → session_order |
| **Scheduled date** | Athlete-local calendar date (`YYYY-MM-DD` in assignment timezone) for an occurrence |
| **Programme cursor** | Persisted assignment pointer to the next due authored occurrence for completion progress |
| **Due occurrence** | The uncompleted authored occurrence that Today treats as current, after schedule + cursor rules |
| **Schedule revision** | Monotonic revision / fingerprint of the durable schedule projection |
| **Scheduling operation** | One previewed, confirmed, atomic transition (move, swap, push, skip, undo) |
| **Preview** | Compute-only proposed schedule effect with stable fingerprint |
| **Collision** | Two or more uncompleted occurrences sharing one scheduled date |

---

## Authority hierarchy

1. **Authored Plan Package / programme version** — immutable prescription authority
   for structure, content, and authored order.
2. **Assignment scheduling projection** — athlete-intended calendar placement of
   authored occurrences (Sprint 1.7 authority).
3. **Programme cursor** — next due authored occurrence for completion progress;
   advanced by Sprint 1.5A completion or by a **contract-defined scheduling
   cursor transition** (skip only, see below).
4. **Prepared execution** — local executable package for one programmed key;
   adapted only via Sprint 1.6.
5. **Completion evidence** — athlete-entered actuals; append-only; Sprint 1.5A.

Scheduling may change (2) and, only where expressly defined, (3). It must not
rewrite (1), (4)’s prescription content, or (5).

### Authority and ownership table

| Concern | Owner | May change |
|---------|-------|------------|
| Prescription content / authored order | Plan Package / version store | Never via scheduling |
| Scheduled calendar dates | Future scheduling service + durable projection | Move / swap / push / undo |
| Skip disposition | Future scheduling service + slot outcome | Skip / undo (where lawful) |
| Completion + normal cursor advance | `complete_programme_session_and_advance` | Complete |
| Prepared executable plan | Prepare + adaptation/reversion services | Prepare / accept / revert / clear |
| Generative planning | Coach Brain / Plan Library / Adaptive Progression | **Forbidden** on scheduling path |

---

## Scheduling occurrence identity

A scheduled programme occurrence is identified by **authored programme
provenance**, never by display label, date, or list index alone.

### Required identity components

- `assignmentId`
- `programmeVersionId`
- `packageContentHash` (materialised)
- `sessionSlotId` (authored slot id)
- `weekNumber`, `dayKey`, `sessionOrder`
- `protocolId` (planned protocol for that slot)
- Programme-shaped `ProgrammedSessionKey.value` (derived; must remain stable
  across date changes)

### Explicitly insufficient as sole identity

- scheduled calendar date  
- UI row position  
- session title / display name  
- mutable array index  

### Relationship to `SessionOccurrence`

ADR-017’s `SessionOccurrence` remains the in-session workout identity bridge.
Sprint 1.7 must **project** durable scheduled occurrences into occurrence
records when preparing/executing, but durable schedule authority is the new
schedule projection keyed by authored slot identity above — not ephemeral
occurrence ids alone.

---

## Current-state model after materialisation (baseline)

Until a schedule projection exists:

- Due session = assignment cursor slot.
- `started_at` + timezone define the materialisation anchor only.
- No per-slot calendar schedule is persisted.
- Today prepare uses cursor provenance only.

Sprint 1.7 introduces an explicit schedule projection for every executable
authored slot in the materialised version:

| Field | Role |
|-------|------|
| authored identity (above) | Immutable |
| `scheduledDate` | Athlete-local date |
| `scheduleStatus` | `scheduled` \| `skipped` \| `completed` (completed mirrored from outcomes) |
| `scheduleRevision` participation | Included in assignment schedule fingerprint |

Initial materialisation of the projection (implementation sprint):

- Assign default dates by walking authored order from `started_at` in the
  assignment timezone, placing one executable slot per day unless package
  permissions later allow denser packing.
- Rest/non-executable days remain unscheduled placeholders (no executable
  occurrence).
- Completed slot outcomes already present mark corresponding schedule rows
  completed and immutable.

---

## State-transition model

```text
Athlete opens scheduling action
  → Preview (compute-only; fingerprint F)
  → Explicit confirm
  → Reload authoritative schedule + assignment + outcomes
  → Validate F still matches and eligibility still holds
  → Atomically persist exact reviewed transition + bump scheduleRevision
  → Update local cache after durable success
  → Invalidate or rebind prepared state per interaction rules
  → Restore after relaunch from durable projection
```

Failure at any validation/persist step leaves the previous schedule
authoritative.

---

## Exact operation semantics

### Preview

- **Compute-only.** No durable write, no cursor change, no prepare mutation, no
  completion evidence, no adaptation mutation.
- Returns:
  - affected authored identities;
  - before/after scheduled dates;
  - collisions created or resolved;
  - cursor/Today impact;
  - prepared-session impact warnings;
  - `previewId` + `scheduleFingerprint` + `previewedAt`.
- Confirmation must apply **exactly** the reviewed preview or fail closed on
  freshness mismatch (`stale_preview`).

### Move

**Definition:** Change the `scheduledDate` of **exactly one** uncompleted
scheduled occurrence to a target athlete-local date, preserving authored
identity and authored relative order.

| Rule | Decision |
|------|----------|
| Eligible source | Uncompleted; not skipped-terminal unless restored by undo; same assignment/version/hash |
| Completed source | **Forbidden** |
| Target date | Any athlete-local date ≥ assignment `started_at`; may be past relative to device “today” only if still uncompleted and founder policy allows catch-up (default: allowed for overdue catch-up) |
| Later sessions | **Do not move** |
| Authored order | **Unchanged** |
| Cursor | Unchanged unless the moved occurrence was the current due occurrence and its new date changes due selection (see Cursor/Today) |
| Prepared | If source is currently prepared → clear local prepare for that key after successful move (see Prepared interaction) |
| Collisions | Allowed: multiple uncompleted occurrences may share a date; Today orders by authored order |
| Cross-week dates | Allowed; authored week identity unchanged |

Move is **date placement**, not reorder. Reorder requires a future
order-permissioned operation (not Move).

### Swap

**Definition:** Exchange the `scheduledDate` values of **exactly two**
uncompleted scheduled occurrences in the same assignment/version/hash.

| Rule | Decision |
|------|----------|
| Same assignment/version/hash | **Required** |
| Authored identities | Preserved for both |
| Authored order | Unchanged |
| Either prepared | Allowed; both prepared keys cleared after success |
| Completed either side | **Forbidden** |
| Order-sensitive training constraints | Package may later forbid specific swaps via permissions; default Phase 1: allow date swap with preview warning only |
| Cursor | Unchanged except via due-date recalculation |
| Rest-day placement | Dates may land on former rest calendar days; rest days are not authored slots |

### Push

**Definition (binding):** From a selected uncompleted occurrence **S**, apply a
positive integer day delta **N** to the scheduled dates of **S and every later
uncompleted occurrence in authored order**. Completed and skipped-terminal
occurrences are not shifted. Relative authored order and relative day gaps
between shifted occurrences are preserved by adding **N** calendar days to each
affected `scheduledDate`.

| Rule | Decision |
|------|----------|
| “Push one later” alone | **Not Push** — that is Move by +N days |
| Week-only push | Out of Phase 1 core; may be a later scoped variant |
| Entire remaining assignment | Covered when S is the earliest remaining uncompleted occurrence |
| Off-days / rest | Calendar rest days are not authored occurrences; push shifts dates only |
| Programme end | If package declares an end/horizon, push that would exceed it fails closed unless athlete confirms an explicit “extend horizon” preview flag (default: fail closed) |
| Collisions | May create multi-session days; preview must list them |
| Prepared | Any prepared key among shifted set is cleared after success |
| Cursor | Unchanged except via due recalculation |

### Skip

**Definition:** Mark exactly one uncompleted authored occurrence as
**skipped** — a scheduling/adherence disposition — without fabricating
performed work.

| Question | Binding answer |
|----------|----------------|
| Is skip completion? | **No** |
| Fabricate actuals / previous performance? | **Never** |
| Create `training_sessions` completion row? | **No** |
| Durable evidence | `programme_slot_outcomes.outcome_status = skipped` (+ scheduling audit/operation record) |
| Preserve authored occurrence? | **Yes** — identity remains; disposition = skipped |
| Advance programme cursor? | **Yes**, via a **dedicated scheduling cursor transition** to the next uncompleted authored occurrence in authored order — **not** via `complete_programme_session_and_advance` |
| Clear prepared execution for skipped key? | **Yes**, after success |
| Undoable? | **Yes**, until undo eligibility expires (see Undo) |
| Later restore/reschedule? | Only through Undo (Phase 1); free reschedule-after-skip is out of scope |
| Progress metrics | Counted as skipped/adherence, never as completed volume |

Skip of a completed occurrence is forbidden. Skip requires preview showing the
next due occurrence after skip.

Legacy `ProgrammeProgressionService.skipSession` is **not** the Sprint 1.7
authority path and must not be reused without redesign onto the preview + RPC
model.

### Undo

**Definition:** Restore the exact prior durable schedule snapshot produced by
the immediately preceding successful scheduling operation for the assignment.

| Rule | Decision |
|------|----------|
| Scope | One-level undo (last operation only) |
| Undoable ops | Move, Swap, Push, Skip |
| Not undoable | Completion, adaptation accept/revert, materialisation, pause |
| Eligibility | Until: any later scheduling op; completion of any occurrence affected by the undone op; or explicit undo TTL (default 72 athlete-local hours) |
| Across relaunch | **Yes**, if operation record persisted |
| After prepare of an unaffected key | Still undoable if eligibility holds; prepare for cleared keys remains cleared |
| After prepare of an affected key | Undo allowed only if that prepare is cleared or athlete confirms discard of that prepare in preview |
| Freshness | Undo preview fingerprints current `scheduleRevision`; stale fails closed |
| Audit | Prior operation remains in audit history; undo appends a compensating operation |

No general event-sourcing platform is required: a bounded operation log
(last snapshot + history rows) is sufficient.

---

## Preview / confirmation contract

Every mutating scheduling action must follow:

1. Preview  
2. Explicit athlete confirmation (one deliberate confirm control)  
3. Reload authoritative schedule + assignment + outcomes  
4. Verify preview identity/fingerprint + eligibility  
5. Atomically persist the exact reviewed transition  
6. Persist-before-cache local update  
7. Apply prepared-state side effects  
8. Relaunch restore from durable state  

Non-confirmation paths (open sheet, dismiss, cancel, back, navigate away) are
complete no-ops.

---

## Eligibility matrix (summary)

| Condition | Preview | Move | Swap | Push | Skip | Undo |
|-----------|---------|------|------|------|------|------|
| Materialised active assignment | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Completed occurrence targeted | ✗ | ✗ | ✗ | ✗ | ✗ | n/a |
| Skipped-terminal targeted | ✗ | ✗ | ✗ | ✗ | ✗ | restore via undo only |
| Paused assignment | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Version/hash mismatch | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Stale preview fingerprint | apply fails | apply fails | apply fails | apply fails | apply fails | apply fails |
| In-flight lock held | reject | reject | reject | reject | reject | reject |

---

## Prepared-session and adaptation interaction

| Prepared state of target | Scheduling behaviour |
|--------------------------|----------------------|
| Not prepared | Schedule mutates; no prepare side effect |
| Prepared, unadapted | After successful op affecting that key: **clear** local prepared record for that key |
| Prepared + accepted adaptation | Same clear after explicit preview warning that adapted prepare will be discarded |
| Pending adaptation proposal | Proposal discarded on confirm; **consumed proposal ids remain consumed** |
| Reverted to original | Treated as prepared unadapted |
| Partial in-session athlete-entered execution | If an active non-terminal execution context exists for that key, scheduling op **fails closed** until athlete exits/finishes that execution (no silent discard of in-flight work) |
| Completed | Forbidden |

Scheduling **must not**:

- silently regenerate prepared execution;
- invoke adaptation pipeline / accept / revert;
- preserve an adapted plan under a new date without clear+reprepare;
- rewrite package provenance on the prepared record.

When the due occurrence later becomes current again, prepare uses the normal
1.4B bank/compiler path for that programmed key.

---

## Completion and previous-performance invariants

- Sprint 1.5A remains sole authority for completion evidence and normal cursor
  advance after performed work.
- Skip is not completion and creates no performed-work evidence.
- Previous performance remains descriptive.
- Completed sessions are immutable: no move/swap/push/skip/undo that rewrites
  their prescription, actuals, or completion linkage.
- Scheduling never fabricates loads, reps, or completed values.

---

## Cursor and Today semantics

### Cursor meaning

- **Programme cursor** continues to mean: the next authored occurrence that
  completion progress treats as current.
- Cursor advances by:
  1. Sprint 1.5A successful completion; or  
  2. Sprint 1.7 skip’s dedicated scheduling cursor transition.
- Move/swap/push do **not** rewrite authored cursor coordinates; they change
  dates and may change which occurrence is **due today**.

### Today meaning

Today (athlete-local date in assignment timezone) shows:

1. All uncompleted, non-skipped occurrences with `scheduledDate = today`,
   ordered by authored order; and/or  
2. If none, the earliest overdue uncompleted occurrence (scheduledDate < today),
   ordered by authored order; and/or  
3. If none, an empty-today state with next upcoming scheduled date.

Prepare/Adapt/Begin attach to the selected due occurrence’s programmed key.

### Overdue

An occurrence is overdue when `scheduledDate < today`, uncompleted, and not
skipped. Overdue items remain eligible for Move/Push/Skip and for Today
catch-up display.

### Invalid chronological order

Athletes may create dates that are not strictly increasing in authored order
(e.g. later authored slot scheduled earlier). Phase 1 **allows** this after
preview warning. Package permissions may later forbid it. Completion still
requires the cursor occurrence; athletes cannot complete out of authored cursor
order through scheduling alone.

### Multiple sessions one date

Allowed. Ordered by authored order for Today and prepare selection defaults.

---

## Collision, timezone, and date rules

| Case | Rule |
|------|------|
| Two+ sessions one date | Allowed; preview lists collision; Today orders by authored order |
| Move onto former rest calendar day | Allowed |
| Swap across authored weeks | Allowed (dates only) |
| Push beyond package horizon | Fail closed by default |
| Before `started_at` | Fail closed |
| Into past | Allowed for uncompleted catch-up; preview flags overdue |
| Completed collisions | Completed rows ignored as movable; dates of completed rows immutable |
| Concurrent edits | Compare-and-swap on `scheduleRevision`; loser fails closed |
| Stale preview | Fail closed |
| Duplicate confirm | Idempotent success if same operation id already applied; else reject |
| Timezone | All dates interpreted in `programme_assignments.timezone` |
| DST | Use athlete-local calendar dates, not absolute timestamps, for schedule placement |
| Offline / multi-device | Durable server projection is source of truth; local cache must reload before mutate |

---

## Persistence and atomicity model (later implementation; not 1.7A)

### Required durable components (proposed)

1. **Schedule projection** rows per authored executable slot  
   (identity + `scheduledDate` + status).  
2. **Schedule revision** on the assignment (monotonic integer / fingerprint).  
3. **Scheduling operation log** (preview id, type, before/after snapshot,
   athlete id, timestamps) sufficient for one-level undo and audit.  
4. **Atomic RPC(s)** performing validate + write projection + outcome/cursor
   side effects under row locks.  
5. **RLS/grants** so athletes mutate only their assignments; coaches/admin per
   existing role model.  
6. **Local cache** of schedule projection for offline display, always
   subordinated to server reload before mutate.

### Atomicity requirements

- Persist-before-cache.  
- Either complete transition succeeds or prior schedule remains authoritative.  
- No partial multi-occurrence push.  
- Skip’s outcome write and cursor transition are one transaction.  
- Idempotency keys required on mutating RPCs.

### Explicitly not authorised in 1.7A

Migrations, RPCs, repositories, UI, Supabase contact, staging writes.

---

## Security, migration, and staging implications

Later authorised implementation sprints must:

- add migrations for projection + operation log + revision;
- add RLS policies and grants;
- add staging verification for preview freshness, skip-without-completion,
  undo, and collision cases;
- preserve Athlete C and existing 1.5A fixtures unless separately authorised;
- never use adaptation or Coach Brain paths for schedule mutation.

---

## Typed outcomes / errors (contract vocabulary)

| Code | Meaning |
|------|---------|
| `preview_ok` | Compute-only preview ready |
| `applied` | Exact preview applied |
| `stale_preview` | Fingerprint/revision mismatch |
| `ineligible` | Target not eligible |
| `completed_immutable` | Completed occurrence targeted |
| `horizon_exceeded` | Push beyond package horizon |
| `execution_in_progress` | Active in-session work blocks mutate |
| `paused_assignment` | Assignment paused |
| `provenance_mismatch` | Version/hash/key mismatch |
| `in_flight` | Concurrent op lock |
| `undo_unavailable` | No eligible undo |
| `noop` | Already applied identical op (idempotent) |

---

## Exclusions (Sprint 1.7A–1.7F unless separately approved)

- Programme reauthoring or athlete-specific version generation  
- Coach Brain / Adaptive Progression / adaptation-pipeline scheduling  
- Post-completion future-slot prescription mutation (ADR-022)  
- Fabricated completion or previous-performance evidence  
- Unsolicited recommendation banners  
- Payments / ownership redesign  
- Full multi-level undo history / general event sourcing  
- Free-form reorder of authored package order (separate permissioned epic)  
- Wearable-driven auto-reschedule  

---

## Adaptation interaction (boundary reaffirmation)

Scheduling and adaptation remain distinct:

| Adaptation | Scheduling |
|------------|------------|
| Changes *what* for current prepared key | Changes *when* (and skip disposition) |
| Requires Adapt → review → Accept | Requires Preview → Confirm |
| Uses SessionAdaptationPipeline via Plan-Package adapter | Must **not** call adaptation pipeline |
| Must not move/swap/push/skip | Must not rewrite prescription |

---

## Sprint decomposition (recommended)

| Sprint | Scope | Verifiable outcome |
|--------|-------|--------------------|
| **1.7A** | Discovery + binding contract + architecture guards | This document; ownership tests; no product behaviour — **complete** |
| **1.7B** | Domain model, identity, preview engine, policy/eligibility validation (compute-only) | Deterministic previews + fingerprints; no durable mutate — **complete** |
| **1.7C** | Durable schedule projection, revision, operation log, atomic RPC skeleton, local restore | Persist/restore schedule; no full athlete UX required |
| **1.7D** | Move + Swap apply paths + UI confirm | Exact preview application; prepared clear rules |
| **1.7E** | Push + Skip (+ scheduling cursor transition) | Push-right + skip-without-completion; Self-Test completion still green |
| **1.7F** | Undo, Today/UI integration, hardening, authorised staging evidence if approved | Undo eligibility; milestone closeout |

Deviation note: Preview is intentionally front-loaded in 1.7B before persistence
(1.7C) so eligibility rules are locked before RPCs exist. Move/Swap precede
Push/Skip because they do not require cursor-transition authority.

### Sprint 1.7B delivery status

Implemented under `lib/domain/programme_scheduling/`:

- stable `ScheduledOccurrenceIdentity` (date not part of identity);
- `ProgrammeScheduleProjection` + authoritative `ProgrammeSchedulingSnapshot`;
- Move/Swap/Push/Skip request types and typed preview outcomes;
- central `ProgrammeSchedulingPolicy` (default-allow; no package permission fields);
- compute-only `ProgrammeSchedulingPreviewEngine` with canonical SHA-256 fingerprint;
- undo TTL / prior-snapshot inputs modelled only (`ProgrammeSchedulingUndoPolicyInputs`);
- architecture guards updated to permit the domain/preview owner while forbidding
  apply/mutate/persist/UI services.

Sprint 1.7B does **not** persist schedules, bump durable `scheduleRevision`,
apply operations, clear prepared state, mutate cursor, create completion, add UI,
or contact Supabase.

---

## Test strategy

Prefer domain/behaviour tests over documentation string searches.

Minimum future coverage themes:

- identity stability across date changes;
- preview compute-only;
- exact preview apply / stale rejection;
- move/swap/push/skip/undo eligibility matrices;
- prepared clear + adaptation proposal discard + consumed replay protection;
- skip creates no completion actuals;
- completion/cursor 1.5A regression;
- architecture dependency: scheduling owners forbid adaptation/Coach
  Brain/Adaptive Progression/Plan Package mutation APIs.

Sprint 1.7A added architecture ownership/dependency guards for the contract file
and forbidden couplings. Sprint 1.7B extends those guards to permit
`lib/domain/programme_scheduling/` and the compute-only preview owner while
continuing to forbid mutation/apply/persist services.

---

## Staging-verification plan (later; not 1.7A)

When separately authorised:

1. Materialised athlete with known cursor and prepared session.  
2. Preview+move collision case.  
3. Skip without completion evidence; cursor advances; prepare cleared.  
4. Push-right near horizon fail-closed.  
5. Undo restore after relaunch.  
6. Confirm 1.5A Self-Test 2 completion still green.  
7. Confirm adaptation accept/revert still scoped to current prepare.

No staging contact is authorised in 1.7A.

---

## Founder decisions (approved and binding for Sprint 1.7)

1. **Scheduling permissions** — Move, Swap, Push and Skip are default-allowed for
   eligible athlete programme assignments. No scheduling-permission field is
   added to the Plan Package schema in this milestone. A central policy boundary
   supports future restrictions without changing operation or preview semantics.
   The Plan Package remains prescription authority, not scheduling-permission
   authority.
2. **Past-date catch-up** — An uncompleted occurrence may be scheduled onto an
   athlete-local date from the assignment’s `started_at` through today,
   inclusive. It may never be moved before `started_at`. Placing an uncompleted
   occurrence in the past makes it overdue; it must not mark complete, fabricate
   actuals, create previous-performance evidence, imply performance on that date,
   or bypass Skip/completion authority.
3. **Push horizon** — Push beyond the programme scheduling horizon fails closed
   by default. Preview returns a typed horizon-exceeded result without mutation.
   Do not silently extend, truncate, or partially apply.
4. **Undo TTL** — Default undo eligibility window is 72 athlete-local hours from
   the successful scheduling operation. Sprint 1.7B models policy inputs only;
   durable undo / operation-log persistence remain later-sprint work.
5. **Paused assignments** — Paused assignments block Preview and mutation for
   Move, Swap, Push and Skip with a typed paused-assignment outcome. Resume does
   not rewrite dates; Today/overdue selection recomputes from the preserved
   projection after resume.

---

## Sprint 1.7A boundary

This document is the binding architecture contract. Sprint 1.7A delivers:

- discovery findings;
- this contract;
- checkpoint / AGENTS / architecture index alignment;
- architecture ownership/dependency tests locking the boundary.

Sprint 1.7A does **not** deliver athlete-facing scheduling behaviour, UI,
migrations, RPCs, repositories, or server persistence.

## Sprint 1.7B boundary

Sprint 1.7B delivers the pure scheduling domain and compute-only preview path
ending at: authoritative snapshot → operation request → policy/eligibility →
proposed projection → impacts/collisions → canonical preview fingerprint →
typed preview result.

Sprint 1.7B does **not** deliver confirmation/apply, durable persistence, cache
replacement, cursor mutation, prepared-state invalidation, athlete-facing UI,
migrations, RPCs, or Supabase contact. Those remain assigned to 1.7C–1.7F.
