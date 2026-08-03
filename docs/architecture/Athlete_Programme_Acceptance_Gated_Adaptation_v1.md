# Athlete Programme Acceptance-Gated Adaptation v1 — Sprint 1.6A

**Status:** Binding for Phase 1 programme-backed adaptation  
**Sprint:** 1.6A (architecture contract only — no product implementation)  
**Depends on:** Sprint 1.4B prepared session, Sprint 1.5A completion/advancement  
**Companions:** [Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md),
[Session_Authority_Model_v1.md](./Session_Authority_Model_v1.md),
[Coaching_Constitution_v1.md](./Coaching_Constitution_v1.md),
[Authored_Plan_Package_v1.md](./Authored_Plan_Package_v1.md),
[Athlete_First_Prepared_Session_v1.md](./Athlete_First_Prepared_Session_v1.md),
[Athlete_Programme_Completion_Advancement_v1.md](./Athlete_Programme_Completion_Advancement_v1.md)

**Related ADRs:** ADR-020 (day-of adaptation compute authority remains distinct from
post-completion), ADR-022 (post-completion remains closed for Phase 1)

---

## Purpose and product journey

Athletes on a materialised Authored Plan Package programme may request
day-of adaptation of the **current prepared executable session** when a lawful
constraint applies (time, equipment, environment, or recovery).

Adaptation is a **proposal**, not a second prescription authority. Cohort
computes a reviewable proposal; only explicit athlete acceptance may replace the
current prepared `SessionExecutionPlan`. The authored programme, programmed
source session, cursor, later sessions, and completed history remain unchanged.

Programme journey (adaptation sits between prepare and execute):

```text
Catalogue enrol (1.3)
  → Start Programme / materialise (1.4A)
  → Prepare current authored session (1.4B)
  → Optional: Adapt Session → review → accept | no-op (1.6B–1.6E)
  → Execute prepared session
  → Atomic complete + authored cursor advance (1.5A)
  → Prepare next authored session (1.4B)
```

Home will eventually expose an athlete-initiated **Adapt Session** action on the
programme Today card. Phase 1 does **not** add unsolicited recommendation
banners.

---

## Authority hierarchy

1. **Authored Plan Package / programme version** — immutable prescription
   authority for structure, order, and programmed content.
2. **Programmed session identity** — `ProgrammedSessionKey` (programme-shaped)
   for the current authored cursor slot; never mutated by adaptation.
3. **Prepared execution** — athlete-facing executable package for the current
   cursor; may hold at most one accepted adaptation for that key.
4. **Accepted adaptation decision** — derived execution decision applied only to
   the current prepared package after explicit accept.
5. **Completed evidence** — athlete-entered actuals; append-only; never rewrites
   (1)–(4) as prescription.

**Engine direction:** reuse the proven underlying `SessionAdaptationPipeline`
(evaluate → plan → apply) through a **Plan-Package-native adapter**. The
programme journey must not depend on the legacy generative Plan Library product
path or Coach Brain generative daily planning as prescription authority.

Legacy Plan Library / occurrence Adapt wiring may remain temporarily for
non-programme paths, but programme-backed adaptation must not import or require
that product path.

---

## Whole-session and individual-exercise adaptation

Adaptation may apply at:

### A. Whole-session level

Lawful session-level changes may shorten, restructure, or substitute the
prepared session **only** where the permitted change preserves authored
training intent (Coaching Recognition Test still passes).

Examples of session-level scope (when policy permits): compress for time,
remove optional accessories across the session, convert to an approved modality
equivalent for the session environment.

### B. Individual-exercise level

Lawful exercise-level changes may replace, remove, or adjust a specific
exercise, including supported changes to:

- exercise selection  
- sets or rounds  
- repetitions  
- load  
- duration  
- distance  
- rest  
- equipment  
- other existing policy-permitted execution parameters  

### Combined proposals

A single proposal may contain:

- zero or one session-level change bundle; and/or  
- one or more exercise-level change items  

Athlete review must clearly identify **every proposed material change**
(session-level and each exercise-level item), plus reason and preserved intent.
Non-material bookkeeping that does not alter executable prescription need not
be listed as a material change.

---

## Proposal representation

Logical proposal shape (contract; concrete Dart types land in later sprints):

| Field | Requirement |
|-------|-------------|
| `programmedSessionKey` | Original programmed identity (required) |
| `reason` | One of: time, equipment, environment, recovery |
| `sessionChanges` | Optional whole-session material changes |
| `exerciseChanges` | Zero or more exercise-level material changes |
| `changeSummary` | Athlete-readable list of every material change |
| `preservedIntent` | Training intent retained after the proposal |
| `originalPreparedPlan` | Reference to current prepared plan before accept |
| `proposedPreparedPlan` | Candidate `SessionExecutionPlan` if accepted |
| `outcome` | `reviewable` or `noSafeAdaptation` |

When `outcome = noSafeAdaptation`, Cohort must return a clear result: the
constraint cannot be satisfied without violating authored intent or policy.
No durable state changes.

---

## Proposal lifecycle

```text
1. Athlete initiates Adapt Session (programme Today)
2. Athlete selects reason (time | equipment | environment | recovery)
3. Plan-Package-native adapter builds pipeline input from prepared/authored session
4. SessionAdaptationPipeline evaluates / plans / applies into a candidate snapshot
5. Policy gate + intent preservation → reviewable proposal OR no-safe-adaptation
6. Athlete reviews material changes (or sees no-safe-adaptation)
7a. Accept → mutate current prepared package only
7b. Reject / Keep Original / cancel / dismiss / ignore → complete no-op
```

Compute steps (3–5) must not mutate durable prepared state. Only step 7a may.

---

## Explicit review and acceptance

Every reviewable proposal must expose:

- original programmed session reference  
- adaptation reason  
- exact material changes (session and/or exercise)  
- preserved training intent  
- option to keep the original prepared session  
- explicit accept and dismiss/keep-original actions  

**Acceptance authority:** nothing changes without explicit athlete acceptance.

Accepting a proposal changes **only** the current prepared executable session.
It must not mutate:

- the authored Plan Package  
- the programmed source session  
- later sessions  
- the programme cursor  
- completed history  
- coach-authored progression  

After acceptance:

- the adjusted prescription is the active prepared session  
- the original programmed prescription remains clearly available as reference  
- previous performance remains descriptive  
- completed actuals remain athlete-entered facts  
- Sprint 1.5A atomic completion and advancement remain unchanged  

---

## No-op outcomes

The following are complete no-ops:

- Reject  
- Keep Original  
- Cancel  
- Dismiss  
- Ignore (navigate away / never confirm)

No-op means:

- no prepared-session mutation  
- no durable rejected-proposal record  
- no cursor change  
- no programme / package change  
- no completion fabrication  

---

## Accepted executable representation

On accept, the prepared package retains:

| Element | Role |
|---------|------|
| Original programmed prescription | Immutable reference (rebuildable from programmed key + exact version) |
| Replaced prepared `SessionExecutionPlan` | Active executable plan after accept |
| Accepted adaptation decision | Reason, material change summary, preserved intent, acceptance timestamp |
| Programmed session identity | Same `ProgrammedSessionKey` / cursor slot provenance |
| Programme provenance | assignment id, programme version id, package content hash, day/slot/protocol as already required by 1.4B |

Acceptance **replaces only** the current prepared `SessionExecutionPlan`. It does
not rewrite programmed source content in the package store of record.

Existing conceptual type `AcceptedAdaptationDecision` remains the decision
envelope. Implementation sprints must ensure the live programme accept path
writes that decision onto the prepared package (today’s legacy occurrence attach
path is not sufficient for programme-backed restore).

---

## Local persistence and restoration

**Phase 1 persistence direction:** an accepted adaptation is stored with the
local prepared session (`PreparedExecutionPackage` / `GeneratedSessionRecord`)
and must survive closing and reopening the app.

- Do **not** introduce a new server table in Sprint 1.6A–1.6E unless a later
  authorised sprint changes this direction.
- Restore must validate existing 1.4B provenance (athlete, assignment, version,
  hash, programmed key, day/slot) **and** restore any accepted adaptation for
  that same key.
- If provenance fails, reconstruct programmed prepare for the current cursor;
  do not invent a different adaptation.

---

## Pre-completion reversion

Before completion, the athlete may revert to the original programmed prepared
session:

1. Clear the accepted adaptation decision from the prepared package  
2. Reconstruct the prepared `SessionExecutionPlan` from the programmed key via
   the existing bank/compiler prepare path  
3. Persist the restored programmed prepare locally  

Reversion must not advance the cursor, rewrite the package, or create
completion evidence.

---

## Completion interaction

Sprint 1.5A remains the sole completion and cursor-advancement authority:

- Athlete submits actuals against the **active prepared** plan (adapted or not)  
- RPC commits one completion + one authored cursor advance  
- Adaptation must not complete, advance, skip, or prepare the next session  
- After successful completion, local prepared-record lifecycle follows 1.5A
  rules; the next cursor uses a distinct programme-shaped key and a fresh
  prepare (no carry-forward of the prior accepted adaptation)

Post-completion adaptation remains **closed for Phase 1**. Adaptation must not
rewrite later sessions or become a second programme-advancement authority
(ADR-022 reaffirmed).

---

## Audit and provenance requirements

For an accepted adaptation, durable local evidence must include at least:

- programmed session identity  
- reason  
- material change summary (every material session/exercise change)  
- preserved intent  
- acceptance timestamp  
- sufficient provenance to restore and revert (assignment/version/hash/key)

Non-acceptance creates no durable rejected-proposal audit record in Phase 1.

---

## Permitted and prohibited mutations

### Permitted (when policy allows and intent is preserved)

- Whole-session shorten / restructure / approved substitution of the **current
  prepared** session  
- Individual-exercise replace / remove / adjust of policy-permitted parameters  
- Local persistence of the accepted decision on the current prepared package  
- Pre-completion revert to programmed prepare  

### Prohibited

- Mutate authored Plan Package or programmed source session  
- Rewrite later sessions, periodisation, assessments, or force a deload week  
- Move week/day/slot or otherwise change programme position via adaptation  
- Invent unrelated training  
- Auto-apply without explicit accept  
- Fabricate completion evidence  
- Implement rescheduling (when/order) through the adaptation acceptance path  
- Depend on generative Plan Library / Coach Brain product path for programme
  adaptation authority  

Unsupported or unsafe proposals are rejected by policy (`AdaptationPolicyGate`
and intent preservation). See no-safe-adaptation below.

---

## Policy failure / no-safe-adaptation

Initial athlete reasons: **time**, **equipment**, **environment**, **recovery**
— but only when policy permits a lawful adjustment.

If the constraint cannot be satisfied without violating authored intent or
policy, Cohort returns a clear **no-safe-adaptation** result:

- prepared state unchanged  
- no accept path that mutates state  
- athlete may keep the original prepared session  

---

## Rescheduling boundary

Adaptation and rescheduling are distinct authorities:

| Concern | Changes | Path |
|---------|---------|------|
| **Adaptation** | *What* is performed in the current prepared session | Accept path in 1.6B–1.6E |
| **Rescheduling** | *When*, and potentially in what *order*, authored sessions are performed | Proposed Sprint 1.7 |

**None** of the following may be implemented through the adaptation acceptance
path:

- move one session to another day  
- swap session days  
- push one session forward  
- push the remaining schedule forward  
- explicitly skip a session  
- undo a scheduling change  
- preview scheduling consequences  

See [Proposed Sprint 1.7](#proposed-sprint-17--athlete-controlled-scheduling).

---

## Non-goals (Sprint 1.6A–1.6E)

- Product UI/persistence implementation in 1.6A (contract only)  
- New Supabase tables or migrations for day-of accept  
- Unsolicited Home recommendation banners  
- Post-completion future-slot mutation  
- Wearable-driven auto-apply  
- Generative Coach Brain prescription for programme sessions  
- Rescheduling / skip / reorder / date movement  
- Payments, ownership, or shell redesign  

---

## Planned delivery increments (1.6B–1.6E)

| Sprint | Scope | Verifiable outcome |
|--------|-------|--------------------|
| **1.6B** | Plan-Package-native adapter + propose/review against prepared authored session; no durable write on dismiss | Decision / no-safe-adaptation surfaces on programme path; dismiss leaves package unchanged |
| **1.6C** | Explicit accept replaces local prepared `SessionExecutionPlan` + stores accepted decision; restore after relaunch | Accept mutates only current prepared package; app relaunch restores accepted state for same key |
| **1.6D** | Pre-completion revert; completion remains 1.5A-atomic and adaptation-agnostic for cursor | Revert restores programmed prepare; Self-Test 2 completion/advance still green |
| **1.6E** | Hardening: policy/no-safe cases, Coaching Recognition fixtures, authorised staging evidence if approved | Focused + staging checks without opening post-completion or rescheduling |

---

## Proposed Sprint 1.7 — athlete-controlled scheduling

**Status:** Proposed subsequent workstream — **requires final approval during
Sprint 1.7**. Not part of adaptation implementation Sprints 1.6B–1.6E.

Intended coverage:

- move one session to another day  
- swap session days  
- push one session forward  
- push the remaining schedule forward  
- explicitly skip a session  
- undo a scheduling change before affected completion  
- preview consequences before confirmation  

### Initial scheduling principles (proposed; final approval in 1.7)

1. Athlete confirmation is mandatory.  
2. Plan Package permissions govern whether moving, reordering, or skipping is
   allowed.  
3. Date movement and session-order movement are separate permissions.  
4. Authored order remains fixed by default.  
5. Skip is not completion and must never fabricate completed evidence.  
6. Skipping/advancing requires its own lawful cursor transition and audit
   evidence.  
7. Push-right must account for programme end date and collisions.  
8. Completed sessions remain immutable.  
9. Scheduling changes must not change session content.  
10. Scheduling operations must be reversible until affected completion, where
    lawful.

Scheduling must never be smuggled through adaptation acceptance.

---

## Relationship to existing adaptation surfaces

| Surface | Phase 1 programme stance |
|---------|--------------------------|
| `Adaptation_Policy_v1.md` | Still binding general acceptance rules |
| `SessionAdaptationPipeline` | Reused via Plan-Package-native adapter |
| Legacy Home Adapt / Plan Library | Not the programme authority path |
| `AdaptationExecutionCoordinator` post-completion | Remains closed / skip for Phase 1 |
| Sprint 1.5A completion RPC | Unchanged advancement authority |

---

## Sprint 1.6A boundary

This document is the binding architecture contract. Sprint 1.6A delivers
documentation and checkpoint alignment only. No product behaviour, UI,
persistence writes, migrations, or Supabase contact are authorised in 1.6A.
