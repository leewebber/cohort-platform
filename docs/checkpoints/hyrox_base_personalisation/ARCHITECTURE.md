# Architecture findings and additive production compatibility plan

2026-10-22 · inspected remote base `fa5186fab8c1038fdb1972aea75a3880935c2d2f`.
This records actual current contracts and proposes a future additive production contract;
no future parser, binding admission, migration or hosted enforcement is claimed delivered.

| Boundary inspected | Current fact | Consequence for this slice |
| --- | --- | --- |
| [C1 contracts](../../../lib/domain/performance_tracking/tracking_contracts.dart), [validator](../../../lib/domain/performance_tracking/tracking_validation.dart), [codec](../../../lib/domain/performance_tracking/tracking_codec.dart) | Independent schema-1 tracking artifacts; units/sources/profiles/assessments; strict decode and dependency digests; field-extraction/difference signatures, not executable personalisation | Shared benchmark semantics do not silently create a tracking profile, assessment or prescription credential |
| [Tracking README](../../../lib/domain/performance_tracking/README.md), [C3 evaluator](../../../lib/application/performance_tracking/profile_tracking_evaluator.dart) | Manual observations cannot claim assessment/programme authority; C2 source identity/ownership and C3 admission/comparability remain observational; measurements grant no prescription eligibility | No bypass of C2, ingestion of real History, promotion of tracking values, or change to admission |
| [Sprint C §6](../../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md#6-schema-and-hash-reassessment) | Reserves future schema-v3 optional tracking_profile_binding; old package hashes exclude athlete selection/measurements | No v1/v2 bindings inserted, no hash reinterpretation or production profile selection |
| [Package parser](../../../packages/cohort_plan_package/lib/src/plan_package_yaml_parser.dart), [canonicaliser](../../../packages/cohort_plan_package/lib/src/plan_package_canonicaliser.dart) | Only existing v1/v2 and enumerated root fields; unknown bindings refused; package session references do not own complete protocol bodies | Existing golden bytes/hashes and published version semantics remain intact |
| [B2 calculator](../../../lib/domain/running_workout/running_pace_calculation.dart), [benchmark policy](../../../lib/domain/running_workout/running_benchmark_policy.dart) | Exact fraction support; policy uses eligible 5 km elapsed evidence, speed percentages and explicit freshness | Base 10 km pace multipliers are a different rule/source policy; do not relabel or broaden B2 |
| [B2 snapshots](../../../lib/domain/running_workout/running_target_snapshot.dart) | Occurrence-owned snapshot wins on retry; exact source/policy retained | Same preservation principle in independent local snapshots; no production freezer changed |
| [B3 entry](../../../lib/features/internal_tools/b3_device_benchmark_entry.dart), existing structured-running execution | Device-test-only manual 5 km RPC path; verified v2 time runner, no commercial Base adoption | No reuse of device RPC, cohort 5 km ingestion permission, runner mapping or export claim |
| [Prescription execution snapshot](../../../lib/domain/adaptation/application/prescription_execution_snapshot.dart) | Immutable structured sets/reps/rest; accepted adaptation belongs to current prepared session | Independent partial previews never mutate prepared sessions or introduce future-session adaptation authority |
| [Accepted founder mapping](../../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md) and [prior source decision](../hyrox_base_source_readiness/DECISION.md) | Canonical exercise identity differs from protocol source, variant and published definition version | Semantic metric enums identify exact tests only; no fabricated EX IDs or Base exercise/version bindings |

## Delivered independent boundary

[Domain](../../../lib/domain/hyrox_base/base_personalisation.dart) imports only core Dart
and existing crypto. [Controller](../../../lib/internal_review/hyrox_base/base_review_controller.dart)
is fixed-owner synthetic memory-only review. The [separate Flutter entry](../../../lib/main_hyrox_base_review_preview.dart)
and [terminal examples](../../../tool/hyrox_base/review_examples.dart) compose that boundary.
Production main, programme materialisation, canonical compiler, C1/C2/C3, B2/B3,
Studio source/workspace/TAR profiles, persisted results and actual exercise definitions
are unchanged. Benchmarks are declared inputs to this separately authorised local rule,
not admitted production evidence. No assertion that Sprint C is complete follows.

Structured intervals retain stable local work/recovery IDs, repeat ordinals, integer
seconds and typed exact pace windows. No recovery follows the last work repetition;
recovery never inherits work pace. These are usable future adapter inputs. Garmin
unit/precision/step limits, provider conversion and consent are unimplemented.

## Proposed additive contract: Plan Package v3

**Prepared design and compatibility plan only.** Build and approve exact v3 schema,
Dart and SQL validation/canonicalisation and immutable dependency publication before
production integration. Keep the reserved optional `tracking_profile_binding` for
observational scope; it grants no prescription permission. Add a separately optional
`personalisation_binding` only in that new version, with this closed shape:

- `binding_schema_version`: 1.
- `rule`: exact rule ID, version and canonical content digest; the immutable dependency
  must include formula/unit/rounding semantics, approved week doses and source policy.
- `benchmark_requirements`: ordered exact metric-definition ID/version/digest,
  test meaning (10 km elapsed completion, 2 km row, squat 5RM etc), accepted source
  declarations and unit conversions, performed chronology requirements and explicit
  `freshness: none` until separately authored otherwise. Never infer test execution.
- `targets`: exact week/day/slot/session protocol revision, block/workout/step IDs,
  metric-to-rule input binding, output unit and authored parameter values; for strength,
  exact exercise/variant/version and work-set scope. No display-label or adjacency match.
- `missing_input_policy`: effort-only only for explicitly authored fallbacks; otherwise
  numerical unavailable, while independently supported programme start remains allowed.
- `replacement_policy`: explicit athlete acceptance for future unstarted occurrences;
  retain old evidence and selection revisions and never replace started/completed snapshots.

Canonical v3 hashes include every **present programme-owned** binding field, target
scope and immutable dependency digest. They exclude athlete IDs, input values/selections,
acceptance timestamps, equipment configuration, computed targets, actuals and UI state.
Do not insert a new side binding into an old published v1/v2 hash or update its defaults.
Fresh immutable v3 programme versions are required. A missing optional binding remains
valid with no personalisation; malformed/unknown/unresolved declared bindings fail closed.

Production evidence/selection records need exact owner, immutable result revision/digest,
source/test context, selected rule and acceptance revision. Start must atomically recheck
selection/configuration/rule/occurrence revisions, then freeze authored and calculated
values, full benchmark input/provenance, equipment increment and rule content. Persist
prescription and actuals separately, with authenticated ownership, replay/idempotency,
concurrent start-versus-selection and correction proof. A proposal is not accepted just
because a worker completed. Future target updates must never overwrite in-progress work;
completion cannot select benchmarks or progress targets automatically.

Compatibility rollout order:

1. Finalise/approve immutable benchmark/derivation policy artifacts and complete source
   exercise/protocol bindings; keep observational profiles independent.
2. Implement strict v3 Dart/SQL/compiler support, recursion/digest checks, golden v3
   vectors and rejection cases. Re-run unchanged v1/v2 goldens and source/workspace/TAR
   round trips. Old clients must refuse unsupported v3 before any write.
3. Add owner-gated append-only benchmark/consent and occurrence snapshot storage with
   local role/API/replay/concurrency proof; no freshness default or backfill into old pins.
4. Implement programme prepare/start preview and accepted future-occurrence revision
   semantics, actual-load capture and equipment configuration. Prove production running
   and erg representations against authored intervals and exact output units.
5. Complete coaching/editorial, authenticated/device and release/security gates; only
   then separately approve hosted deployment, publication/assignment or distribution.

This plan does not allocate broader Sprint C, Stage 3, Test Week authoring or a Garmin
integration. It is the explicit remaining production bridge, not a silent local bypass.
