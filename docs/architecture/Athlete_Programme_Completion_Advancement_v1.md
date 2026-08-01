# Athlete Programme Completion and Advancement v1 — Sprint 1.5A

**Status:** Binding for local Sprint 1.5A  
**Depends on:** Sprint 1.4A materialisation, Sprint 1.4B first prepared session

---

## Lifecycle

1. Materialised assignment + exact version/hash + authored cursor  
2. Sprint 1.4B prepares `PreparedExecutionPackage` for the current cursor  
3. Athlete enters actual values and explicitly submits (**Save and finish**)  
4. Atomic server RPC commits one completion + one authored cursor advance  
5. Client reconciles the persisted assignment  
6. Sprint 1.4B prepares the newly current authored session (separate boundary)

Preparation never completes or advances. Completion never prepares the next
session inside the same transaction.

---

## Why completion and advancement are one atomic boundary

A completion without advancement leaves Home stuck on a finished slot. An
advancement without completion skips prescription history and breaks previous-
performance eligibility. Partial multi-write client sequences are forbidden.

RPC: `public.complete_programme_session_and_advance(payload jsonb)`

---

## Why next-session preparation stays separate

Next-session preparation is idempotent Sprint 1.4B work
(`SessionExecutionLoader` → `PreparedExecutionPackage` → Home/today). Keeping
it outside the completion transaction preserves restore/reconstruction and
avoids coupling bank compilation to write locks.

---

## Logical completion identity

Programme-shaped key:

`prog:{assignmentId}@{programmeVersionId}:w{week}:{dayKey}:s{slot}:{protocolId}`

This distinguishes athlete assignment, exact version, authored week/day/slot
and protocol. Database uniqueness:

- `UNIQUE (assignment_id, session_slot_id)` (existing)
- partial unique `(assignment_id, logical_completion_key)`
- partial unique `(assignment_id, idempotency_key)`

---

## Request idempotency

- Client freezes one idempotency key per explicit submit attempt.
- Same key + same actuals fingerprint → `already_committed` reconcile.
- Same logical key + same fingerprint with a different request key → logical
  replay reconcile (still one completion / one advance).
- Same logical key + different fingerprint → conflict (no overwrite).

---

## Compare-and-swap cursor advancement

RPC locks the assignment `FOR UPDATE`, requires expected cursor equality, then
updates to the derived next cursor (or existing `status='completed'` when
terminal). Concurrent losers receive `stale_cursor`.

Post-materialisation cursor/status fields are protected by the existing
materialisation write guard (GUC + privileged role). Gate K
`guc_bypass_blocked` remains denied/denied.

---

## Authored package traversal

Next cursor derivation (`cohort_programme_version_next_executable_slot` and
`AthleteProgrammeAuthoredCursorTraversal`):

1. Next executable slot in the current authored day  
2. Else first executable slot in the next authored day (`day_order`)  
3. Else first executable slot in the next authored week  

No calendar inference, day-key sort, latest-version fallback, skip, or
performance-derived progression.

---

## Response-loss reconciliation

If the transport fails after an uncertain submit:

1. Do not mint a new logical payload  
2. Reconcile assignment/completion authority  
3. Treat moved cursor / completed assignment as success  
4. Otherwise retry the frozen payload / idempotency key  

Never show completion success from optimistic local state alone.

---

## Local prepared-record lifecycle

- Local `GeneratedSessionRecord` remains until server success is confirmed.
- After success, best-effort local clear; cleanup failure must not roll back
  server authority.
- Stale local records fail provenance against the new cursor.
- The next session uses a distinct programme-shaped key.

---

## Athlete-entered actual-value authority

Completion retains athlete-entered actuals only. Prescribed values are not
rewritten as actuals. Previous performance may later read those actuals as
reference-only and must not alter the next authored prescription.

---

## Failure / conflict outcomes

Typed codes include: authentication required, cross-athlete, assignment
missing/inactive/not materialised, exact version missing, package hash
mismatch, invalid cursor, protocol/key mismatch, completion validation
failure, stale cursor, idempotency/logical payload conflict.

Terminal cursor uses the existing assignment `completed` contract. No new
terminal lifecycle was invented for this sprint.

---

## Forbidden

Autonomous progression, adaptation apply without acceptance, Coach Brain
generation, payments/subscriptions/ownership, wearables/location, shell
redesign, client-nominated athlete id / next cursor, service-role in Flutter.

---

## Self-Test 2 boundary

Local automated journey proves prepare → explicit submit → one completion →
one advance → reconcile/replay → next key differs.

Cohort Staging Self-Test 2 uses a dedicated multi-slot fixture (Athlete C /
`PROG-S15A-STAGING`, three authored executable slots). It must not mutate the
retained Self-Test 1 one-slot Athlete A package. Guarded tooling:

- `tool/staging/create_s15a_self_test_2_fixture.sh`
- `tool/staging/run_s15a_flutter_staging_verify.sh`
- `lib/main_s15a_staging_verify.dart` (anon-only; secrets stub restored after)

Gate L covers hosted-security-equivalent disposable DB assertions for the RPC.
Local Gate K remains the authoritative GUC-bypass denial evidence when a hosted
privileged SQL session cannot safely demote to authenticated.
