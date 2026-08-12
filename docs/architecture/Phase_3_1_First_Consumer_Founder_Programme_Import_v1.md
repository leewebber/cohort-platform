# Phase 3.1 first consumer — founder programme YAML import

**Status:** complete and founder-accepted at implementation commit
`fb724d2f7a854bd4a36cbb45c884adcb82222765`. Phase 3.1 is complete.

## Consumer and composition

`founder_programme_yaml_import` remains the existing
`FounderProgrammeImportService`. Founder YAML may now include the optional,
untrusted field `transitional_exercise_id`.

The pure-Dart importer owns only
`FounderProgrammeTransitionalIdentityResolver`, a narrow resolution port.
`tool/founder_programme_import/repository_transitional_identity_adapter.dart`
adapts that port to the repository-owned `TransitionalExerciseIdBridge`.
`tool/import_programme.dart` is the single bridge-aware composition root and
constructs `InMemoryTransitionalExerciseIdBridge` from
`FounderApprovedIdentityMappingsPhase31F.allMappings`. The existing
`tool/importer/bin/import_programme.dart` invocation forwards to that root.
Neither the bridge nor its 21 mappings is copied.

## Input and canonical output

```yaml
- transitional_exercise_id: cohort.exercise.goblet_squat
  exercise_name: Goblet Squat
  order: 1
```

When `transitional_exercise_id` is present it is the identity authority.
`exercise_name` is display-only. Combining it with `exercise_slug` is rejected.
A failed transitional reference never falls back to slug, name, alias, fuzzy
matching, relationships, substitutions, or inferred identity. Legacy exact
slug/name behavior remains available only when no transitional identity is
supplied.

The bridge output is validated against the caller-supplied catalogue. The
canonical target must exist and be published. Only that canonical `EX-*` value
may populate `SessionBlockExerciseLink.exerciseId`.

## Fail-closed matrix

| Condition | Issue code |
|---|---|
| No transitional ID, slug, or name | `missing_exercise_reference` |
| Malformed transitional ID | `invalid_transitional_exercise_id` |
| No operational or historical mapping | `unmapped_transitional_exercise_id` |
| Multiple canonical mapping targets | `conflicting_transitional_mapping` |
| Historical mapping is retired | `retired_transitional_mapping` |
| Canonical target absent from supplied catalogue | `missing_canonical_target` |
| Canonical target occurs more than once | `conflicting_canonical_target` |
| Canonical target is not published | `canonical_target_not_published` |
| Transitional ID combined with slug | `conflicting_authored_reference` |

Located issues carry import key, week, day, session, block, exercise order, raw
reference, code, message, and sorted canonical candidates. They sort by
week/day/session/block/exercise/code/raw reference. Global schema and programme
issues precede located identity issues.

## Validation and writes

The validator constructs an immutable `FounderProgrammeResolvedIdentityPlan`
for every exercise in the complete programme. Any global or identity issue
causes `writes_started=false`; no lineage, version, protocol, block, link, or
programme-tree write starts. Persistence after successful validation remains
the existing multi-table sequence and is not newly transaction-atomic.

## Firewalls and deferrals

- Plan Package v1, its compiler, canonical JSON, hashes, and trusted importer
  are unchanged.
- MovementStandard, CoachingContent, VideoReference, the Phase 3.2D aggregate,
  and the eight-record pilot are unchanged and unwired.
- No parallel canonical catalogue or transitional mapping collection exists.
- The historical 132-row review export is not runtime data.
- No migration, RLS, Supabase mutation/contact, deployment, publication,
  athlete UI, Workout Player, evidence, adaptation, comparison, substitution,
  media, or hosted verification is included.
- Hosted verification and stronger multi-table transactionality remain
  deferred.

## Local verification

The implementation checkpoint requires:

- all founder importer and bridge-consumer behavior tests;
- all Exercise Database and Exercise Knowledge authority regressions;
- Plan Package compiler/import and canonical JSON/SHA-256 golden regressions;
- the six-group Phase 2 consolidation safety gate;
- the full Flutter test suite;
- zero diagnostics in every changed Dart file; and
- full analysis no greater than the accepted 423-issue baseline, with no
  error-level diagnostics.

The 423-issue baseline-tolerant exception applied only to this implementation
checkpoint and is now consumed. It does not resolve the repository warning
baseline, carry forward, or authorise another baseline-tolerant change.

On 2026-08-12 all listed behavior and regression suites passed, including the
full Flutter suite and all six Phase 2 safety groups. Changed-file analysis
reported zero issues. Full analysis reported 415 issues, below the recorded
pre-implementation baseline of 423, with no error-level diagnostics and no
changed file represented.

Founder acceptance confirms all 21 mappings, canonical-target validation, and
the all-identities-before-writes boundary. It does not make the historical
132-row review export runtime authority, connect Exercise Knowledge to a
consumer, change Plan Package v1, authorise hosted verification/deployment,
authorise Product-UI Gate 2 or athlete UI, or allocate Phase 3.2E/F/G.
