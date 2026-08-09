# Phase 3.1C — Exercise Knowledge Repository Boundary

**Status:** COMPLETE and **COMMITTED**  
**Recorded:** 2026-08-09  
**Commit:** `957a63d9809e8291b8715e3743feccb93a798eee`  
**Baseline (post–3.1B commit):** `b9952b69340d3150e6b62e06951aa2c5d90a1e38`  
**Contracts:** [`Phase_3_1B_Exercise_Knowledge_Contracts_v1.md`](./Phase_3_1B_Exercise_Knowledge_Contracts_v1.md)

```text
PHASE_3_1B_ACCEPTED=true
PHASE_3_1C_REPOSITORY_BOUNDARY_COMPLETE=true
CANONICAL_EXERCISE_ID=EX-*
ALIASES_AUTHORITATIVE=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCTION_PERSISTENCE_ADDED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=not_applicable
PHASE_3_2_STARTED=false
```

---

## 1. Repository responsibility

Provide a domain port through which Cohort can eventually load, validate, and
publish canonical Exercise Knowledge (`EX-*`) without becoming:

* a programme prescription authority;
* a completion-evidence authority;
* an adaptation / substitution selector;
* a second live exercise catalogue (existing `exercises_v2` / ontology untouched).

Package: `lib/domain/exercise_knowledge/`  
Port: `ExerciseKnowledgeRepository`  
Test impl: `InMemoryExerciseKnowledgeRepository`  
Publication: `ExerciseKnowledgePublicationService`  
Snapshot load: `ExerciseCatalogueSnapshotLoader`

---

## 2. Retrieval contracts

| Operation | Contract |
|-----------|----------|
| Definition lookup | By canonical `ExerciseId` only |
| Multi-get / list | Deterministic order by `EX-*` |
| Visibility | `operational` (published), `historical` (published+retired), `authoring` (all) |
| Missing | Explicit `ExerciseDefinitionLookup.isMissing` |
| Display name | Never used as identity key |
| Alias resolve | Returns canonical `ExerciseId`, `AliasAmbiguous`, or `AliasNotFound` |

---

## 3. Catalogue aggregate

`ExerciseCatalogueSnapshot` holds:

* `catalogue_version`
* definitions
* relationships
* comparison protocols

Serialization and list ordering are deterministic (sorted by id). Used for
validation, publication, and immutable published snapshots.

---

## 4. Lifecycle and publication flow

```text
Draft knowledge
  → ExerciseCatalogueSnapshotLoader / validator (fail closed)
  → founder approval via ExerciseKnowledgePublicationService
  → immutable published version in repository
  → later retirement (still historically resolvable)
```

Rules:

* Draft is never returned under `operational` visibility.
* Publication fails closed on validation errors.
* Same published id + same version cannot silently change content (bump version).
* Only `actingOwner == founder` may publish or retire.
* UI is not implied as authority.

---

## 5. Alias semantics

* Aliases are search/authoring aids only (`ALIASES_AUTHORITATIVE=false`).
* Resolution never exposes an alias string as canonical identity.
* Ambiguous aliases fail closed (`AliasAmbiguous`).
* `cohort.exercise.*` is **not** resolved here — deferred to
  `TransitionalExerciseIdBridge` (port only; unimplemented).

---

## 6. Historical resolution

Retired definitions remain in the working set and are visible under
`historical` / `authoring` visibility. They are excluded from
`operationalSnapshot()`.

---

## 7. Relationship lookup semantics

* Outgoing / incoming retrieval preserves direction and type.
* Lifecycle visibility filters apply.
* No ranking, scoring, or automatic substitution selection.

---

## 8. Comparison-protocol lookup

* Retrieve by stable protocol id and optional version pin.
* Compatibility helper applies only declared protocol→exercise binding.
* Never infers comparability from relationship type, family, or modality.

---

## 9. Future code-authoring integration

Programme / Plan Package YAML will eventually reference:

```yaml
exercise_id: EX-0001
```

The future compiler integration (not in this sprint) must:

* reject unknown canonical exercise IDs;
* reject aliases where canonical IDs are required;
* validate prescription dimensions against exercise capabilities;
* validate contextual adaptation metadata;
* resolve referenced comparison protocols;
* distinguish reusable exercise facts from programme-specific intent.

Plan Package compilation and programme YAML are **unchanged** in 3.1C.

---

## 10. Deferred persistence decision

Meaningful production persistence requires a schema / migration sprint.
Phase 3.1C intentionally provides only:

* domain ports;
* in-memory repository;
* snapshot loader + publication service.

No temporary file/SQLite/Supabase store was improvised.

---

## 11. Deferred identity bridge

`TransitionalExerciseIdBridge` is a neutral port placeholder.
`cohort.exercise.*` knowledge remains transitional and untouched.

---

## 12. Explicit non-authorities

This boundary does **not**:

* generate workouts;
* apply adaptations;
* select substitutions;
* compute programme progression;
* store sets/reps/load/tempo or athlete results;
* replace `ExerciseCatalogueService` / `exercises_v2` / YAML ontology.

---

## 13. Manual testing

```text
MANUAL_TESTING_APPLICABILITY=NOT_APPLICABLE
MANUAL_TEST_PLAN=not_required
MANUAL_TESTS_COMPLETED=false
DEFERRED_TO_INTEGRATION_CHECKPOINT=Phase 3.1D or first live-consumer integration
```

No athlete- or founder-facing journey changed.

---

## 14. Exact next sprint

**Phase 3.1D — Canonical Exercise Identity Bridge**

Map transitional knowledge ids to `EX-*` without migrating live consumers'
runtime behaviour until explicitly authorised.

---

## Implementation map

| Area | Path |
|------|------|
| Repository port | `ports/exercise_knowledge_repository.dart` |
| In-memory impl | `in_memory/in_memory_exercise_knowledge_repository.dart` |
| Snapshot | `models/exercise_catalogue_snapshot.dart` |
| Publication | `services/exercise_knowledge_publication_service.dart` |
| Loader | `services/exercise_catalogue_snapshot_loader.dart` |
| Bridge port (deferred) | `ports/transitional_exercise_id_bridge.dart` |
| Tests | `test/domain/exercise_knowledge/exercise_knowledge_repository_test.dart` |
