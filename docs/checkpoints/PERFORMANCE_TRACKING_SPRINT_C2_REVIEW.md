# Performance Tracking C2 — independent reader review

**Recorded:** 2026-10-05. **Verdict:** independent subset locally verified after
one scoped bridge fix; programme attribution remains unimplemented and blocked.
Stop for founder review/integration approval. No expansion of read authority.

**Reviewed clean HEAD:** `694b58155da66983c7ef5ef0b668ff25c7d5e3d1`.
**Cached origin/main base:** `72c1281f0966f2a6485873f6071b0e000ba1e000`.
Branch: `codex/performance-tracking-c2-history-adapter`. No fetch or hosted contact.
The three existing C2 commits and seven integrated C1 commits are preserved.
The commit containing this review adds one fourth linear C2 commit; the final
Git report supplies its full SHA and clean-worktree state.

Binding: [approved architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[read proposal](../architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md),
[reader handoff](./PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md)
and [preserved adapter handoff](./PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md).

## Confirmed defect and fix

A valid programme claim plus the non-leaking `no_visible_record` envelope was
returned by the bridge as an ordinary empty frame. The adapter then reported
independent missing evidence, dropping the claim's attribution requirement.
The new regression failed against the reviewed implementation before the fix.
The bridge now raises `programme_scope_unproven` for that case. The regression
also exercises the adapter and verifies explicit failure, no prescription
eligibility and no historical reconstruction. Ordinary independent absence
retains its existing missing semantics. SQL and response privacy are unchanged.

All other claim paths remain fail-closed: invalid input, absent retained links,
contradictory retained links and unavailable full authority are distinct failures.
Even an invented success envelope cannot admit a programme claim. No verified
witness, canonical artifact or authored-assessment claim is admitted by C2.

## Verified independent boundary

The RPC remains one STABLE SECURITY INVOKER SQL statement with fixed search path,
schema-qualified relations and identity from `auth.uid()`. An explicit owned
record predicate isolates athlete reads even when ordinary History coach RLS
allows broader reads. Foreign and absent records have identical envelopes.
Complete raw result trees and owner-readable correction membership use the same
statement snapshot; ID ordering never implies chronology. The producer never
silently truncates: aggregate child/audit row, response-byte and claim-byte
bounds return failure. These bound admitted evidence, not all database work or
transport allocation; this is not an adversarial query-cost/time guarantee.

Closed envelope decoding, identity/parent checks, counts, actor changes,
malformed fields and audit scopes remain strict. The adapter separately verifies
supported units/fields/evidence and correction consistency. Incomplete historical
inputs and tied correction timestamps cannot establish a prior revision or
latest field correction. Digests identify current inputs/provenance, not a
reconstructed ledger. Tracking always grants no prescription eligibility;
B2 policy, frozen targets and blocked Cohort ingestion are untouched.

EXECUTE remains authenticated-only for client roles; PUBLIC, anon and service_role
are revoked. Normal function-owner privileges persist. No table grants/RLS,
mutation path, package/compiler/hash, programme or assignment changed.

## Training-session permission: both paths proven

[Authenticated SQL proof](../../supabase/tests/sql/gate_c2_coherent_history_read.sql)
actually attempts direct `training_sessions` SELECT, catching only PostgreSQL
`insufficient_privilege`. It does not merely inspect ACL metadata or grant access:

- Athlete A: SELECT denied; independent RPC on A's owned History record **with
  a retained training_session_id** succeeds and preserves that ID. The same
  record with a matching well-formed programme claim returns
  `programme_authority_unavailable`, never independent evidence.
- Athlete B: SELECT denied; B's own independent History succeeds, and A's record
  is inaccessible. Foreign/absent envelopes with claims remain identical.
- Coach: existing ordinary History access remains broader, but this RPC rejects
  the athlete's record. Unauthenticated reads and execution grants are checked.

Missing parent SELECT does **not** block the implemented independent RPC: it
reads History/result/audit tables only; the FK ID is retained without selecting
its parent. Their current RLS/helper chain does not depend on training_sessions.
The ordinary legacy History hydration likewise has no session-table read, but
still lacks coherent audit/tree guarantees and is not certified for tracking.
The permission gap blocks the proposed actual-session owner/protocol witness;
that join has not been attempted or smuggled into the independent function.

The disposable baseline deliberately omits historical hosted blanket grants;
training_sessions RLS is disabled there. This proves the local paths only, not
today's hosted ACL. No claim of hosted permissions, deployment or readiness.

## Programme witness follow-up — proposal only

Existing read authorities were inspected before recommending a new boundary:

- [Calendar inspection/resolver](../../supabase/migrations/20260924120000_completed_fixed_programme_calendar_inspection.sql)
  checks owned assignment, but its active path ensures/reconciles projections
  and can write. It is not a pure tracking read or actual-session ownership proof.
- [Occurrence JSON helper](../../supabase/migrations/20260926190000_fixed_occurrence_time_of_day.sql)
  is STABLE and projects links, but has no standalone caller ownership gate.
  Do not expose it as authentication authority or infer missing links.
- [Assigned graph read policies](../../supabase/migrations/20260926150000_assigned_programme_graph_read.sql)
  can supply pinned version graph reads, including historical assignments.
  They do not grant actual training-session access or complete canonical bytes.
- [B3 completion authority](../../supabase/migrations/20260929120000_b3_structured_running_targets_and_actuals.sql)
  provides exact mapping/block/repetition validation patterns. Its trusted
  internal execution remains revoked from clients; do not expose it or convert
  target snapshots into tracking results/prescription eligibility.
- [Content graph read authority](../../supabase/migrations/20260918120300_content_graph_rls.sql)
  exposes relationship-manifest payloads, not complete Plan Package bytes.
- [Package graph checker/import](../../supabase/migrations/20260731120000_authored_plan_package_import.sql)
  and [v2 publication attestation](../../supabase/migrations/20260927120000_plan_package_v2_authored_running.sql)
  provide graph-validation and exact-byte hashing patterns. These are not public
  tracking read endpoints. Original phase/session keys and full canonical text
  are not retained; rebuilding a package from rows cannot prove its original hash.

**Recommendation:** separately authorise one narrowly owner-gated STABLE combined
History/programme-witness read RPC, using a reviewed SECURITY DEFINER boundary
for the inaccessible joins, with no broad direct table SELECT grant. Keep the
independent invoker v1 unchanged. This would introduce a new bounded read
authority over existing records, not reuse an already complete witness or grant
prescription authority. No definer fallback has been implemented in this review.

The follow-up contract must:

1. Accept exact record/closed programme claim and original canonical package
   text from an existing pinned publication artifact; never caller athlete/role
   or an authoritative client hash. Derive identity from auth.uid() and gate the
   owned History record before returning any joined data.
2. Prove record athlete/assignment/session/source block; owned assignment and
   pinned version/materialised hash; immutable published version/hash;
   exact occurrence assignment/version/hash/slot/protocol; linked outcome
   occurrence/session; **actual training_sessions owner/protocol**; exact slot's
   version path, protocol revision and authored session block. Running scope
   additionally requires canonical mapping/workout/step/repetition identities.
   Missing historical links are unproven; contradictions fail. No latest/date/
   label matching, schedule reconciliation, completion or assessment insertion.
3. Independently SHA-256 the supplied exact UTF-8 bytes against the **server-read
   immutable publication hash**. Parse/validate package schema and exact graph
   against retained authored authority using the internal validation patterns;
   never substitute the client's hash or the content-graph digest. The bridge
   independently recompiles canonical bytes/hash with the
   [existing compiler](../../packages/cohort_plan_package/lib/src/plan_package_compiler.dart)
   and checks exact authored scope. Package v1's session block authority must
   still come from its exact immutable protocol, not fabricated package content.
   Missing original artifact or publication hash means unproven attribution;
   no new package storage or reconstruction is required by this option.
4. Return witness plus complete raw History/audits from **one statement snapshot**,
   not a separate witness request followed by independent v1. All nested read
   helpers must be STABLE/pure with fixed paths and qualified relations; no
   caller-exposed unguarded internal helper. Any callable helper must enforce its
   own ownership gate. Authenticated EXECUTE only, other client roles revoked;
   no table grants/RLS widening or internal-helper client grants.
5. Prove cross-athlete isolation, absent/contradictory historical links,
   package-byte/hash mismatch, exact authored joins, bounded malformed input,
   concurrent corrections and unchanged mutation/permissions/package hashes in
   a disposable local gate before proposing hosted deployment.

**Only material founder decision:** authorise this separately reviewed narrow
read-authority expansion and server-attested artifact-input contract, or leave
programme attribution blocked. Existing public/internal RPCs do not remove that
need. No expansion, SQL implementation or new witness is included here.

## Verification and integration evidence

| Check | Current review result |
|---|---|
| Affected strict bridge tests | **26 passed**, including new no-visible-claim failure and adapter propagation |
| Changed Dart analysis | **No issues found** for reader and bridge test |
| Fresh C2 disposable DB gate | **PASS**: actual authenticated SELECT denial plus independent/claim paths, ownership, >1,000-row completeness, bounds, missing/contradictory links, incomplete audit payloads and tied timestamps |
| Concurrent correction/read proof | **3 two-session races passed**: before/after committed actuals and full audits; no mixture; legacy multi-read negative control differs |
| Existing authority fingerprints | Unchanged relation ACL/RLS, policies and existing function/mutation definitions |
| Mandatory safety gate | **6 groups passed, 0 failed** |
| Diff and changed relative links | Checked before local commit |

Commands: `flutter --suppress-analytics test --no-pub test/performance_tracking/coherent_history_rpc_reader_test.dart`;
`dart --suppress-analytics analyze lib/application/performance_tracking/coherent_history_rpc_reader.dart test/performance_tracking/coherent_history_rpc_reader_test.dart`;
`./supabase/tests/run_c2_coherent_history_read_gate.sh`;
`FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`.
The pre-fix regression failure is recorded as reproduction, not a verification
pass. Unchanged adapter/C1/transport tests are reused from immutable reviewed
HEAD's [113-test handoff](./PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
not claimed rerun. No full Flutter suite or concrete cross-app concern.

Integration preserves:
`3abac2af9e24fdb5601fecf850373aab1bf4ee75`,
`5623a7975c583ef324ecc62d8ec7932bc60ea2fa`,
`694b58155da66983c7ef5ef0b668ff25c7d5e3d1`.
Migration unchanged SHA-256:
`1625ee58a2400946b0ac73ed2933e52ee3ef55fa7b40922cc0f70cd7459544cf`.

Completed subset: unwired independent History adapter/RPC/bridge and local proof.
Unresolved: complete programme/test attribution, immutable artifact delivery,
historical reconstruction, future policy drift/out-of-band corruption detection,
hosted permissions/apply and production wiring. Selection persistence, manual
entry, scoring, calculations, real profiles/tests and next slices remain separate.
No hosted contact, push, permission widening or programme/package changes.
