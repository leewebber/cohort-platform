# Performance Tracking C2 — local read-only adapter handoff

**Recorded:** 2026-10-05

**Status at original closeout:** PURE_ADAPTER_LOCAL_VERIFIED.
**Current continuation:** independent C2 is integrated through `144ba110`; RPC
applied/SELECT-verified on Cohort Field Manual, ledger 115.
[Deployment closeout](./PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md) records
exact scope and preserved hosted/local permission discrepancy. Programme attribution
is blocked and bridge/adapter remain unwired.

**Original authorised continuation:** independent coherent RPC/bridge LOCAL_VERIFIED;
[reader handoff](./PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md) records
proof and stopped programme authority. Original evidence below is preserved.

**Branch:** `codex/performance-tracking-c2-history-adapter`

**Verified clean fetched base:** `72c1281f0966f2a6485873f6071b0e000ba1e000`

**Implementation/proposal commit:** `3abac2af9e24fdb5601fecf850373aab1bf4ee75`

Binding: [revised architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[C1 handoff](./PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md) and
[C1 review](./PERFORMANCE_TRACKING_SPRINT_C1_REVIEW.md).
C1's reviewed seven commits, including both audits and original implementation,
were integrated by founder-authorised strict fast-forward at the base above.
This C2 request superseded the old C2 pause for the bounded local adapter only.

```text
PERFORMANCE_TRACKING_C1=INTEGRATED
PROGRAMME_METRICS_PROFILE_C2_AUTHORISED=true
PERFORMANCE_TRACKING_C2=PURE_ADAPTER_LOCAL_VERIFIED_AWAITING_FOUNDER_REVIEW
PERFORMANCE_TRACKING_C2_COHERENT_READER=PROPOSED_NOT_AUTHORISED
PERFORMANCE_TRACKING_C2_PRODUCTION_WIRED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
COHORT_5K_TEST_INGESTION=BLOCKED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## Findings and delivered boundary

The existing History store hydrates record/block/exercise/set rows through
separate requests, then fetches only a correction timestamp. It cannot certify
one coherent current-input/audit snapshot. Existing correction authority updates
actuals and appends audit in one transaction, but older set audit payloads omit
some corrected duration/distance inputs. Timestamps do not establish commit
order or a reconstructable immutable result revision.

The [unwired pure adapter](../../lib/application/performance_tracking/history_tracking_adapter.dart)
and [caller/read-port contract](../../lib/application/performance_tracking/README.md)
implement independent work while the database portion remains stopped:

- Exact supported immutable metric/method references; only extraction, no
  difference evaluation or arbitrary formulas. Raw existing History field shapes
  are checked before permissive parser defaults can hide malformed input.
- Authenticated actor check before/after await, returned record ownership,
  complete parent graph, duplicate denial and exact source-block identity.
- Closed block duration/distance, set reps/load/distance/duration and exact
  structured-running pace mappings. Canonical units/numeric values are explicit;
  no default/implicit conversion, position/ordinal identity or timer/target value.
- Missing/partial/skipped/unavailable/ineligible/incomparable states, selected
  field coverage and withheld partial values unless permitted. A complete scope
  inside a partial session does not become a completed session or authored test.
- Coherent-read port requirement: reject unproven hydration or incomplete tree/
  audit collections. Verify audit owner/record/session/affected row references;
  reject contradictory current inputs where full affected audit inputs exist.
- Current selected-input and audit-set digests, preserved source identities,
  exact requested audit membership and explicit stale-reference failure.
  Running capture window/mapping/package inputs are included when used.
- Optional programme claim must match raw History links and a coherent verified
  authority witness. Contradictory witnesses are rejected even for independent
  queries. The authority join itself is not implemented or inferred from labels.
- Original event precision/time/date preserved, with unknown civil timezone
  kept unknown. Historical reads are refused. Audit membership is unordered;
  no inferred latest correction or fabricated previous values.

Values exist only in an ephemeral read projection. C1 measurement artifacts are
not rewritten/populated with copied History values; no results ledger/cache or
production consumer is added. Tracking availability/eligibility never grants
prescription eligibility. Existing B2 sources/policy/revisions, target snapshots
and blocked Cohort ingestion remain unchanged.

## Stopped read-boundary portion and concrete proposal

[Coherent History read proposal](../architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md)
specifies a versioned authenticated, read-only single-statement RPC over existing
History/RLS authority, complete raw tree/audit membership, exact optional
programme authority joins and local correction-race/RLS proof. A single embedded
SELECT remains a possible alternative only after proving the same guarantees.
No SQL, function, migration, grant change or Supabase transport implementation
was added. The existing store is not relabelled atomic or wired to this adapter.

The port's snapshot/completeness markers are trusted producer promises, not
client-verifiable certificates. A production producer must be separately
implemented and locally proven before real reads are admitted. Fake-port proof
does not establish database snapshot, RLS or concurrency behaviour.

## Verification at implementation commit

| Check | Result |
|---|---|
| `flutter --suppress-analytics test --no-pub test/performance_tracking/` | **87 passed**: unchanged C1's 52 plus 35 synthetic C2 tests covering ownership/auth switching, parents/scopes, raw shapes/units, correction consistency, incomplete reads, missing states, historical refusal, staleness and deterministic digests |
| Changed-file Dart analysis | **No issues found** for all five new Dart files: three application files and two test/fixture files |
| Phase 2 consolidation safety gate | Final implementation: **6 groups passed, 0 failed** |
| Formatting/diff/links | All added Dart files formatted; staged/range `git diff --check` and changed relative file links checked |
| Boundary inspection | C1 artifacts/code/goldens, package/compiler, B2, runtime, SQL, UI, programme and assignment paths unchanged |

Analysis command: `dart --suppress-analytics analyze lib/application/performance_tracking test/performance_tracking/history_tracking_adapter_test.dart test/performance_tracking/history_tracking_fixtures.dart`.
Safety command: `FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`.
No full Flutter suite was warranted for this unwired projection; no concrete
cross-app concern arose. Prior immutable C1 package/compiler/B2 compatibility
evidence in the C1 handoff is retained, not rerun or claimed as new C2 proof.

Repository root, clean base and fetched HEAD/origin equality were verified before
branch creation. Origin main remains the fetched base locally; there was no push.
No hosted service, DB/migration, phone build, selection storage, manual entry,
ingestion, scoring or programme/package change. `.env` and `supabase/.temp`
were untouched. Source imports are only core Dart, existing crypto and C1.

## Integration range and remaining authority gaps

The implementation/proposal commit above is the first local commit after the
base. A second documentation/live-pointer commit records this handoff; its full
tip SHA, the two-commit range/count and final clean worktree are supplied in the
final Git report. All seven integrated C1 commits remain unchanged ancestors.

Founder review remains necessary before integration or further implementation.
The coherent production read boundary and optional programme join need separate
authority/local proof. Unsupported field families/legacy unit aliases, source
registry publication trust, authored assessment proof, freshness/zone evaluation
and historical input reconstruction are not implemented. No later slice may
interpret an audit-set digest or tracking eligibility as B2 evidence permission.

Profile/custom composition selection persistence, manual measurement entry and
append-only write enforcement, calculations, real profiles/tests, UI, storage,
schema v3, programme content changes and hosted operations remain separately
scoped. Stop here for founder review; do not start them or wire C2 to production.
