# Completion ownership and parent protection — local handoff

**Recorded:** 2026-10-07 (Asia/Makassar).
**Status:** **LOCAL_OWNERSHIP_PROTECTION_PROVED_AWAITING_FOUNDER_REVIEW**.
The formerly failing canonical completion-isolation gate passes. This is a local
candidate; authenticated device validation remains blocked pending separately
approved hosted remediation and independent verification.

## State and scope

Started clean at `ca3837946e526e29a0eb805665ec3e5aa0d29f1f` and created
`codex/completion-ownership-protection`. Preserved the audit
`1b85fe3b1a54b436ee6aa9cb68a09c5cecabf1ff`, table remediation
`ee06faa6a227dd53996342b191908e59d3e818b3`, blocked handoff and every earlier
commit. Integration base and unchanged cached `origin/main`:
`b1d028fb33eb537391f307bb4eac22dddd98ebde`; no fetch.
The [permission handoff](./PERFORMANCE_TRACKING_HISTORY_PERMISSION_REMEDIATION_HANDOFF.md)
contains the confirmed defect and bounded proposal. Its historical failing result
and the [readiness audit](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_READINESS_AUDIT.md)
remain recorded; the new proof supersedes the local completion blocker.

Only completion request ownership, retained physical/programme identities,
parent-trigger protection and disposable proof changed. No production Dart,
existing table grant/policy, programme content, release configuration or athlete
evidence changed. No hosted contact/apply, push, phone build/install or next slice.
Repository `supabase/.temp` retains its pre-task file set and content digest.

## Complete entrypoint and ownership trace

| Callable path | Legitimate authority and protected mutation |
|---|---|
| [Standalone completion](../../supabase/migrations/20260719160000_add_training_session_records.sql), `complete_training_session_record(jsonb)` | Authenticated athlete owns the physical session and record. No programme/outcome parent is admitted through this standalone path. The guarded server wrapper supports terminal parent synchronisation without restoring client session UPDATE. Exact owned retries return the existing record. |
| [Canonical programme completion](../../supabase/migrations/20260801160000_complete_programme_session_and_advance.sql), `complete_programme_session_and_advance(jsonb)` | Caller → owned assignment → immutable version/hash → exact week/day/slot/planned protocol/key → retained outcome → exact physical session → exact existing record, if any. Validation and row locks precede record, outcome, cursor or trigger mutation, including replay. |
| [Fixed-occurrence completion](../../supabase/migrations/20260905180000_swap_future_fixed_programme_session_and_begin.sql), `complete_fixed_programme_occurrence_and_advance(jsonb)` | Same chain plus exact owned occurrence/assignment/slot/version/hash/key/protocol. Guard precedes temporary cursor movement and delegation to the guarded canonical public entrypoint. A failed transaction-body response rolls its intermediate mutations back. |
| [Historical backfill](../../supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql), `complete_backfilled_fixed_programme_occurrence(jsonb)` | Own assignment/occurrence/slot; server creates the physical parent. Root or nested parent nomination is denied. A reused existing record must be that outcome's exact owned parent/record. Existing second-device logical replay may submit a fresh unbound candidate UUID and returns the original server identity; no rebinding or new record occurs. The clock-taking helper is not callable by clients or service_role. |
| [Correction](../../supabase/migrations/20260905121000_correct_interval_performance_record.sql), `correct_completed_performance_record(jsonb)` | Existing own completed record and exact physical parent/retained links. Contradictory nominated identities fail before correction. Original exact child joins, correction audit, running restrictions and rollback remain; no reopening, cursor movement or new correction eligibility. |
| [Terminal parent trigger](../../supabase/migrations/20260914120000_terminalize_training_session_from_completed_record.sql), `cohort_sync_training_session_from_terminal_record()` | Independently checks physical owner, known protocol and retained outcome/assignment/slot/version/hash/key links; UPDATE also requires parent athlete equality. Narrow SECURITY DEFINER execution enables legitimate owned standalone completion without general client parent access. Partial completion retains ended_early. |
| New BEFORE record guard | Rejects owner/parent rebinds and contradictory known assignment/slot/source identities, including INSERT/UPSERT conflicts. Authenticated assignment references must be owned with the exact slot version. Backfill's parent-before-outcome interval requires exact assignment lineage/version, week and protocol on its newly allocated parent. Direct foreign child writes remain denied by unchanged parent-scoped RLS. |
| Internal result tree / retained bodies | Reviewed transaction bodies are renamed privately and lose all PUBLIC/anon/authenticated/service_role EXECUTE. Only guarded public paths call them as postgres owner. Backfill result-tree insertion remains internal. No alternate completion route bypasses the guard. |
| Historical reconciliation | `cohort_reconcile_terminal_training_sessions_from_records()` is unchanged SECURITY INVOKER historical repair. It gains no session UPDATE privilege or elevated execution path. Its deliberately corrupt postgres-only fixture is seeded with both triggers disabled, then both re-enabled before future-path assertions. |

The [completion service](../../lib/features/programme/services/athlete_programme_completion_service.dart)
passes the authored **planned** protocol in the request and the prepared
**effective** protocol in the completion record. The guard checks the former
against the immutable slot and the latter against the physical session; it does
not equate adapted execution with authored prescription. Known physical
programme IDs accept only retained lineage code or exact version UUID. Missing
historical metadata is not reconstructed: an existing exact owned outcome can
supply retained linkage; contradictory known metadata is rejected. No title
matching or athlete-specific exception is used.

Canonical start/resume and fixed-start entrypoints already establish owned
parents/outcomes; they remain unchanged. Benchmark-only completion functions do
not mutate this session lifecycle. Coach History access retains explicit active
relationship authority; it grants no athlete completion/correction authority.

## Migration and exact security boundary

[New migration](../../supabase/migrations/20261007130000_completion_ownership_and_parent_guard.sql):
`20261007130000_completion_ownership_and_parent_guard.sql`.
SHA-256: `d0a6a4b16a60376c3d7d97420b9e5e423efaf12d6d636b16064bfa7143fcbbe5`.

[Preserved table migration](../../supabase/migrations/20261007120000_history_read_permission_remediation.sql):
SHA-256: `7c5ce19e72ddd438acfe9db23a5b3c4abed65bdeb6db8faa82e8e7df70910ff7`.

| Function group | Effective non-owner EXECUTE |
|---|---|
| Canonical, fixed and standalone public completion | authenticated, service_role; claims-derived athlete ownership still mandatory |
| Public backfill and correction | authenticated only |
| Five renamed transaction bodies; request/parent/record-trigger helpers; parent sync trigger; clock-taking backfill helper | none for PUBLIC, anon, authenticated or service_role |

PUBLIC/anon cannot execute any affected public completion/correction path. No
client grant options or additional principals remain on those paths. New guards,
wrappers and triggers are postgres-owned SECURITY DEFINER with fixed
`pg_catalog, public, pg_temp` search path. The unchanged public SQL backfill
wrapper delegates only to its guarded clock helper. Table ACLs/RLS remain exactly
those in the prior handoff: owner-only authenticated session SELECT; record/result
and profile SELECT/INSERT/UPDATE; relationship/correction SELECT; no anonymous,
destructive or sequence privileges. No policies were weakened or widened.

The actor is `auth.uid()` plus existing athlete-role authority. Payload actors,
substituted parents, conflicting existing record identities and contradictory
programme links cannot confer authority inside SECURITY DEFINER execution.
Foreign and absent identities return the same completion envelope:
`authorization_failure / completion_identity_denied`. Correction uses generic
SQLSTATE `42501 / completion_identity_denied`. Static forbidden-authority request
fields retain the original validation response. Denials contain no foreign
identity, state or result details.

Non-success canonical/fixed/backfill transaction-body responses execute inside a
rollback subtransaction, so a returned rejection cannot retain staged cursor,
parent or child changes. Exceptions roll back the whole affected invocation.
Existing active-assignment idempotent/logical retries remain. The pre-existing
inactive-assignment response after final-slot programme completion is unchanged;
this slice does not reopen terminal assignments or redesign lifecycle rules.

## Current-task verification

| Check | Result |
|---|---|
| [Dedicated role/API gate](../../supabase/tests/run_history_permission_remediation_gate.sh) | Overall PASS, including the previously failing [canonical isolation probe](../../supabase/tests/sql/gate_history_permission_completion_owner.sql), own canonical start/resume/restore and partial completion. |
| [Expanded actual-role proof](../../supabase/tests/sql/gate_completion_ownership_security.sql) | Actual authenticated role: foreign/absent/substituted parent, record, assignment, slot, protocol, hash and nested identities denied. Owned fixed/backfill occurrence substitutions denied. Direct foreign parent/child writes denied. Independent AFTER-trigger defence proved even with BEFORE guard disabled only for a synthetic negative transaction. Own standalone completion/retry/correction and active programme retry pass. |
| Rejected-request preservation | Each negative probe compares all-row digests of sessions, records, block/exercise/set results, outcomes, assignments, occurrences and correction audits. Foreign-child correction deliberately follows a tentative own-note mutation and proves rollback. All unchanged; SQL probes roll back. |
| [Loopback API proof](../../supabase/tests/completion_ownership_http.py) | All five anonymous entrypoints denied; foreign/missing completion identities uniformly denied; private bodies unreachable; linked coach has no completion authority. Own standalone completion/retry/correction and exact canonical retry pass. Every rejection/retry checks evidence digest. Only locally minted disposable synthetic identities. |
| Replay / ACLs / retained evidence | Fresh reset plus repeated migration application; exact public/internal function ACL assertions, adverse prior table grants, unknown-policy fail-closed control and replay preservation pass. Every pre-existing public ordinary-table row set stays unchanged; function/ACL semantics are stable on replay. No production row repair. |
| Full disposable DB gate | `bash supabase/tests/run_local_db_gate.sh`: fresh/repeat reset, baseline fidelity, canonical/fixed/backfill/correction/coach compatibility, start/concurrency and PostgREST controls PASS. Gate L now starts its synthetic parent through actual canonical start rather than a bare unlinked INSERT. |
| Structured running | `bash supabase/tests/run_b3_structured_running_targets_and_actuals_gate.sh`: PASS, including partial/skipped work, completion freeze, retry and correction boundaries. |
| Focused Flutter | **317 tests passed**: completion service/self-test/integrity, backfill, structured running controller/actuals, completion migration, distance feature and C2/C3 tracking regressions. No full Flutter suite: no production Dart changed and shared DB paths have direct compatibility evidence. Prior unchanged 508-test UI evidence remains attributed to the earlier handoff. |
| Analysis | Completion service, save coordinator, performance store and unchanged C2 decoder fixture: **zero issues**. No changed production Dart. |
| Safety / source checks | Six safety groups PASS; Bash/Python syntax, documentation links and diff checks PASS. |

Disposable projects, task-created backups, scratch logs and proof files are
removed. Existing Docker resources are preserved. No hosted account was
impersonated, token acquired, denied hosted function bypassed or permission
widened. Prior hosted source counts remain historical: two complete owned km
observations, three absent values and no retained comparison context. No fresh
hosted readiness or device proof is claimed.

## Founder review and approval boundary

Implementation/proof commit: `3652fc6543bfc6f6d5e8786bba19b9332c71b9de`.
Full linear integration range:
`b1d028fb33eb537391f307bb4eac22dddd98ebde..codex/completion-ownership-protection`:
preserved audit, table remediation, blocked handoff, this bounded fix/proof and
updated handoff. Exclusive new range:
`ca3837946e526e29a0eb805665ec3e5aa0d29f1f..codex/completion-ownership-protection`.
Final tip is reported with repository state; no integration or push occurred.

Stop for founder review. Founder approval is required for integration. Hosted
preflight/application/independent postchecks require separate explicit authority
and fresh target/health/grant/policy checks. Authenticated device validation,
phone build/install and release activation remain separately unauthorised.
