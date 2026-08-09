# Phase 3.1E — Structured Exercise Relationship Graph

**Status:** COMPLETE (**commit pending in this close-out**)  
**Recorded:** 2026-08-09  
**Baseline (post–3.1D commit):** `38f27ca478779903fc1d93bca5368daed87388f2`  
**Bridge:** [`Phase_3_1D_Canonical_Exercise_Identity_Bridge_v1.md`](./Phase_3_1D_Canonical_Exercise_Identity_Bridge_v1.md)

```text
PHASE_3_1D_ACCEPTED=true
PHASE_3_1E_RELATIONSHIP_GRAPH_COMPLETE=true
CANONICAL_EXERCISE_ID=EX-*
GRAPH_NODE_IDENTITY=EX-*
RELATIONSHIPS_SELECT_SUBSTITUTIONS=false
RELATIONSHIP_IMPLIES_COMPARABILITY=false
TRAVERSAL_IMPLIES_COMPARABILITY=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=deferred
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

---

## 1. Graph purpose and non-authorities

`ExerciseRelationshipGraph` is a **derived read model** over a validated
`ExerciseCatalogueSnapshot`. It supports candidate discovery inspection only.

It is **not**: a second repository; adaptation/substitution engine; programme
generator; progression calculator; comparison authority; or persistence store.

---

## 2. Canonical node identity

Nodes are canonical `ExerciseId` (`EX-*`) only. Transitional ids, aliases, and
display names cannot identify nodes or endpoints.

---

## 3. Relationship vocabulary inventory

| Type | Directional | Symmetric | Inverse | Comparability |
|------|-------------|-----------|---------|---------------|
| `progression` | Yes | No | Authored separately (`regression`) | Never by default |
| `regression` | Yes | No | Authored separately | Never by default |
| `lateral_alternative` | Yes | No | Authored separately | Never by default |
| `equipment_alternative` | Yes | No | Authored separately | Never by default |
| `environment_alternative` | Yes | No | Authored separately | Never by default |
| `related_non_comparable` | Yes | No | Authored separately | Never by default |
| `directly_comparable_variant` | Yes | No | Authored separately | Only with explicit protocol |

See `ExerciseRelationshipSemantics`. No competing vocabulary invented.

---

## 4. Direction and inverse semantics

Direction is preserved (`source → target`). Reverse edges are never invented.
Incoming lookup returns authored reverse direction only when such an edge exists.

---

## 5. Graph construction and validation

`ExerciseRelationshipGraph.build` fail-closes on: noncanonical/transitional
nodes/endpoints; missing endpoints; self-relations; duplicate edges; missing
comparison protocols for comparable variants; non-founder published edges;
prescription/evidence fields on edges.

Visibility modes: `operational` / `historical` / `authoring`.

---

## 6. Constraint semantics

`RelationshipEligibilityEvaluator` uses existing `SubstitutionConstraint` fields
only. Results: `eligible` (may be considered), `ineligible`, or `indeterminate`
(incomplete context — fail closed for selection). `isSelected` is always false.

---

## 7. Traversal semantics

Bounded (`maxDepth`), deterministic, cycle-safe (visited edge ids), type-filtered,
direction-explicit, non-ranking. Hops are never recommendations.

---

## 8. Substitution versus selection

Relationships identify possible connections. Eligibility means “may be
considered.” Nothing ranks, chooses, or rewrites a session.

---

## 9. Relationship versus comparability

`ComparabilityFirewall` is a **negative firewall only** — not a competing
comparison authority. It proves adjacency, traversal, modality, family,
substitution eligibility, and bridge mappings do **not** imply comparability.

- Same-exercise comparison does **not** require a graph edge.
- A `directly_comparable_variant` edge alone is **never** sufficient.
- Protocol / identity resolution remains with `ComparisonProtocol`,
  `ComparisonIdentity`, and previous-performance services.
- The graph must not merge performance histories.

---

## 10. Lifecycle and historical resolution

| View | Includes |
|------|----------|
| Operational | Published only |
| Historical | Published + retired |
| Authoring | Draft + published + retired |

Retirement excludes from operational discovery but remains historically
resolvable. Silent mutation of published edges remains forbidden (publication
service / version rules from 3.1C).

---

## 11. Founder publication authority

Unchanged from Phase 3.1C — only founder-owned published relationships enter
the operational graph.

---

## 12. Hotel and limited-equipment examples (fixtures only)

1. Back squat → goblet (equipment alternative)  
2. Barbell RDL → DB RDL (equipment tokens)  
3. SkiErg → banded ski (hotel room)  
4. Outdoor vs treadmill distinct nodes  
5. Back squat → hotel BW squat (hotel room only)  
6. Kettlebell-required edge ineligible without KB  
7. Eligible ≠ selected  
8. Substitution ≠ comparison  
9. Retired related edge historically resolvable  
10. Missing target fails closed  

---

## 13. Planned future consumers

Adaptation candidate discovery, founder review tools, Plan Package validation
hints — all deferred; none wired in 3.1E.

---

## 14. Deferred production persistence

In-memory / snapshot-derived only. No schema migration.

---

## 15. Deferred live integration

No Workout Player / Plan Package / adaptation / Progress wiring.

---

## 16. Manual testing

```text
MANUAL_TESTING_APPLICABILITY=DEFERRED_TO_FIRST_LIVE_CONSUMER_INTEGRATION
MANUAL_TEST_PLAN=documented
APP_LAUNCHED_IN_CHROME=false
MANUAL_TESTS_COMPLETED=false
DEFERRED_TEST_TRIGGER=First live consumer of ExerciseRelationshipGraph or TransitionalExerciseIdBridge
```

---

## 17. Remaining identity-mapping decisions

Unchanged from 3.1D: author 21 production `platform_exercise_id` links; resolve
`running` outdoor vs treadmill; confirm HYROX/SkiErg comparison boundaries.

---

## 18. Exact next sprint

**Phase 3.1F — Founder Canonical Catalogue and Identity-Mapping Review**

---

## Implementation map

| Area | Path |
|------|------|
| Graph | `graph/exercise_relationship_graph.dart` |
| Eligibility | `graph/relationship_eligibility.dart` |
| Firewall | `graph/comparability_firewall.dart` |
| Semantics | `vocabulary/exercise_relationship_semantics.dart` |
| Tests | `test/domain/exercise_knowledge/exercise_relationship_graph_*.dart` |
