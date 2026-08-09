# Phase 3.1F — Canonical Deployment and First-Consumer Plan

**Status:** ACCEPTED by Lee Webber (first-consumer recommendation locked)  
**Recorded:** 2026-08-09  
**Prerequisite (committed):** Phase 3.1F Part 2 `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc`  
**Part 1b:** `a53ba7c789a5ed8a7c716780a0ed6319cb910e07`

```text
ROLLOUT_PLAN_ACCEPTED=true
ROLLOUT_PLAN_COMPLETE=true
FIRST_CONSUMER_RECOMMENDED=founder_programme_yaml_import
FIRST_CONSUMER_AUTHORISED=false
FIRST_CONSUMER_IMPLEMENTED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

Accepted Stage 2 direction (not authorised for implementation in this document):

```text
Founder programme YAML
→ FounderProgrammeExerciseResolver
→ explicit founder-approved transitional mapping
→ immutable SessionBlockExerciseLink.exerciseId (EX-*)
```

Stage 1 (hosted catalogue seed) and Stage 2 (first consumer) remain
**independently authorised**. Stage 2 is **not** authorised by accepting this plan.

---

## Required sequencing

1. Founder-accepted local Part 2 implementation — **done** (`fe92a42`).
2. Independent hosted deployment authorisation.
3. Hosted preflight verification (read-only).
4. Catalogue seed deployment (`EX-128`…`EX-132` only).
5. Hosted post-deployment verification (read-only).
6. Separate first-consumer implementation authorisation.
7. First-consumer code and tests.
8. Manual athlete-flow testing for that consumer only.
9. Wider consumer migration only through later approvals.

Do **not** combine Stages 1 and 2 into one executable sprint.

---

## Stage 1 — Hosted canonical catalogue deployment (plan only)

### Scope

Apply local migration  
`supabase/migrations/20260809160000_founder_exercise_library_phase_3_1f_part2.sql`  
to the founder-authorised hosted project so published catalogue includes
`EX-128`…`EX-132`.

**Not in Stage 1:** mapping-consuming application code; consumer migration;
schema DDL; athlete/programme/completion data.

### Pre-deployment (read-only)

Confirm project identity (linked/configured project name and environment).

Exact read-only checks (illustrative; refine under deployment auth):

```sql
-- Expect contiguous published catalogue through EX-127; none of EX-128..132.
SELECT min(exercise_id) AS min_id, max(exercise_id) AS max_id, count(*) AS n
FROM public.exercises_v2
WHERE published IS TRUE;

SELECT exercise_id, name, slug
FROM public.exercises_v2
WHERE exercise_id IN ('EX-128','EX-129','EX-130','EX-131','EX-132')
ORDER BY exercise_id;
-- Expect 0 rows before deploy.
```

Collision fail-closed if any of `EX-128`…`EX-132` already exist with non-exact
approved fields (migration `RAISE EXCEPTION`).

### Apply

- Environment: only the project named in the future narrow authorisation.
- Mechanism: established migration apply path for that environment.
- Transaction: migration `DO` block is atomic; refuse partial/mismatched state.
- Expected insert: exactly five rows (`EX-128`…`EX-132`) when absent;
  exact-match re-apply is a no-op.

### Post-deployment (read-only)

```sql
SELECT exercise_id, name, slug, published
FROM public.exercises_v2
WHERE exercise_id IN ('EX-128','EX-129','EX-130','EX-131','EX-132')
ORDER BY exercise_id;
-- Expect 5 rows; published = true; names/slugs match Part 2 seed.
```

### Failure / rollback

| Failure | Handling |
|---------|----------|
| Preflight finds existing conflicting rows | Do not apply; founder decision |
| Migration raises on conflict | Transaction aborts; no partial insert |
| Post-check mismatch | Stop; do not proceed to Stage 2; founder rollback decision |

Rollback options (require separate authority): delete only the five inserted rows
if and only if no dependents reference them; otherwise leave rows and halt
consumers. Prefer not to delete if any session/block already references them.

### Audit evidence

Retain: authorisation message, project identity, preflight result, migration
filename/hash, postflight result, operator, timestamp. No credentials in audit
artifacts.

### Explicit Stage 1 exclusion

Mapping-consuming application code is **not** deployed in Stage 1.

---

## Stage 2 — First consumer migration (plan only)

### Candidate comparison (code evidence)

| Candidate | Advantages | Risks | Historical impact | Runtime impact | Recommendation |
|-----------|------------|-------|-------------------|----------------|----------------|
| **Founder Programme YAML import** (`FounderProgrammeExerciseResolver` → `SessionBlockExerciseLink.exerciseId`) | Existing write-once authoring boundary into durable `EX-*`; fail-closed unmatched resolution today; dry-run CLI; matches “resolve once → immutable authored EX-*” | `tool/importer` lacks `cohort_platform` dep today; must not keep name/slug as a second identity authority | New imports only; no completion rewrite | Only newly imported programmes | **Recommend** |
| Plan Package import/compiler | Strong fail-closed compile/import | Schema v1 has **no** exercise ids; would invent surface | None | None if compile-only | Later gate; not first |
| Session template seed/catalogue | Already stores `EX-*` | No transitional input; bridge would be artificial | Seed-only | Library only | Not a bridge consumer |
| Runtime programmed-session resolution | Broad coverage | Runtime inference; large blast radius | Can skew series | Direct athlete path | Reject |
| Completion-evidence construction | — | Rewrites/infers identity after the fact | High | Completion submit | Reject |

### Recommended first consumer

**Identifier:** `founder_programme_yaml_import`  
**Primary APIs:**  
`tool/importer/lib/features/founder_programme_import/founder_programme_prescription_mapper.dart`  
(`FounderProgrammeExerciseResolver.resolveExerciseId` / validation)  
`founder_programme_import_validator.dart`  
`founder_programme_import_service.dart` (writes `SessionBlockExerciseLink.exerciseId`)

### Why safer than alternatives

- Smallest real surface that already persists canonical `EX-*` into authored session
  blocks.
- Fail-closed validation already exists; extend with explicit bridge resolution.
- Avoids Workout Player / runtime / completion inference.
- Plan Package cannot consume the bridge until it grows an exercise identity field.
- Historical evidence untouched; only future imports change.

### Implementation sketch (not authorised yet)

1. Accept optional authored transitional id `cohort.exercise.*` where legacy YAML
   requires it (or resolve only when transitional form is present).
2. Resolve **once** via `TransitionalExerciseIdBridge` loaded with
   `FounderApprovedIdentityMappingsPhase31F.allMappings`.
3. Persist/compile the resulting `EX-*` into `SessionBlockExerciseLink.exerciseId`.
4. Reject unknown, ambiguous, retired, or malformed mappings.
5. Do **not** use fuzzy name match, graph traversal, or substitution edges for identity.
6. Do **not** rewrite historical evidence or existing session blocks.
7. Do **not** make Workout Player responsible for identity inference.
8. Preserve comparison-protocol authority (mapping ≠ comparability).

### Likely files / contracts

| Area | Paths |
|------|-------|
| Resolver | `founder_programme_prescription_mapper.dart` |
| Validator / service | `founder_programme_import_validator.dart`, `founder_programme_import_service.dart` |
| YAML models/schema | `founder_programme_import_models.dart`, `*_schema.dart`, `*_parser.dart` |
| Dependency | `tool/importer/pubspec.yaml` → path/shared access to bridge + seed |
| Seed (read-only) | `lib/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart` |

**Input:** YAML exercise reference (slug/name today; optional transitional id).  
**Output:** immutable `EX-*` on `SessionBlockExerciseLink`.  
**Canonical becomes immutable:** at import write into session block links.  
**Lifecycle:** published mappings only for operational import; retired fail closed
for new imports.

### Failure behaviour

| Condition | Behaviour |
|-----------|-----------|
| Unknown transitional id | Reject import (fail closed) |
| Conflict / multiple targets | Reject import |
| Resolved `EX-*` missing from catalogue | Reject import (Stage 1 prerequisite for EX-128…132) |
| Heuristic name-only identity | Forbidden |

### Legacy / history / exclusions

- Existing plans and completions: **unchanged**.
- Downstream excluded from first consumer: Workout Player, ProgrammedSessionResolver,
  Progress, adaptation day-of, completion evidence, Plan Package (until it grows
  exercise ids), athlete catalogue browsing.

### Tests (future Stage 2)

- Unit: resolver maps each of 21 transitional ids exactly once; unknowns fail.
- Integration: dry-run import with transitional id produces `EX-*` links.
- Architecture: no Workout Player / completion import of bridge.
- Manual: founder dry-run + one controlled import on staging after Stage 1.

### Schema / hosted prerequisites

| Question | Answer |
|----------|--------|
| DB schema change for bridge? | **No** |
| Hosted Stage 1 prerequisite? | **Yes** before importing programmes that need `EX-128`…`EX-132`; Batch A targets already on hosted catalogue may resolve earlier but Stage sequencing still prefers Stage 1 first |
| Rollback boundary | Disable transitional acceptance in importer; leave persisted `EX-*` links intact |

### Smallest future founder authorisations required

1. **Stage 1 auth:** narrowly scoped hosted apply of
   `20260809160000_founder_exercise_library_phase_3_1f_part2.sql` to a named
   environment, with pre/post read-only verification — no app deploy.
2. **Stage 2 auth:** implement `founder_programme_yaml_import` bridge consumption
   only — no other consumers, no evidence rewrite, no Phase 3.2.

---

## Confirmations

- No hosted environment contacted while preparing this plan.
- No hosted mutation performed.
- No consumer migrated.
- Historical evidence not rewritten.
- Comparison protocol remains sole positive comparability authority.
- Planning did not modify production application behaviour.
