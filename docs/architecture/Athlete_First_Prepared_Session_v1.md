# Athlete First Prepared Session v1 — Sprint 1.4B

**Status:** Binding for Sprint 1.4B first-session integration  
**Depends on:** Sprint 1.4A materialisation (`Athlete_Plan_Materialisation_v1.md`)

---

## Lifecycle (enrolment → materialisation → preparation)

```text
Catalogue enrol (1.3)
  → programme_assignments row (enrolled-only; not executable)
Start Programme (1.4A)
  → same row materialised (exact version + package hash + cursor)
Prepare current session (1.4B)
  → authored slot → ProgrammedSessionKey → SessionExecutionLoader
  → PreparedExecutionPackage → local restore → Home/today
```

Materialisation and preparation remain **separate idempotent boundaries**:

| Boundary | Durable authority | Idempotent success |
| --- | --- | --- |
| Materialisation | `programme_assignments` (RPC) | `already_materialised` |
| Preparation | local `GeneratedSessionRecord` + in-memory cache | restore / reconstruct |

Preparation never writes materialisation columns. Materialisation never creates a prepared package.

---

## Authoritative reconciliation

The app reloads the caller’s active assignment from persistence (`ProgrammeAssignmentStore.getActiveAssignment`). Programme-backed Home/prepare is executable only when:

- `status = active`
- `materialised_at IS NOT NULL`
- exact `programme_version_id` + `materialised_package_content_hash` present

Catalogue enrolled-only rows (`enrolment_source` set and `materialised_at` null) are not prepared and are not executable via Today. Inactive rows are not prepared. Coach/dev assignments without `enrolment_source` remain resolvable on the legacy today path until they use Start Programme. No client-derived cursor or latest-version substitution. No legacy `PlanAssignment` conversion.

`AthletePlanMaterialisationHandoff` remains the Start Programme → prepare handoff shape; Home also reconciles from the persisted assignment after navigation return.

---

## Cursor → ProgrammedSessionKey

`AthleteProgrammeAuthoredSlotResolver` binds the stored cursor to the exact package:

1. Load exact `programme_version_id` (must be published / non-archived)
2. Compare materialised package hash to version package hash (fail closed on mismatch)
3. Load template tree for that version only
4. Resolve `current_week` / `current_day_key` / `current_slot_order` (no calendar fallback, no first-slot fallback)
5. Require non-rest day + non-empty `protocol_id`
6. Build programme-shaped key:

```text
prog:{assignmentId}@{programmeVersionId}:w{week}:{dayKey}:s{slot}:{protocolId}
```

Same materialised assignment + cursor ⇒ same logical key.

---

## Deterministic bank / compiler authority

Preparation uses **only**:

- Authored slot `protocol_id`
- Existing `SessionExecutionLoader` (protocol / session-block bank → `SessionExecutionPlan`)
- Existing `PreparedExecutionPackage`

Excluded:

- Coach Brain generation
- Generative `ProgrammedSessionResolver`
- Autonomous coaching
- A second compiler or session model

Previous performance remains reference-only. Adaptation remains behind existing policy and athlete-acceptance gates (not applied by 1.4B prepare).

---

## Prepared-package provenance

`PreparedExecutionPackage` / `GeneratedSessionRecord` carry:

- `assignmentId` (programme assignment id)
- `programmeVersionId`
- `packageContentHash`
- `dayKey` / `slotOrder` / `protocolId`
- programme-shaped `programmedSessionKey`

Restore accepts a stored package only when athlete, assignment, version, hash, key, day, and slot match the reconciled cursor. Otherwise reconstruct through the same exact-version path, or fail closed when reconstruction is disallowed.

---

## Idempotent prepare / restore

1. Memory cache by key value  
2. Local KV restore when provenance matches  
3. Else compile via `SessionExecutionLoader` and persist  

Repeated Home refreshes, duplicate opens, and response-loss retries reconcile to one logical prepared execution.

---

## Home/today integration

When legacy Plan Library `hasActivePlan` is false and a materialised programme exists:

- Show `AthleteProgrammeTodaySection`
- Preparing / prepared / retry (no fabricated readiness)
- Open via `launchWithPlan` (preloaded plan; no Coach Brain resolve)

Without a materialised programme, existing Choose Programme entry remains. Plans tab stays Plan Library — Programme Catalogue is not merged into it. No athlete shell redesign.

After Start Programme success, Programme screen requests Home refresh and returns so today’s authored session can appear without app restart.

---

## Failure and retry

Stable failures: missing version, hash mismatch, invalid cursor, unresolvable authored slot, inactive / enrolled-only. Home shows a clear retry state and does not present a substitute session.

---

## Why latest-version substitution is forbidden

The materialised assignment is the athlete’s executable contract. Substituting “latest” would change prescription without an authorised plan event and break Self-Test 1 provenance.

---

## Why Coach Brain is excluded

Authored Plan Package sessions are deterministic bank compilations. Coach Brain remains a separate generative path and must not author Self-Test 1 prescription.

---

## Why completion and cursor advancement are deferred

Self-Test 1 ends at open + restore of the first prepared execution. Completion attribution, cursor advancement, next-session unlock, and adaptation application are later sprints.

Opening, restoring, or reconstructing must not:

- Create a completion
- Advance week/day/slot
- Change `started_at`, `programme_version_id`, or materialisation provenance

---

## Self-Test 1 boundary

Local automated journey (`athlete_programme_first_session_integration_test.dart`):

1. Active materialised exact-version programme  
2. Reconcile from persistence  
3. Resolve week 1 / day_1 / slot 1  
4. Map to programme-shaped `ProgrammedSessionKey`  
5. Produce `PreparedExecutionPackage` via bank/compiler  
6. Home shows the session  
7. Open path uses preloaded plan  
8–10. Discard service memory; restore same logical package  
11. No completion  
12. Cursor unchanged  
13. No Coach Brain / adaptation apply / commerce / latest-version substitution  

Staging-backed Self-Test 1 evidence:
see `docs/architecture/Sprint_1_4B_Staging_Self_Test_1.md`.

---

## Database

Sprint 1.4B adds **no** migration. Preparation reuses local `GeneratedSessionRecord` persistence. Gate K (including `guc_bypass_blocked`) remains the materialisation security gate; no Gate L is required while DB behaviour is unchanged.

---

## Security (preserved from 1.4A)

- Athlete identity from `auth.uid()` for materialisation RPC  
- Cross-athlete isolation / hardened materialisation write guard  
- Exact-version + package-hash enforcement in Flutter prepare path  
- No client service-role use  
- No direct cursor/version/package mutation from prepare/open/restore  
