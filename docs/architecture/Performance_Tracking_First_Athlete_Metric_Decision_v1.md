# First athlete History slice — proposed metric decision

**Recorded:** 2026-10-07. **Status:** PROPOSED_NOT_FOUNDER_APPROVED_NOT_PUBLISHED.
Documentation only. No executable definitions or real profile publication.

Clean starting HEAD: `1ec96aca963ed589cedbac4c02999a8135b9f9b7`, branch
`codex/athlete-tracking-first-slice-proposal`, repository
`/Users/leewebber/Developer/cohort_platform`. Cached origin/main:
`f316a48ba529e98d408bf0acefc9ea2798eb9726`; no fetch or hosted refresh.
The [first-slice proposal](./Performance_Tracking_First_Athlete_History_Slice_Proposal_v1.md)
and its commit are preserved. This decision refines its tentative duration
candidate; its discovery, ownership, wiring and release boundaries still apply.

## Recommendation and candidate audit

Recommend **Recorded block distance**, in kilometres, inside **Distance
observations**. It answers “What distance did this History block record?” It
does not answer “Am I fitter?” More distance may reflect a different workout,
not improvement. No totals, conversions, pace, differences or rankings.

The following three candidates use existing extraction signatures. No live
athlete records were inspected, so availability and prevalence remain unknown.

| Candidate | Exact raw field and binding | Value and comparison conditions | Decision |
|---|---|---|---|
| Recorded block distance | `result_data.distance` on a block with `result_type=distance` or `endurance`; explicit `result_data.distanceUnit`. Exact owned record → block-result → source-block identity. | Useful record of completed distance. Kilometres are a native model unit. No exercise ID, reps or equipment is necessary to report this raw quantity. Modality, equipment, duration, route and conditions **would** be necessary for a performance-equivalence claim; current context does not establish them. | Recommended as a quantity observation only. Existing C2/C3 support extraction and bounded comparison admission, with refusals retained. |
| Recorded block duration | `result_data.durationSeconds` on `duration`, `distance` or `endurance` blocks; same exact parent/source binding. Integral seconds. | Useful elapsed-time fact; faster/slower has no meaning without identical task/distance and conditions. Not a sum of session/block times or generic session-duration improvement. | Supported raw fact, but less useful as the first distance-oriented History profile. No fitness claim supported. |
| Recorded set load | `load`, explicit `load_unit=kg`; exact record → block → exercise-result → set-result, with each parent checked. | Useful load log. Exercise identity, reps, equipment, technique/range and relevant set conditions are needed to interpret strength performance. C2 does not project these into comparison context. Exercise titles and equal loads do not prove comparability. | Raw extraction supported; an exercise-specific strength metric is not honestly supported by the current comparison contract. Defer. |

Evidence: [C1 definitions](../../lib/domain/performance_tracking/tracking_contracts.dart),
[C2 extraction](../../lib/application/performance_tracking/history_tracking_projection.dart),
[C3 evaluator](../../lib/application/performance_tracking/profile_tracking_evaluator.dart),
[History result models](../../lib/features/performance/models/performance_result_data.dart)
and [snapshot builder](../../lib/features/performance/services/performance_snapshot_builder.dart).
Distance/endurance model serialization writes `distanceUnit`, normally `km`;
their hydration defaults are **not** tracking authority. C2 reads raw coherent
data and rejects a measured distance without a supported explicit unit. Metres
are also readable, but are incompatible with this proposed kilometre metric;
do not convert, relabel or default them into admission.

## Proposed immutable content closure

These are proposed v1 content specifications, not instantiated artifacts or
approved registry entries. Proposed IDs below reserve no real catalogue content.
On separately authorised packaging, C1 canonical encoding must produce each
digest from the frozen content and exact dependency closure, method → metric →
profile. No invented digest, implicit latest reference or silent content change.
Changes after approval require a new version and explicit reference adoption.

| Artifact | Proposed content |
|---|---|
| Method | ID `proposed.history.block_distance.km.extract`, version `1`; kind `fieldExtraction`; `inputUnits=[kilometres]`; `outputUnit=kilometres`. Existing field extraction only; no new computation. |
| Metric | ID `proposed.history.block_distance.km`, version `1`; label **Recorded block distance**; unit `kilometres`; exact v1 method reference above, with its canonical digest when packaged. |
| Metric evidence policy | `allowedSources=[historyResult]`; `captureField=distance`; `requiredContext=[]`; `requiresAssessment=false`; `allowPartial=false`; `freshnessCivilDays=null`. No freshness or assessment claim. |
| Profile | ID `proposed.history.distance_observations`, version `1`; kind `curated`; name **Distance observations**; view `history`; ordered metrics: exactly the proposed metric's v1 reference/digest. No athlete ID, predecessor, programme binding or saved selection. `curated` is a proposed composition kind, not evidence of approval. |

Proposed athlete description: “The distance recorded for a selected completed
History block, in kilometres. This is an observation of what was recorded, not
a fitness score. Comparison may be unavailable when evidence or context is
missing.” C1 metric/profile schemas have no description field. This is proposed
accompanying read copy, not a new wire key or a hashed semantic constraint.

`requiredContext=[]` deliberately permits a valid independent observation even
when no comparison family was retained. It does **not** relax C3's mandatory
pairwise context requirement. No unsupported context keys are declared merely
to suggest that exercise/equipment conditions were checked.

### Exact source and evidence requirements

Use the deployed independent C2 reader/strict bridge, not separately hydrated
History models. Resolve current authenticated athlete ownership, exact record
ID, block-result ID and source-block ID. Require the block's record parent and
both row/snapshot source-block identities to agree. Select exactly
`['result_data','distance']`; no exercise/set/workout/repetition aliases for this
profile. Never bind by title, position, planned distance, timer or note.

The raw block result type must be supported and agree with `result_data.resultType`
when data is present. Values must be native finite nonnegative numbers with an
explicit supported unit. Recorded zero is a value, not a missing marker.
Block completion is required; an endurance result also requires its explicit
`completed` flag. A completed block within a partial/abandoned session does not
prove completion of the whole session, test or programme.

Preserve C2 outcomes and C3 projection:

- **Recorded:** available complete kilometre evidence can be tracking-eligible.
  Show value, unit, performed chronology/precision and source provenance.
- **Missing:** absent selected rows and not-started capture remain distinct
  reasons; show no value. Do not discover only numeric fields and hide these.
- **Partial:** visible partial state; `allowPartial=false` suppresses its value
  from this metric's admitted output. Do not recover it from raw data to compare.
- **Skipped:** visible skipped state, no value and no inferred completion.
- **Unavailable:** a completed block with no recorded distance is unavailable,
  not zero. Malformed units/types/parents fail explicitly, not as missing data.
- **Incomparable/ineligible:** preserve the evaluator's state, refusal reason
  and any source value it legitimately retains, without portraying it as admitted.
- **Corrected:** correction provenance accompanies the current evidence state;
  it is not a replacement state. Retain selected-input digest and actual audit
  references. A correction does not restore missing context or prove historical
  as-of reconstruction. Do not invent earlier values or a correction delta.

Each coherent frame is record-local. Two successful reads do not certify a
shared cross-record snapshot. Duplicate aliases remain one physical observation;
contradictory aliases fail. The same source cannot be compared to itself.

### Comparison rule and indispensable limits

Use the existing exact `TrackingComparabilityPolicy.reference` and C3 evaluator.
Request one explicit pair, with the same exact metric and method versions/digests,
same block-field scope, distinct physical observations, eligible evidence and
compatible units. Both must carry equal, nonempty retained
`block_snapshot.comparisonFamily`, projected by C2 as `comparison_family`.
Missing family means comparison unavailable; unequal family means incomparable.
Caller `expectedContext` can check retained context, not supply missing proof.

“Comparable recorded distances” means admission under that policy only. It
does not certify equivalent exercise, modality, equipment, elapsed time or route,
and cannot support an improvement claim. Keep that explanation near the pair.
Technical policy/reference details may sit in expandable Evidence.

The snapshot builder derives comparison families for interval/circuit contracts;
generic distance/endurance capture does not guarantee one. Do not author a new
family, infer it from titles or backfill legacy snapshots. An authorised source
feasibility check is needed before promising any real comparable pairs.

There is no indispensable extraction-contract gap for this narrow observation.
There **is** an indispensable retained-context/semantics gap for calling it a
standardised performance measure (and for exercise-specific load comparisons):
C2 currently projects only comparison family, not the required typed conditions.
Closing that gap needs a separate contract/evidence proposal. If the founder
requires performance equivalence or guaranteed comparisons in the first slice,
stop and re-scope rather than implementing around this limitation.

## Synthetic examples — policy expectations, not new executed tests

Assume valid full C1 closure, authenticated synthetic owner, complete strict C2
frames with matching exact parents/source IDs, terminal records and two distinct
block identities. IDs and family below are illustrative fixture labels only;
no real retained family or athlete evidence is asserted.

| Synthetic observation | Performed date | Raw capture | Retained family |
|---|---|---|---|
| A | 2026-09-01 | completed distance block, `resultType=distance`, `distance=5`, `distanceUnit=km` | `synthetic.distance.family.a` |
| B | 2026-09-08 | completed distance block, `resultType=distance`, `distance=6`, `distanceUnit=km` | `synthetic.distance.family.a` |

**Valid pair:** A/B use the same proposed exact metric/method and field scope;
both are available and tracking-eligible. Existing C3 admits `comparable`.
Display the two recorded quantities and dates; no difference or improvement.
Even this admission proves no additional training conditions.

**Refused pair:** remove B's retained family, keeping its valid value/unit/date.
Both independent observations remain usable. C3 returns
`comparison_unavailable`, reason `context_unavailable:comparison_family`.
Plain-language reason: “Comparison context was not recorded for both blocks.”
If instead families differ, C3 returns `incomparable` with
`context_incompatible:comparison_family`. Two numbers alone are insufficient.

## Exact founder decision and remaining gates

Approve or reject this proposed v1 **Distance observations** content closure:
one complete-only **Recorded block distance** metric, kilometre raw extraction,
independent History sources, no conversions, and C3 comparisons limited to
recorded-quantity admission with missing-context refusals. Explicitly accept
that the first slice may show useful observations with **no comparable pair**,
and is not a standardised fitness/improvement measure. Otherwise direct a
different metric purpose and separately scope the indispensable evidence gap.

Content decision does not authorise packaging, implementation, publication or
release. Preserve the first-slice proposal's separate source discovery/binding,
production wiring and athlete presentation decisions. Selection persistence,
manual entry, custom editing and programme tests remain deferred. No programme
attribution is requested; legacy scope stays unproven. Tracking cannot change
programming or grant prescription eligibility.

The recorded hosted `training_sessions` SELECT/RLS discrepancy remains a
separate release security gate; this metric needs no session-table read and
neither relies on that grant nor remediates it. See the
[C2 reader handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md).
Existing [C1](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md),
[C2](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md) and
[C3](../checkpoints/PERFORMANCE_TRACKING_C3_EVALUATION_HANDOFF.md) verification is
reused as committed evidence, not rerun. This task checks local links and Git
diff only; no tests, safety gate, analysis, builds or hosted reads are claimed.
