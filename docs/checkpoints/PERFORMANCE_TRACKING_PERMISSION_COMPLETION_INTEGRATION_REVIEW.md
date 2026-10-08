# History permissions and completion ownership — integration review

**Recorded:** 2026-10-08 (Asia/Makassar).
**Status:** **REVIEWED_LOCALLY_AWAITING_FOUNDER_INTEGRATION_APPROVAL**.
Two scoped fixes are committed separately. The completion-isolation gate and
expanded role/API/concurrency proof pass. No outstanding confirmed defect remains
within the reviewed boundary. Hosted remediation and authenticated device
validation remain separately gated; this record authorises neither.

Started clean at expected HEAD `680b3ba86eaf5ef4cd46765ae24be7b5a834867a`,
preserving all six existing commits. Review branch:
`codex/history-permission-completion-review`. Base and unchanged **cached**
`origin/main`: `b1d028fb33eb537391f307bb4eac22dddd98ebde`; no fetch.
The [table handoff](./PERFORMANCE_TRACKING_HISTORY_PERMISSION_REMEDIATION_HANDOFF.md)
and [completion handoff](./PERFORMANCE_TRACKING_COMPLETION_OWNERSHIP_PROTECTION_HANDOFF.md)
retain their historical findings and verification. This review supersedes their
local readiness claims where the defects below were previously uncovered.

## Confirmed findings and separate fixes

| Finding | Evidence and resulting protection |
|---|---|
| **P1: elevated backfill child UUID collision** | The original internal tree used `ON CONFLICT DO NOTHING`, then attached descendants to the nominated UUID. An actual authenticated caller's valid own backfill committed and inserted a descendant beneath another athlete's existing block. Pre-fix disposable probe: `committed=t foreign_descendant_inserted=t`; the probe rolled back. Fix `eaef02e61e265d3c458e2a854c599efc68bf0387` validates every block/exercise/set's exact parent before insertion and after a conflict wait, including a block-only tree and a concurrently committed foreign UUID. Foreign and other-record collisions now produce the uniform denial with unchanged evidence. |
| **P2: mutable identity edges** | Existing child policies permitted moving an owned result to another owned in-progress tree. Correction locked the record and selected result, leaving intermediate parent edges mutable. The record trigger also omitted record ID/programme ID updates. The same identity fix makes child primary IDs and immediate parent edges immutable, protects the record ID and contradictory known programme ID, and runs the record guard for those columns. No demonstrated consumer reparents these identities; draft UPSERT retains stable IDs/parents. |
| **P2: checked ownership links were not all retained under locks** | Parent validation read assignment/outcome links without locking them; direct child writes could inspect a physical parent without locking it. Fixed request validation also acquired assignment before occurrence, opposite the established fixed path, and entered the retained advisory fence after row validation. Fix `34eafe33f96f877e4ccc5179189041b6888291ca` retains and revalidates assignment/outcome/parent locks, aligns fixed/backfill fence → occurrence → assignment order, and locks the assignment checked for a parent-free draft. The identity fix supplies explicit privileged parent validation for direct child writes. Actual-role barrier probes prove competing ownership/link changes wait until the checked transaction ends. |

No old migration, permission policy, package, programme content, assignment or
athlete evidence is rewritten. Fixture changes only supply valid synthetic
athlete profiles for correction and temporarily disable the new block guard
while postgres seeds the deliberately corrupt historical reconciliation fixture.
All guards are re-enabled before future-path assertions. Application/security
probes never disable these guards or widen privileges.

## Final callable and trigger boundary

All five public completion/correction names have exactly one `jsonb` overload.
Their wrappers validate claims-derived athlete ownership before invoking private
transaction bodies; SECURITY DEFINER execution does not use client filtering or
RLS as ownership authority. The existing exact assignment → immutable
version/hash/slot/key → occurrence/outcome → physical session → record chain
remains mandatory for programme completion and retries. Foreign, absent and
contradictory nominated identities are denied before mutation.

Standalone completion admits only an owned independent physical parent and
record. Backfill creates its parent server-side, validates exact tree edges and
preserves second-device logical replay without binding a fresh candidate record.
Correction retains exact record/child joins, terminal-only eligibility, the
correction audit and structured-running restrictions. The independent terminal
parent trigger still checks ownership/linkage and updates by both parent ID and
athlete. Partial completion preserves `ended_early`; no cursor, scheduling or
correction eligibility redesign was introduced.

The new `guard_direct_result_write_v1` BEFORE trigger is SECURITY INVOKER. It
inherits the actual privilege context: direct authenticated child writes lock
their owned root and explicitly require the current in-progress state, including
after waiting behind completion. Inside a legitimate elevated completion or
correction it retains that caller's elevated context. It uses no client-settable
flag to authorise terminal writes.

The subsequent `guard_result_identity_v1` BEFORE trigger is SECURITY DEFINER,
with fixed `pg_catalog,public,pg_temp` search path. It independently checks the
claims-derived record owner, immutable identity edges, exact ancestors and
retained parent links. It locks the physical parent without restoring client
session UPDATE. Both trigger functions have no PUBLIC/anon/authenticated/
service_role EXECUTE; trigger invocation creates no callable RPC bypass.

Record-first locks fence concurrent completion/correction and child operations.
Parent validation locks sorted assignment/outcome hints, then the physical
parent, then rechecks the exact outcome membership and all known identities.
Moved/deleted/added hints fail closed. The parent lock also fences new outcome
references through the existing foreign key. Immutable child edges prevent
correction from checking one tree and subsequently mutating a reparented tree.
Fixed/backfill acquire their retained advisory fence before occurrence and
assignment rows. These checks establish transaction-time ownership; they do not
authorise arbitrary later trusted-server reassignments or claim absence of every
possible database deadlock.

Historical absent metadata is not fabricated. Parent-free legacy assignment
hints without retained authority remain independent context; an extant checked
assignment is locked and must have the same owner. Immutable authored programme
structures remain under their existing publication/freeze authority.

| Function group | Effective non-owner EXECUTE |
|---|---|
| Public canonical, fixed and standalone completion | authenticated, service_role; authenticated claims-derived athlete ownership remains required |
| Public backfill and correction | authenticated only |
| Retained transaction bodies, clock helper, request/parent helpers, record/parent/child trigger functions, internal result-tree insertion | none for PUBLIC, anon, authenticated or service_role |

Completion denials remain `authorization_failure / completion_identity_denied`;
correction denial remains generic SQLSTATE `42501 / completion_identity_denied`.
No foreign identity, state or result details are returned. Failed body responses
use rollback subtransactions. Rejected probes compare all-row digests of
sessions, records, block/exercise/set results, outcomes, assignments, occurrences
and correction audits: zero row/evidence residue, including denial after a
tentative own-note change. No sequence counter rollback is claimed.

## Exact grants, RLS and sequence boundary

The [table migration](../../supabase/migrations/20261007120000_history_read_permission_remediation.sql)
is unchanged. PUBLIC/anon have no privileges on the eight audited tables.
Authenticated retains only:

| Relation | Authenticated grants |
|---|---|
| `training_sessions` | SELECT |
| records, blocks, exercises, sets | SELECT, INSERT, UPDATE |
| correction audits, coach/athlete relationships | SELECT |
| profiles | SELECT, INSERT, UPDATE |

No client DELETE/TRUNCATE/REFERENCES/TRIGGER/MAINTAIN, grant options or separate
column grants remain. `training_sessions_id_seq` has no PUBLIC/anon/
authenticated SELECT/USAGE/UPDATE. Postgres/service table privileges are preserved;
no blanket grants, new server grants or default privilege changes were added.

Session RLS is enabled with only `training_sessions_athlete_select`: authenticated
SELECT using `athlete_id=auth.uid()::text AND cohort_auth_is_athlete()`.
FORCE RLS is unchanged; client session mutation and coach session-table reads
have no policy. Unknown additional session policies abort migration replay.
All other existing policies remain exactly as [inventoried in the audit](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_READINESS_AUDIT.md):
own record reads/in-progress updates; owned result-parent reads/in-progress write
checks; explicit active-relationship coach History/profile reads; own correction
reads; relationship endpoint reads; own profile provisioning/editing. Coach
History access confers no C2 owner-read or completion/correction authority.
No policy was weakened. No additional excessive privilege was found in this
bounded scope. Wider schema hardening was not performed.

## Verification of the final candidate

| Check | Observed result |
|---|---|
| [Dedicated role/API/replay gate](../../supabase/tests/run_history_permission_remediation_gate.sh) | PASS, including the formerly failing canonical isolation gate, eight-table ACL/column/sequence checks, anon/cross-athlete denials, explicit coach boundaries, actual C2/C3 decoding and C2 correction/publication races. Replay preserves every existing public ordinary-table row set, final function/ACL semantics, other policies and server table grants. |
| [Child identity proof](../../supabase/tests/sql/gate_completion_child_identity.sql) | PASS: foreign block/exercise/set and own other-record UUID collisions denied with unchanged digests; own partial backfill and second-device retry succeed. One public overload per route, private helper ACLs and all six child triggers asserted. |
| [Concurrency proof](../../supabase/tests/concurrency/gate_completion_identity.py) | PASS: five ownership/link barriers (correction outcome/assignment/physical parent, parent-free draft assignment, direct-child physical parent); fixed advisory-before-row order; immutable identity denials; child write begun before completion waits then rejects the terminal root; concurrent foreign UUID winner is rejected even without descendants. Fixtures cleaned and original evidence digests restored. Uses actual authenticated roles and competing trusted server writers, with observed lock barriers and bounded timeouts. |
| [Existing expanded security/API proofs](../../supabase/tests/sql/gate_completion_ownership_security.sql), [API proof](../../supabase/tests/completion_ownership_http.py) | PASS: every affected entrypoint, standalone/programme completion, partial completion, retries/correction, foreign/missing/substituted identities, independent parent defence, anonymous/private-path denials and unchanged evidence. |
| [Full local DB compatibility](../../supabase/tests/run_local_db_gate.sh) | PASS: final migration fresh/repeat reset, schema lint, baseline fidelity, shared start/resume/fixed/backfill/correction/coach compatibility, concurrency and API controls. Its deliberate negative controls reject their inverted assertions as expected. Historical compatibility sections intentionally replay earlier function definitions; final guarded role/API proof above is the security authority. |
| [Structured running](../../supabase/tests/run_b3_structured_running_targets_and_actuals_gate.sh) | PASS: 11 BM cases plus BL mapping compatibility, partial/skipped evidence, completion freeze, retry and correction boundaries. |
| Focused Flutter | **242 tests pass**: `test/performance/`, backfill persistence and structured-running controller. Unchanged earlier 317/508-test evidence is retained and attributed to the prior handoffs; no full Flutter suite rerun. No production Dart changed. |
| Analysis / safety | Completion service, performance store and C2 decoder fixture: **zero analysis issues**. Changed Python AST/Bash syntax and SQL schema lint pass. **Six safety groups pass**, zero failed. Initial SDK-generated-file restriction was resolved by the required local access; it was not a product failure. |
| Diff / links / preservation | Local links and `git diff --check` pass. Repository `supabase/.temp` retains its exact file set/content hash. Disposable stacks, task-created backups and scratch files removed; unrelated Docker resources preserved. |

The initial child-collision probe failed intentionally to establish the defect.
Early compatibility failures identified only the synthetic profile/corruption
fixture assumptions described above. One intermediate replay-preservation check
was invalidated by changing a migration while its copied candidate was running;
the frozen final candidate passed the complete gate. No failed/intermediate run
is used as readiness evidence.

## Ordered migrations and integration range

| Order | Migration filename | SHA-256 |
|---|---|---|
| 1 | [20261007120000_history_read_permission_remediation.sql](../../supabase/migrations/20261007120000_history_read_permission_remediation.sql) | `7c5ce19e72ddd438acfe9db23a5b3c4abed65bdeb6db8faa82e8e7df70910ff7` |
| 2 | [20261007130000_completion_ownership_and_parent_guard.sql](../../supabase/migrations/20261007130000_completion_ownership_and_parent_guard.sql) | `d0a6a4b16a60376c3d7d97420b9e5e423efaf12d6d636b16064bfa7143fcbbe5` |
| 3 | [20261008120000_completion_result_identity.sql](../../supabase/migrations/20261008120000_completion_result_identity.sql) | `604309505ca646801951d92fb6e305ae070bf1a6c1854338d633fc015f809320` |
| 4 | [20261008121000_completion_link_locking.sql](../../supabase/migrations/20261008121000_completion_link_locking.sql) | `33712db05d2439b7c42729b8e5f57f66a6992ef3cf1ce26a807f5bb15cc4e8cd` |

Exact reviewed implementation range:
`b1d028fb33eb537391f307bb4eac22dddd98ebde..34eafe33f96f877e4ccc5179189041b6888291ca`.
Full integration range including this documentation commit:
`b1d028fb33eb537391f307bb4eac22dddd98ebde..codex/history-permission-completion-review`.
**Nine ordered commits, zero merges**; the branch tip is this handoff/pointer
commit and its full SHA is reported with final repository state.

1. `1b85fe3b1a54b436ee6aa9cb68a09c5cecabf1ff` — readiness audit.
2. `ee06faa6a227dd53996342b191908e59d3e818b3` — table remediation/proof.
3. `ca3837946e526e29a0eb805665ec3e5aa0d29f1f` — blocked handoff.
4. `3652fc6543bfc6f6d5e8786bba19b9332c71b9de` — completion ownership/proof.
5. `122b1cb6d7edb9a67edc1398722f38d6027de8a3` — completion handoff.
6. `680b3ba86eaf5ef4cd46765ae24be7b5a834867a` — API evidence clarification.
7. `eaef02e61e265d3c458e2a854c599efc68bf0387` — result identity/parent protection.
8. `34eafe33f96f877e4ccc5179189041b6888291ca` — retained link locking/concurrency proof.
9. This integration-review handoff and current pointers, at the named branch tip.

## Remaining approval boundary

**Stop for founder integration approval.** The concrete candidate is the entire
nine-commit linear range above, with all four migrations in order. Integration,
fetch/push and hosted operations were not performed.

After separately approved integration, hosted preflight/application and
independent postchecks require fresh target identity/health, ledger, grants,
policies, function/trigger definitions and protected evidence verification.
Device validation requires a separately approved authenticated build/install
boundary after hosted security is proved. Release guards remain unchanged.
No next slice follows from this review. Historical real-source observations and
missing comparison context were not refreshed; no real athlete results or
personal identifiers appear in this report.
