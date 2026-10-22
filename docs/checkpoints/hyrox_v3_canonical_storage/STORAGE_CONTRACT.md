# Local authenticated declared-evidence storage contract

2026-10-22. Two additive migrations; no hosted apply or athlete data.

## Declared evidence and deliberate selection

[Evidence migration](../../../supabase/migrations/20261022120000_hyrox_base_declared_evidence.sql)
reuses B2's owner/RLS, immutable revision, explicit command, idempotency and strict-payload
patterns without changing its separate 5 km tables, eligibility or calculation policy.
The five approved metrics retain exact test meaning from
[Base decisions](../hyrox_base_personalisation/DECISIONS.md): 10 km run completion,
2 km row completion, back squat/strict press 5RM **total external load**, strict pull-up
maximum (zero valid). Every declaration retains its date, raw decimal/unit, canonical
integer value, declared source type/reference, server owner, revision/predecessor,
correction reason, command, complete request, server digest and transaction chronology.
`knownResult`/`recordedResult` are declarations, not authenticated test attestation;
`syntheticExample` is refused. There is no freshness cutoff or inferred latest/best result.

`record_hyrox_base_benchmark(payload)` derives the actor from the established authenticated
Supabase session and athlete profile, validates closed keys/types, exact civil date and
metric/unit conversion, then serialises each actor/metric stream with a transaction advisory
lock. Same-owner exact command retry returns its original revision; mismatched/foreign
commands refuse without values. Source identity is actor + metric + exact source reference.
Corrections require its current predecessor and a reason. An unknown/foreign predecessor
cannot nominate an identity. New declarations never automatically select or replace evidence.

`select_hyrox_base_benchmark(payload)` requires the literal explicit preview-use consent,
exact owner/metric/revision and expected prior selection ID. Append-only selections retain
server generation and acceptance time. A null revision explicitly withdraws selection.
Only one concurrent operation against a head can win. A corrected/superseded revision
cannot be newly selected. Old selections are immutable; correction makes their numerical
use unavailable until a deliberate new selection. New independent evidence does not
change an existing selection. An exact historical retry returns that original acknowledgement;
callers must read the current head rather than treating a retry as a fresh acceptance.

`read_hyrox_base_selections()` reads at most one head per approved metric, returning exact
retained evidence and `selected_declared_result`, `unavailable_stale_selection` or
`unavailable_withdrawn`. No head means no selected metric. These states **do not grant
programme prescription eligibility**. The persisted scope is precisely
`declared_benchmark_future_preview_only_v1`, not a programme/assignment/binding/rule/target
or equipment consent. The application [RPC repository](../../../lib/application/hyrox_base/benchmark_repository.dart)
uses the existing session, sends raw values rather than calculated targets/hashes, exposes
explicit read/selection/withdrawal, and remains unwired from production screens/launchers.

## Trusted computation and security

Private `cohort_base_canonical_value` repeats Dart's decimal grammar, exact ms/microgram/
count conversion, pound factor, precision refusal and technical limits. Private
`cohort_base_calculate_v1` implements only the approved eight-week run, **dedicated** row
and squat arithmetic, integer rule version 1, exact rational pace bounds and SQL NUMERIC
intermediates with configured gram increments/nearest ties down. Missing/invalid inputs,
unknown rules/weeks and WOD-row kinds are unavailable. There is no unrelated exercise-load
inference. It is not an authenticated calculator API or source/metric/unit admission layer;
future canonical callers must resolve those prerequisites before using it.

All new tables have owner-only authenticated SELECT RLS. No PUBLIC/anon/service read or
any client DML/column mutation/TRUNCATE privilege is granted. Only the three public RPCs
execute as authenticated; private helpers are revoked from PUBLIC/anon/authenticated/service.
RPC actor validation also refuses a service role carrying an athlete sub even if an RPC
were accidentally over-granted. Definer functions pin `pg_catalog, pg_temp` and qualify
application/extension references. Immutable UPDATE/DELETE triggers protect retained rows,
including under a privileged local test actor; composite ownership/metric predecessor and
selection FKs use RESTRICT. Administrative superuser DDL/trigger disabling is outside RPC
actor authority, as with existing stores. Migration owner remains a trusted deployment actor.

## Canonical refusal, preserving existing authority

[Guard migration](../../../supabase/migrations/20261022121000_v3_unresolved_authority_guard.sql)
refuses new/changed schema markers >=3 at `programme_versions`, after the existing v2
insert marker. Both existing canonical start entry points resolve the **assignment's actual
version**, not a client version/digest, and return
`unavailable / v3_authoritative_admission_unavailable` before any session/outcome write for
owned unresolved v3 pins. Foreign requests retain existing authorization refusal. The prior
bodies are copied privately, with original entry-point OIDs retained so cached callers
also execute the guard; their execution is revoked, and the existing start functions remain the
only operational entry points. Established public generic-start service execution is retained
only where already effectively granted; private bodies are revoked and no existing public
fixed-start permissions are changed. Unexpected PUBLIC/anon generic-start authority rejects
the migration for separate review. There is no client-set GUC switch enabling v3.

All old v1/v2 bodies, canonical bytes/hashes/goldens and B2/C1/C2/C3 contracts are unchanged.
The original application/shared-compiler/server v3 import guards remain in force. This is
strict refusal pending authoritative admission, **not implementation of accepting v3**.
