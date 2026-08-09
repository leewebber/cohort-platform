# Phase 3.1B — Canonical Exercise Domain Contracts

**Status:** COMPLETE (contracts + validation + fixtures; **uncommitted pending review**)  
**Recorded:** 2026-08-09  
**Baseline (post–3.1A docs commit):** `5d05e66d6616090afe7408a2eb7ed14e6db94e2b`  
**Discovery:** [`Phase_3_1A_Exercise_Database_Discovery_v1.md`](./Phase_3_1A_Exercise_Database_Discovery_v1.md)  
**Binding freeze:** [`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md)

```text
PHASE_3_1A_ACCEPTED=true
PHASE_3_1B_CONTRACTS_COMPLETE=true
CANONICAL_EXERCISE_ID=EX-*
THIRD_EXERCISE_ID_INTRODUCED=false
SUBSTITUTION_IMPLIES_COMPARABILITY=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
PHASE_3_2_STARTED=false
```

---

## 1. Purpose of the Exercise Knowledge Authority

Establish one typed domain contract surface for reusable exercise facts so later
sprints can resolve the dual-authority problem (`EX-*` catalogue vs
`cohort.exercise.*` knowledge) without inventing a third identity system.

This sprint defines contracts only. It does **not** migrate live consumers,
change persistence, alter Workout Player behaviour, or implement adaptation
planning.

---

## 2. Canonical identity decision

| Rule | Decision |
|------|----------|
| Sole canonical runtime exercise ID | `EX-*` (digits), typed as `ExerciseId` |
| `cohort.exercise.*` | Transitional aliases only (`transitionalAliasIds`) |
| Third ID system | Forbidden |
| Live identity migration | Deferred (not this sprint) |

`ExerciseId.parse` rejects malformed ids and transitional knowledge ids as
canonical.

---

## 3. Domain concepts and responsibilities

| Concept | Responsibility |
|---------|----------------|
| `ExerciseDefinition` | Reusable movement/activity facts |
| Classification vocabulary | Modality, laterality, complexity, impact, dimensions |
| `EquipmentRequirement` | Required / optional / one-of / loading capability |
| `EnvironmentSuitability` | Suitable / unsuitable training environments |
| `ExerciseRelationship` | Typed, directional, versioned links |
| `SubstitutionConstraint` | Reusable facts that *may* preserve intent |
| `ComparisonProtocol` / `ComparisonIdentity` | Explicit like-for-like series keys |
| Knowledge refs | Coaching, media, movement standard, sport standard |
| Lifecycle | draft → published → retired (founder-owned publish) |
| `ExerciseKnowledgeValidator` | Deterministic structured validation |

Package: `lib/domain/exercise_knowledge/`.

---

## 4. Definition / prescription / evidence separation

| Layer | Owns | Does not own |
|-------|------|--------------|
| **Exercise Knowledge Authority** | Identity, classification, equipment, environment, valid dimensions, relationships, substitution constraints, comparison eligibility, standards/coaching/media refs | Sets, reps, load, tempo, rest, scheduling, session position, athlete results |
| **Programme / Plan Package authoring** | Why the movement is in the session, prescription, role, importance, adaptation permissions, session invariants, contextual comparison protocol, whole-session alternatives | Global exercise ontology |
| **Performed evidence** | What was performed, completed values, accepted adaptation provenance, athlete agreement | Exercise definitions |

Phase 3.1B touches only the first layer’s contracts.

---

## 5. Relationship semantics

Directional types:

* progression / regression
* lateral alternative
* equipment alternative
* environment alternative
* related but non-comparable
* directly comparable variant (requires explicit comparison protocol)

Guards: no self-relationships; no duplicate uniqueness keys
(`source>target:type`); published relationships founder-owned at launch.

---

## 6. Substitution versus comparability

* A relationship may preserve training **intent** without sharing a performance series.
* Substitution suitability **never** implies direct comparability.
* Shared family / movement pattern **never** grants comparability.
* `impliesComparabilityByDefault` is always `false`.
* `directly_comparable_variant` is invalid without `comparison_protocol_id`.
* Actual substitution permission remains the intersection of knowledge + programme
  policy + athlete circumstances + invariants + athlete agreement (planner deferred).

---

## 7. Equipment and environment model

* Equipment: required tokens, optional tokens, one-of groups, external-load flag.
* Environment: explicit suitable / unsuitable lists (hotel room ≠ hotel gym, etc.).
* Equipment alone does not define environmental suitability.
* Session-level permission to substitute equipment remains programme context.

---

## 8. Comparison protocol rules

* Series key: `cmp:<EX-*>:<protocolId>:v<version>:<setup>`.
* Same exercise + different setup/protocol → different series.
* Protocols declare valid performance dimensions only — no athlete results.
* HYROX (and other sport) standards attach via `SportStandardRef` / protocol
  `standardRefId`, not a second exercise identity.

---

## 9. Lifecycle and founder ownership

* States: `draft`, `published`, `retired`.
* Draft is never runtime-authoritative.
* Published → draft is forbidden; published → retired allowed.
* Retired remains resolvable for historical evidence.
* Only founder-owned knowledge may be published at launch.
* Canonical identity of a published definition must not silently change (identity
  is the primary key; content changes require versioning in later repository work).

---

## 10. Structured programme-authoring boundary

Programme YAML / Plan Package continue to own contextual coaching decisions.
Exercise Knowledge provides reusable facts programmes will reference later via
`EX-*`. This sprint does not change programme compile, YAML, or materialisation.

---

## 11. Consumers planned for later sprints

* Exercise Knowledge repository / loaders (3.1C)
* Identity alias bridge (`cohort.exercise.*` → `EX-*`)
* Plan Package / Exercise Policy / day-of adaptation
* Previous-performance comparison protocol attachment
* Founder authoring surfaces (same contracts; not a second authority)

---

## 12. Explicitly deferred

* Database migrations / Supabase schema
* Seeding production exercises / media population
* Live consumer migration
* Identity bridge implementation
* Adaptation planner / hotel adaptation / whole-session alternatives
* Completion-evidence additive changes (3.1F)
* Founder or athlete UI
* Phase 3.2+ content production

---

## 13. Examples (hotel adaptation and honest progression)

Fixtures in `test/domain/exercise_knowledge/exercise_knowledge_fixtures.dart`
(contract tests only — not production seeds):

| Example | Intent continuity | Direct comparison |
|---------|-------------------|-------------------|
| Back squat → goblet squat | Equipment alternative may preserve squat pattern | **No** — distinct series |
| Outdoor run → treadmill | Environment alternative | **No** — pace not auto-equivalent |
| SkiErg → banded ski | Hotel continuity / partial stimulus | **No** — cannot share SkiErg series |
| Back squat → hotel BW squat | Emergency environment alternative | **No** |
| HYROX wall balls modified setup | — | Different protocol/setup → different series |
| Directly comparable without protocol | — | **Rejected** by validator |

---

## 14. Migration implications

* `EX-*` is already the platform catalogue identity; contracts align to it.
* `cohort.exercise.*` remains untouched and transitional until a later bridge sprint.
* No live import of `lib/domain/exercise_knowledge` outside the new package
  (enforced by architecture tripwire).

---

## 15. Exact next sprint

**Phase 3.1C — Exercise Knowledge Repository Boundary**

Load/store/publish boundaries for these contracts without migrating live
consumers or changing athlete behaviour.

---

## Implementation map

| Area | Path |
|------|------|
| Domain package | `lib/domain/exercise_knowledge/` |
| Fixtures | `test/domain/exercise_knowledge/exercise_knowledge_fixtures.dart` |
| Contract tests | `test/domain/exercise_knowledge/*_test.dart` |
| Architecture tripwires | `test/architecture/exercise_knowledge_authority_boundaries_test.dart` |
