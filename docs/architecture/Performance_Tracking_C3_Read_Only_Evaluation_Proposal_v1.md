# Performance Tracking C3 — read-only evaluation proposal

**Recorded:** 2026-10-06. **Current status:** FOUNDER_APPROVED;
LOCAL_REVIEW_VERIFIED_AWAITING_FOUNDER_INTEGRATION_APPROVAL.
[Implementation handoff](../checkpoints/PERFORMANCE_TRACKING_C3_EVALUATION_HANDOFF.md)
records exact scope/verification; proposal commit `b1a7ffd` is preserved. The
founder's separate implementation authorisation superseded this proposal's pause
for pure extraction/comparability only. No broader tracking/wiring authority.
Verified repository `/Users/leewebber/Developer/cohort_platform`, clean HEAD and
**cached** origin/main `66e94e010cef40d1743694371bb59b0940b3eb72`, without fetch.
Local documentation branch: `codex/c3-tracking-evaluation-proposal`.

Binding: [revised contract architecture](./Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[C1 contracts](../../lib/domain/performance_tracking/README.md),
[C2 adapter](../../lib/application/performance_tracking/README.md),
[adapter handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md),
[independent bridge handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
[programme bridge handoff](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md)
and [deployed authority](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_DEPLOYMENT.md).
Deployment is recorded evidence at this base, not a fresh hosted survey.

## Recommendation and exact boundary

Build one unwired, pure in-memory profile evaluator over caller-supplied C2
current-read outcomes, plus a closed pairwise **comparability** policy. Return
measured values, reasons and provenance. Defer numeric differences and all other
derivations. No new reader, async fetching, automatic baseline search or database
snapshot authority is required. Synthetic definitions/profiles/frames only.

Proposed implementation files are limited to a pure evaluator/result contract
under `lib/application/performance_tracking/`, focused synthetic tests under
`test/performance_tracking/`, and accompanying documentation. Reuse the C1/C2
contracts unchanged. Do not change package/compiler/publication, SQL, B2 or
production registrations.

| Input | Required boundary |
|---|---|
| Athlete and profile | Exact curated/custom profile ID/version/digest; complete supported metric/method and predecessor closure. Optional caller-supplied selection/binding revisions remain exact. Custom owner and selection athlete must match; deselection returns `not_selected` |
| Observation envelope | Exact original C2 query plus its result and independent/programme query mode. Carry the query athlete/metric reference and stable field identities; a naked value, copied result ledger or caller-made witness is insufficient |
| Programme context | Exact declared claim/binding, where requested, and the existing combined reader's validated outcome. Binding declaration alone is not attested programme scope |
| Comparison request | Two explicitly named observation inputs, one exact metric reference, and the closed versioned comparison policy described below. No implicit pair construction |

Validate dependency closure before projecting; reject duplicate/conflicting
artifact identities, wrong digests, athlete mismatch and unannounced upgrades.
Resolve only pinned versions, never registry latest or label/name matches.
C1 structural validation does not establish registry approval or authentication.
For synthetic tests use supplied supported definitions and proven fake C2 reader
flows; any later production caller must use the separately authorised C2 bridge,
not construct trusted outputs by labelling arbitrary maps.

Return profile members in authored order, referencing a shared observation set
rather than copying observations per profile. Each member retains its own
eligibility and source links. Unselected/configuration states, failed reads and
successful missing evidence remain distinct. The evaluator does not populate
C1 measurement artifacts with History values or create a persistent cache.
C1 `latest` view metadata is preserved but not executed: inputs are explicitly
selected; unsupported automatic-selection requests fail, never silently choose.

## Existing method contracts and supported extraction

[Method contracts](../../lib/domain/performance_tracking/tracking_contracts.dart)
define only `fieldExtraction` and `difference`. The
[validator](../../lib/domain/performance_tracking/tracking_validation.dart)
requires one extraction input or two difference inputs, all in the output unit.
A method carries ID/version/digest, kind and unit signature. It has **no** operand
source binding, subtraction direction, rounding, comparison-context policy,
chronological selection or “better” meaning. A difference signature is not an
executable calculation licence. The C2 adapter explicitly refuses it.

C3 supports extraction only through the unchanged C2 mappings:

| Exact selected scope | Supported measured field / unit |
|---|---|
| Block duration/distance/endurance | `result_data.durationSeconds` / seconds |
| Block distance/endurance | `result_data.distance` / explicitly stored metres or kilometres |
| Exact exercise/set | `reps` / count; `load` / kilograms; `distance` / metres or kilometres; `duration_seconds` / seconds |
| Exact running workout/block/step/repetition | `result_data.intervals.paceSecondsPerKm` / seconds per kilometre |

Preserve canonical decimal values and explicit source units. No conversion,
pace/distance derivation, timers, prescriptions, frozen targets, aggregation,
percentages, averages, ranks or scoring. Unsupported field/method/source requests
return a typed reason. A recorded zero remains zero; missing is never zero.
Manual entries and standalone assessment execution/resolution remain later
sources. C1 source/revision contracts already accommodate them; C3 does not
accept a synthetic declaration as a performed assessment or implement their
storage/authority. Unsupported routes remain explicit, not fabricated History.

## Explicit comparisons, without a derived value

Implement one closed, versioned policy, proposed `same_metric_context_v1`, whose
fixed rules are encoded and digested as evaluation-policy content. It is a
comparison-admission policy, separate from the metric's extraction method; no
arbitrary predicates or formulas. Both input references and policy version/digest
travel with the output. This is founder-approved bounded C3 behaviour,
not already supplied by the C1 method signature. Keep its closed policy and
ephemeral evaluation encoding separately versioned; do not add artifact kinds
to the C1 codec or change existing hashes. A policy digest binds semantics, not
source trust or permission.

A pair is comparable only when both are independently tracking-eligible,
available values for the same athlete and **exact** metric and method versions/
digests; units match; supported field-scope kind/path match; and source-retained
`comparison_family` is present, nonempty and equal. Every metric-required context
key must be present and equal. Compare only contexts actually supplied by the
validated source, never invent conditions. Matching labels, protocol lineage or
exercise identity do not establish test/procedure equivalence. This policy is
for supported selected-field observations, not whole-test equivalence.

Inputs must represent two distinct physical observations. Return paired facts
and `comparable`, or `comparison_unavailable` (absent/ineligible evidence), or
`incomparable` with reasons (version/unit/context/scope mismatch). A known mismatch
must remain explicit even if another prerequisite is missing; preserve all
material reasons. Do not subtract, classify improvement or claim a time trend.
Chronology is retained; equal timestamps/unknown civil zones are not ordered by
row IDs or audit dates. Explicit left/right roles identify operands, not proven
baseline/follow-up chronology. No policy for cross-version equivalence, freshness,
assessment completeness, partial comparisons or programme windows is invented.

## Identity, evidence and authority separation

Deduplicate by athlete plus exact History record/block-result/source-block,
exercise/set or workout/step/repetition, and field path. Exclude profile, selection,
source alias, query mode, metric label and correction ID from physical identity.
The same observation may appear in several profiles or compatible metric views;
it is still one physical observation and cannot be both operands of a pair.

C2 input digests include metric identity, so differing metric-dependent digests
alone do not prove alias conflicts. Preserve per-metric input digests. Compare
admitted actual values, known canonical units, captured coverage/known capture
states, source context/chronology and audit-set provenance for alias consistency.
Metric-specific ineligibility or withheld partial values
are not raw-source contradictions: compare actuals only where both are supplied.
Different policy projections retain their own states while sharing physical identity.
Ineligible/incomparable zero-coverage views may hide their original capture state;
unknown capture states remain unknown. Programme attribution is a separate claim,
not a different physical measurement. Conflicting current frames or correction
memberships for one physical identity fail with an explicit conflict; never
choose the newest by timestamp. Multiple coherent record reads do not establish
one cross-record database snapshot. C3 evaluates the supplied frames only.

| Fact | C3 treatment |
|---|---|
| Missing result/field | Preserve C2 `missing`/`unavailable` distinction and reasons; no value invented |
| Partial or skipped work | Preserve `partial`/coverage or `skipped`; permitted partial values stay labelled, never become tracking-eligible or comparison operands |
| Completed selected field in a partial session | May remain available under C2 rules; does not prove full session/test completion |
| Unit/context/method incompatibility | Explicit incomparable/ineligible/unsupported reason; retain safe individual facts |
| Corrections | Preserve current value, exact requested audit reference, full unordered audit membership and audit-set digest; correction is provenance alongside evidence, not a replacement evidence state |
| Missing retained artifact or origin authority | Preserve `programme_scope_unproven`; no programme/test attribution |
| Contradictory claim/proof, stale input digest, ownership/read failure | Typed failure; never relabel as missing or automatically fall back to independent evidence |

Expose independent tracking eligibility, programme attribution
(`not_requested` / `proven` / `unproven`, with contradictory claims as failures),
and prescription eligibility separately. Prescription eligibility is always
false. A failed programme read contains no admitted independent evidence; only
a separately supplied, valid independent result may populate that view. C3
performs no fallback request and cannot erase the original failed claim.

Assessment requirements, missing required context and unevaluated freshness
remain C2 ineligibility reasons. Profiles cannot relax them. Historical/as-of
inputs remain unavailable: correction membership/digests are not result revisions,
and older incomplete audit payloads cannot reconstruct omitted fields. A new
current observation does not silently refresh an older pinned reference.

Legacy programme scope stays unproven. Recorded deployment has zero artifacts;
no current hosted state is inferred beyond that dated record. Do not backfill,
invent canonical bytes, attach profiles to immutable packages or republish Bali
merely to enable tracking. C2's separate scope seal does not place protocol bodies
inside the original package hash. B2 policy/evidence/target freezes and blocked
Cohort 5 km ingestion remain unchanged.

## Synthetic acceptance checks for later implementation

1. Exact dependency closure, duplicate IDs/digests, custom owner, selection lineage,
   explicit upgrades/deselection; no cross-version auto-resolution.
2. Every supported C2 field/unit; malformed/unsupported fields, methods, source
   types and unknown units; real zero versus missing. No conversions/derived targets.
3. Profile projection retains missing/partial/skipped/unavailable/ineligible/
   incomparable reasons, selected-field coverage, and correction annotation.
4. Two available same-definition/context observations are comparable with only
   paired measured values. Missing baseline keeps the other fact visible. Reject
   cross-athlete/version/method/unit/context/scope pairs and same-source operands.
5. One field reused through source aliases, several profiles, independent/programme
   views and metric-dependent digests remains one physical observation; conflicting
   values/audit sets fail. Reordering inputs never chooses a conflict winner.
6. Stale source references, tied audit timestamps, unrelated corrections and
   incomplete historical payloads retain current provenance without replay claims.
7. Synthetic valid sealed programme witness versus missing artifact/link and
   contradictory proof; no claim fallback, no manufactured test eligibility.
8. Deterministic ephemeral result encoding/hash, exact policy/dependency/input and
   audit digests included; profile display order preserved, observation sets sorted
   only for serialization. Hash is not a permission credential or durable ledger.
9. No mutations, fetching, stores, production transport/consumer registration,
   compiler/SQL/B2 changes or prescription eligibility across any result state.

Example fixtures: two synthetic recorded seconds values `12` and `14` with exact
matching definition/context can be paired; no delta or “better” label is emitted.
One reused source in synthetic curated/custom profiles counts once; a skipped
scope has no numeric result; an unsealed programme claim stays unproven even if
a separately requested independent observation is available.

Later implementation verification: focused `test/performance_tracking/` tests,
changed-file Dart analysis, required Phase 2 safety gate and diff check. Reuse
committed C1/C2 compiler/database compatibility evidence; no DB or full Flutter
suite unless a concrete changed shared path warrants it. At the original proposal closeout none were run; links/diff were its checks.
The implementation handoff now records the actual focused verification.

## Settled choices and founder approval

Already settled: optional programme/curated/custom tracking; immutable exact
versions and explicit upgrades; athlete ownership/reusable History references;
future append-only manual corrections; observational defaults; no prescription
promotion; no package changes or fabricated legacy proof. Do not reopen them.

**Approved material decision:** C3 is extraction plus explicit comparability
only, deferring numeric `difference`. Recommended because existing method
contracts do not define reproducible arithmetic/comparison semantics, and this
slice validates the reusable observation/profile layer without enlarging C1.
Alternative: include subtraction now, requiring separately versioned executable
operand/direction/signed-decimal/context and precision rules, new semantics and
regressions; a signature alone is insufficient. Arithmetic remains outside C3.
No real profile membership, test procedure, units conversion, best/latest rule,
programme-binding content or manual-entry policy needs selecting for this slice.

The separately authorised C3 implementation is complete as recorded in the handoff.
This document grants no further implementation. Stop for founder integration
approval; no push.
