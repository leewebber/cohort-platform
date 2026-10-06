# Performance Tracking C3 — pure evaluation handoff

**Recorded:** 2026-10-06. **Status:** LOCAL_IMPLEMENTED_VERIFIED_AWAITING_FOUNDER_REVIEW.
[Founder-approved proposal](../architecture/Performance_Tracking_C3_Read_Only_Evaluation_Proposal_v1.md).

Repository `/Users/leewebber/Developer/cohort_platform`; local branch
`codex/c3-tracking-evaluation`. Clean starting HEAD/proposal:
`b1a7ffddc6c2802107ac21a9c06cf545d5d53932`; cached origin/main/base:
`66e94e010cef40d1743694371bb59b0940b3eb72`. Both exact refs, parentage and clean
worktree verified without fetch or hosted contact. Proposal commit is preserved.
Implementation: `c70a02a097c47ff74e57d132acfc6fd0876f8f00`.
This handoff/live-pointer commit follows it; final reported HEAD identifies the
complete **three linear commits** after the exclusive base (proposal,
implementation, documentation), zero merges. No push or main-ref change.

## Delivered boundary

[Pure evaluator](../../lib/application/performance_tracking/profile_tracking_evaluator.dart),
[result/input contracts](../../lib/application/performance_tracking/profile_tracking_evaluation_contracts.dart)
and [synthetic tests](../../test/performance_tracking/profile_tracking_evaluator_test.dart).
No C1 artifact/codec or C2 read/observation contract changed. No SQL, package,
publisher, infrastructure transport, B2 or runtime wiring changed.

- Synchronous in-memory evaluation of exact curated/custom profile references,
  optional selection/binding revisions and explicit C2 query/result envelopes.
  Reuses C1 closure validation for exact digests, ownership/revision lineage and
  explicit upgrades. Unsupported extraction field/unit/method/source definitions,
  automatic latest/best selection and inconsistent declared scopes fail explicitly.
- C2 performs measured-field extraction; C3 preserves its explicit source identity,
  value/unit and evidence. It adds no raw-result parser or query. Every supported
  block/set/running field is covered by synthetic adapter-to-evaluator tests.
- Shared physical observation identity includes athlete, record/block-result/
  source-block, field path and exact set/exercise or running step/repetition.
  Metric/profile/alias/query mode/audit reference do not create another observation.
  Per-metric digests and per-query views remain distinct; aliases retain all links.
  Genuinely different rows, fields and repetitions remain distinct.
- Alias value/context/chronology/audit conflicts fail rather than choosing a winner.
  Across successful outcomes, a row cannot contradict its parents; fields of one
  record must agree on performed chronology and complete audit membership. Failed
  queries attest no parent relationships. Metric-specific ineligibility/withheld
  partial values do not themselves contradict another view of the same actual.
- Closed `same_metric_context_v1` policy has its own immutable reference/digest,
  separate from C1 codecs/method signatures. Explicit pairs require available,
  tracking-eligible, distinct observations for the same exact metric/method, unit,
  field-scope kind/path and present equal comparison family/required context.
  Known mismatches remain explicit beside missing prerequisites. Output is
  comparable/incomparable/comparison_unavailable, with references and reasons;
  no subtraction, numeric ordering, conversion or “better” judgement.
- Missing/partial/skipped/unavailable/ineligible/incomparable evidence and coverage
  remain honest. Corrected results retain current values plus requested audit
  reference, full unordered audit membership and audit-set digest. A record audit
  alone is not a claim the selected field was corrected or is its latest revision.
- Independent tracking eligibility, programme attribution and prescription
  eligibility stay separate. Unproven/failed programme requests never fall back;
  separately supplied valid independent observations remain visible/eligible.
  A binding declaration alone grants no attribution. Legacy scope remains unproven.
- Deeply immutable ephemeral result schema, canonical JSON and SHA-256 preserve
  exact policy/profile/metric/method/input/audit dependencies. Unordered input,
  definition, profile and audit membership ordering is normalized; authored
  profile member order and explicit operand roles remain meaningful. Invalid
  unordered requests are also handled deterministically. No cache/results ledger.

## Verification in this task

| Check | Result |
|---|---|
| Focused tracking group | **204 passed** (`test/performance_tracking/`): unchanged C1/C2 checks plus the then-current 39 C3 regressions, before the additional batch safeguard below |
| Final affected C3 tests | **41 passed** after all consistency fixes; includes the two added parent/audit batch regressions |
| Final changed-file analysis | **Zero diagnostics** across the evaluator, contracts and test file |
| Final safety gate | **6 groups passed, 0 failed** after adding batch checks; the subsequent alias-first validation ordering changed only the failure reason precedence and passed final affected tests/analysis |
| Diff, links and boundary | Changed/range diff check and documentation file links checked; unchanged C1/C2 authority, package, SQL, B2 and production paths inspected |

Commands: `flutter --suppress-analytics test --no-pub test/performance_tracking/`;
`flutter --suppress-analytics test --no-pub test/performance_tracking/profile_tracking_evaluator_test.dart`;
`dart --suppress-analytics analyze` on the three changed Dart files;
`FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`;
`git diff --check`. Tests include existing loopback-only transport fixtures; no
hosted contact. No full Flutter suite/build: the evaluator has no consumer and
no shared source/runtime changes. Prior compiler, publication and disposable
DB/concurrency verification remains attributed to the committed C1/C2 handoffs,
not rerun or claimed as new C3 proof.

Routine corrections before commit: formatting/test lint issues were fixed;
a new cross-field audit-membership regression failed against the initial C3
implementation, then passed with the batch safeguards. Alias-specific conflicts
are checked first, followed by record/parent consistency, so repeated aliases
retain a precise stable conflict reason. No permissive fallback was introduced.

## Remaining limits and stop

C3 consumes trusted C2 outcomes; a public typed constructor and C1 structural
validation cannot prove registry approval, authentication, source existence or
coherence. It validates envelope correspondence but does not independently
rebuild C2 selected-input digests or publication witnesses from raw database rows.
Any production caller must use the authorised C2 bridges, separately wired and
reviewed. Multiple record reads do not establish one cross-record snapshot.

Current History values and complete unordered audit membership are retained,
not reconstructed historical result revisions. Ties/incomplete audit payloads
remain insufficient for replay. Historical and prescription flags are always
false; B2 authority and blocked Cohort benchmark ingestion are unchanged.

Manual-entry/assessment sources, freshness/zone evaluation, equivalence across
metric/test versions, programme windows, latest/best search, arithmetic/formulas,
scores/ranks, real profiles/content, storage, UI and production wiring remain
outside scope. Synthetic scope witnesses test composition with the already
proved C2 boundary; they do not add a new security/publication authority.
Recorded hosted artifact count was zero; no hosted refresh, fabricated backfill
or Bali republication was performed or proposed. Environment files and repository
supabase/.temp are untouched. Stop for founder review: no push or next slice.
