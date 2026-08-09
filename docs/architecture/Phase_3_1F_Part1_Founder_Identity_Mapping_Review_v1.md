# Phase 3.1F Part 1 / 1b — Founder Canonical Catalogue and Identity-Mapping Review

**Status:** Part 1 **committed**; Part 1b **review packet complete** (advisory only; **not committed**)  
**Recorded:** 2026-08-09  
**Part 1 commit:** `216a9be2d06dd5be11862c3a8fda0062dde12e0e`  
**Part 1b baseline (post–Part 1):** `216a9be2d06dd5be11862c3a8fda0062dde12e0e`

```text
PHASE_3_1F_PART_1_ACCEPTED=true
PHASE_3_1F_PART_1_COMMITTED=true
PHASE_3_1F_PART_1_COMMIT=216a9be2d06dd5be11862c3a8fda0062dde12e0e
READ_ONLY_HOSTED_CATALOGUE_EXPORT_AUTHORISED=true
HOSTED_TABLE_READ=public.exercises_v2
HOSTED_MUTATION_PERFORMED=false
AUTHORITATIVE_CANONICAL_CATALOGUE_AVAILABLE=true
AUTHORITATIVE_CANONICAL_CATALOGUE_COUNT=127
TRANSITIONAL_EXERCISE_COUNT=21
FOUNDER_MAPPING_MATRIX_COMPLETE=true
PROPOSED_MAPPING_COUNT=14
AMBIGUOUS_MAPPING_COUNT=2
MISSING_CANONICAL_COUNT=5
SPLIT_REQUIRED_COUNT=0
INTENTIONALLY_UNMAPPED_COUNT=0
INSUFFICIENT_EVIDENCE_COUNT=0
PRODUCTION_MAPPINGS_IMPLEMENTED=false
CANONICAL_EXERCISES_CREATED=false
HEURISTIC_IDENTITY_MATCHING_USED=false
MAPPING_IMPLIES_SUBSTITUTION=false
MAPPING_IMPLIES_COMPARABILITY=false
HISTORICAL_EVIDENCE_REWRITTEN=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
PHASE_3_1F_COMPLETE=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

**Authority note:** This matrix is **advisory**. Silence is not approval. Part 2 must not
begin until Lee explicitly approves (or rejects/amends) the decisions below.

---

## 1. Purpose and scope

Complete evidence gathering for mapping 21 transitional `cohort.exercise.*`
knowledge identities → canonical `EX-*`. Part 1b adds a founder-authorised
read-only hosted catalogue export and a full decision matrix.

Out of scope (unchanged): implementing mappings; creating exercises; mutating
hosted data; migrating consumers; rewriting history; granting substitution or
comparability.

---

## 2. Hosted-access authorisation and exact scope

Lee Webber explicitly authorised one narrowly scoped **read-only** retrieval from
the configured hosted Supabase project for `public.exercises_v2` published
catalogue export and founder mapping review.

| Allowed | Used |
|---------|------|
| SELECT published catalogue from `public.exercises_v2` | Yes |
| Store review-only local artifact | Yes (gitignored raw JSON + committed meta) |
| Compare with 21 transitional definitions | Yes |
| Prepare advisory matrix | Yes |

| Forbidden | Performed |
|-----------|-----------|
| INSERT/UPDATE/DELETE/UPSERT/RPC/DDL | **No** |
| Other tables / athlete / completion / programme / PII | **No** |
| Mapping implementation / exercise creation | **No** |
| Part 2 | **No** |

**Environment contacted:** linked CLI project **Cohort Field Manual** (`eu-west-1`),
via `supabase db query --linked` (SELECT-only). No credentials printed or stored
in artifacts.

---

## 3. Query validation

Documented query (Part 1 §4), SHA-256 prefix `cdf8558e6e5b11f1`:

```sql
SELECT
  exercise_id,
  name,
  slug,
  published,
  category,
  movement_pattern,
  movement_plane,
  exercise_type,
  equipment,
  equipment_category,
  environment,
  technical_complexity,
  primary_muscles,
  secondary_muscle_groups,
  primary_capability,
  unilateral,
  loading_options,
  purpose,
  setup,
  execution,
  coaching_cues,
  regression,
  progression,
  related_protocols,
  notes_internal
FROM public.exercises_v2
WHERE published IS TRUE
ORDER BY exercise_id;
```

| Check | Result |
|-------|--------|
| SELECT-only | Pass |
| Single table `public.exercises_v2` | Pass |
| No JOIN / RPC / mutation / DDL | Pass |
| No athlete/programme/completion/payment tables | Pass |
| Deterministic `ORDER BY exercise_id` | Pass |
| Explicit `published IS TRUE` scope | Pass |
| Projection matches hosted-faithful schema columns | Pass |

**Schema fields absent** (not invented; documented gap): aliases, explicit version,
replacement/supersession metadata, dedicated comparison-protocol identity column.
Lifecycle available via `published`. A second SELECT-only aggregate on the **same
table** counted publication state (`127` published; `0` unpublished).

---

## 4. Export provenance

| Field | Value |
|-------|-------|
| Execution | ~11.9 s (main export) |
| Table | `public.exercises_v2` |
| Query hash (16) | `cdf8558e6e5b11f1` |
| Returned rows | **127** |
| ID range | `EX-001` … `EX-127` (contiguous; **0** gaps) |
| Malformed IDs | 0 |
| Duplicate IDs | 0 |
| `EX-9xxx` fixtures | 0 |
| Publication (all rows in table) | 127 published; 0 unpublished |
| Raw artifact | `docs/architecture/reviews/exercises_v2_published_export_phase_3_1f_part1b.json` (**gitignored**, REVIEW_ONLY) |
| Meta artifact | `docs/architecture/reviews/exercises_v2_published_export_phase_3_1f_part1b.meta.json` |

Authorisation for hosted access **ends** after this successful export.

---

## 5. Source-authority classification

| Source | Classification | Sufficient? |
|--------|----------------|-------------|
| Hosted `public.exercises_v2` published export (Part 1b) | **Authoritative production catalogue (published scope)** | **Yes** |
| Wave 1 seed migration (55 rows `EX-073`–`EX-127`) | Incomplete local expansion | Superseded for review by export |
| `EX-900x` test fixtures | Fixture-only | Forbidden as production targets |
| Transitional YAML `cohort.exercise.*` | Transitional knowledge only | Non-authoritative for `EX-*` |

**Export classification:** `AUTHORITATIVE_COMPLETE`  
(published catalogue is contiguous, duplicate-free, fixture-free, and materially
more complete than the 55-row Wave 1 seed).

---

## 6. Canonical catalogue validation

- Identities: all `EX-\d+`
- Completeness vs Wave 1: 127 > 55; includes pre-Wave-1 ids `EX-001`–`EX-072`
- Deterministic identity: primary key `exercise_id`; no version column (single current row per id)
- Lifecycle: `published=true` for all 127; no unpublished/superseded rows in table
- Fail-closed: no duplicate current ids; no conflicting published versions observed
- Test fixtures excluded from export
- Names alone not used as identity proof in the matrix below

---

## 7. Transitional inventory (revalidated — 21)

Source: `knowledge/reference/exercises_reference.yaml` (`ontology_version` 1.3.0).

| Check | Result |
|-------|--------|
| Count | **21** (unchanged since Part 1 / 3.1D) |
| `platform_exercise_id` authored | **0** |
| Operational bridge mappings added | **No** |
| Transitional IDs authoritative for catalogue | **No** |

---

## 8. Mapping-assessment method

1. Locate candidates using equipment, movement pattern/category, environment, and
   authored purpose — names/aliases may **locate** only.
2. Reject intensity labels, nearby variants, substitution adjacency, and graph edges
   as identity proof.
3. Assign exactly one classification per transitional id.
4. Record that every proposed mapping grants **neither** substitution nor
   comparability.
5. Do **not** emit executable bridge fixtures from this review.

---

## 9. Founder decision matrix (21 rows)

| # | Transitional ID | Transitional name | Candidate EX-* | Canonical name | Classification | Material match | Material conflict | Founder decision | Proposed next action |
|---|-----------------|-------------------|----------------|----------------|----------------|----------------|-------------------|------------------|----------------------|
| 1 | `cohort.exercise.back_squat` | Back squat | `EX-073` | Back Squat | `PROPOSED_DIRECT_MAPPING` | Barbell + full-gym/rack; squat pattern; bilateral strength | None material | Batch A | Publish DRAFT→founder-approved mapping after approval |
| 2 | `cohort.exercise.front_squat` | Front squat | `EX-074` | Front Squat | `PROPOSED_DIRECT_MAPPING` | Barbell + full gym; squat pattern | None material | Batch A | Same |
| 3 | `cohort.exercise.goblet_squat` | Goblet squat | `EX-030` | Goblet Squat | `PROPOSED_DIRECT_MAPPING` | KB/DB equipment; squat; home/hotel-capable vs catalogue KB/DB | None material | Batch A | Same |
| 4 | `cohort.exercise.romanian_deadlift` | Romanian deadlift | `EX-078` | Romanian Deadlift | `PROPOSED_DIRECT_MAPPING` | Required barbell + hinge; `EX-040` is separate DB RDL | Optional DB/KB in YAML are equipment options, not alternate identity | Batch A | Map to barbell `EX-078` only |
| 5 | `cohort.exercise.walking_lunge` | Walking lunge | `EX-025` | Walking Lunge | `PROPOSED_DIRECT_MAPPING` | Lunge pattern; bodyweight foundation; optional load | Lateral lunge `EX-098` is different | Batch A | Same |
| 6 | `cohort.exercise.pull_up` | Pull-up | `EX-053` | Pull Up | `PROPOSED_DIRECT_MAPPING` | Pull-up bar; vertical pull; strict/bodyweight aliases | Weighted `EX-095` / chin `EX-096` are different identities | Batch A | Map to `EX-053` only |
| 7 | `cohort.exercise.lat_pulldown` | Lat pulldown | — | — | `CANONICAL_EXERCISE_MISSING` | Cable vertical-pull knowledge exists | No cable lat-pulldown row in catalogue | Create new EX | Author new canonical after approval; do not map to pull-up |
| 8 | `cohort.exercise.bench_press` | Bench press | `EX-083` | Bench Press | `PROPOSED_DIRECT_MAPPING` | Barbell + bench; horizontal push | Floor press `EX-046` different | Batch A | Same |
| 9 | `cohort.exercise.strict_press` | Strict press | `EX-088` | Strict Press | `PROPOSED_DIRECT_MAPPING` | Required barbell; vertical push | DB strict press `EX-037` separate | Batch A | Map to barbell `EX-088` |
| 10 | `cohort.exercise.push_up` | Push-up | `EX-012` | Push Up | `PROPOSED_DIRECT_MAPPING` | Bodyweight horizontal push | Weighted/ring/HSPU variants are different EX rows | Batch A | Map to `EX-012` only |
| 11 | `cohort.exercise.running` | Running | — | — | `CANONICAL_EXERCISE_MISSING` | YAML: outdoor/track/trail locomotion; bodyweight | Catalogue has intensity/surface runs (`EX-001`…`EX-007`) but **no** generic Running; treadmill absent | F-01 | Do **not** map to Easy/Threshold/etc.; decide F-01 |
| 12 | `cohort.exercise.rowing` | Rowing (erg) | `EX-049` | Row Erg | `PROPOSED_DIRECT_MAPPING` | Required rower ↔ Row Erg equipment; cyclical conditioning | Brand/standard not separately modeled | Batch A | Map to `EX-049`; protocol owns race standards |
| 13 | `cohort.exercise.ski_erg` | SkiErg | `EX-050` | Ski Erg | `FOUNDER_CONFIRMATION_REQUIRED` | Required ski_erg ↔ Ski Erg equipment | HYROX/device/protocol vs identity; banded ski alternatives must stay distinct | F-02 | Confirm identity=`EX-050` with protocol boundary |
| 14 | `cohort.exercise.burpee_broad_jump` | Burpee broad jump | — | — | `CANONICAL_EXERCISE_MISSING` | Compound jump+locomotion knowledge | Catalogue has separate `EX-009` Burpee and `EX-024` Broad Jump only | Create BBJ or split | Prefer new combined canonical; do not merge histories of 009/024 |
| 15 | `cohort.exercise.sled_push` | Sled push | — | — | `CANONICAL_EXERCISE_MISSING` | Sled + locomotion push knowledge | No sled rows in catalogue | Create new EX | Author sled push canonical |
| 16 | `cohort.exercise.sled_pull` | Sled pull | — | — | `CANONICAL_EXERCISE_MISSING` | Sled + locomotion pull knowledge | No sled rows; distinct from sled push | Create new EX | Author sled pull canonical (separate from push) |
| 17 | `cohort.exercise.farmer_carry` | Farmer carry | `EX-101` | Farmer Carry | `PROPOSED_DIRECT_MAPPING` | Carry pattern; DB/KB/handles | Farmer March `EX-041` is different | Batch A | Map to `EX-101` only |
| 18 | `cohort.exercise.wall_ball` | Wall ball shot | `EX-052` | Wall Ball | `FOUNDER_CONFIRMATION_REQUIRED` | Wall-ball equipment; squat/throw capacity; catalogue purpose cites hybrid/HYROX | Load, target height, sex/category, HYROX standard vs identity unresolved in ontology | F-03 | Confirm one `EX-052` + protocol/prescription, or split |
| 19 | `cohort.exercise.plank` | Plank | `EX-021` | Plank | `PROPOSED_DIRECT_MAPPING` | Bodyweight trunk stiffness; side/Copenhagen are separate EX | Pattern label Anti-Rotation vs YAML core — naming only | Batch A | Map to `EX-021` |
| 20 | `cohort.exercise.dead_bug` | Dead bug | `EX-022` | Dead Bug | `PROPOSED_DIRECT_MAPPING` | Bodyweight core control | None material | Batch A | Same |
| 21 | `cohort.exercise.box_jump` | Box jump | `EX-059` | Box Jump | `PROPOSED_DIRECT_MAPPING` | Box + jump/power | Box step-over `EX-058` different | Batch A | Map to `EX-059` |

**Non-authority (every row):** mapping ≠ substitution permission; mapping ≠ comparability.

**Evidence completeness:** Batch A rows = complete for identity (equipment + pattern +
catalogue purpose alignment). F-01/F-02/F-03 and missing-EX rows = partial pending
founder ontology/product choices.

**Historical handling:** No rewrite of completions. Unmapped transitional evidence stays
quarantined via existing bridge rules until approved mappings exist. Supersession N/A
(no version column; single published row per id).

**Multiple-to-one:** None proposed. Nearby variants deliberately excluded.

---

## 10. Classification summary

| Classification | Count | IDs |
|----------------|------:|-----|
| `PROPOSED_DIRECT_MAPPING` | 14 | #1–6, #8–10, #12, #17, #19–21 |
| `FOUNDER_CONFIRMATION_REQUIRED` | 2 | #13 ski_erg, #18 wall_ball |
| `CANONICAL_EXERCISE_MISSING` | 5 | #7 lat_pulldown, #11 running, #14 burpee_broad_jump, #15 sled_push, #16 sled_pull |
| `TRANSITIONAL_DEFINITION_REQUIRES_SPLIT` | 0 | — |
| `INTENTIONALLY_UNMAPPED` | 0 | — |
| `INSUFFICIENT_AUTHORITATIVE_EVIDENCE` | 0 | — |

---

## 11. Decision F-01 — Running

Transitional facts: label Running; environments **outdoors / track / trail**;
equipment bodyweight; aerobic-base intent. **No treadmill** in authored environments.

Catalogue running-family rows are intensity or surface specific:
`EX-001` Easy Run, `EX-002` Threshold Run, `EX-003` Sprint, `EX-004` Hill Sprint,
`EX-005` Strides, `EX-006` Trail Run, `EX-007` Stair Run. **No** generic Running;
**no** treadmill row.

| Option | Meaning | Consequence |
|--------|---------|-------------|
| A | Create new canonical generic outdoor/track Running | New `EX-*`; then map transitional → that id |
| B | Split transitional knowledge into outdoor vs treadmill (and possibly intensity) before mapping | Multiple knowledge ids + possibly multiple new EX rows |
| C | Map to an existing intensity row (e.g. Easy Run) | **Not recommended** — collapses intensity into identity |
| D | Leave intentionally unmapped for now | Knowledge stays quarantined |

**Recommendation (evidence-supported):** Do **not** choose C. Prefer A or B after Lee
decides whether treadmill must be a separate identity (catalogue currently lacks it).

---

## 12. Decision F-02 — SkiErg

Candidate: `EX-050` Ski Erg (equipment Ski Erg).

Separate layers:

| Layer | Treatment |
|-------|-----------|
| Canonical identity | Likely `EX-050` if approved |
| Device/standard | Not a separate EX column today; keep in standard/protocol notes |
| Prescription/scoring | Distance/calories/time — prescription, not identity |
| Ski-pattern alternatives (e.g. banded) | **Different** canonical exercise if/when authored |
| Comparison protocol | Sole positive comparability authority |

Confirm: SkiErg knowledge mapping must **not** make banded ski-pattern work the same
exercise or directly comparable.

---

## 13. Decision F-03 — HYROX wall balls

Candidate: `EX-052` Wall Ball. Catalogue purpose: “Major hybrid/HYROX capacity
movement.” Transitional YAML does not encode load, target height, or sex/category.

| Layer | Ontology question |
|-------|-------------------|
| Movement identity | One `EX-052` vs multiple EX by standard |
| HYROX movement standard | Identity vs comparison protocol |
| Ball load / target height / sex category | Prescription parameters vs identity |
| Scoring | Protocol/prescription |

**Options:** (1) One canonical `EX-052`; HYROX rules in protocol/prescription —
**recommended if** Cohort treats HYROX as standard/protocol. (2) Separate HYROX wall-ball
canonical — only if founder wants distinct performance identity from general wall ball.

Do not decide silently in Part 2 without F-03 answer.

---

## 14. Missing canonical definitions (do not create in Part 1b)

1. Lat pulldown (cable vertical pull) — for `cohort.exercise.lat_pulldown`
2. Generic outdoor/track Running — if F-01 chooses A (and treadmill if F-01 chooses B)
3. Burpee broad jump (combined) — for `cohort.exercise.burpee_broad_jump`
4. Sled push — for `cohort.exercise.sled_push`
5. Sled pull — for `cohort.exercise.sled_pull` (separate from push)

---

## 15. Historical-resolution considerations

- Existing completions keyed by transitional or historical ids must **not** be rewritten.
- Bridge resolution remains fail-closed for unmapped ids.
- Approving a mapping does not merge performance series across related EX rows
  (e.g. Push Up vs Weighted Push Up; Burpee vs Broad Jump vs future BBJ).
- No supersession metadata in schema; treat each `EX-*` as current published identity.

---

## 16. Confirmations

- Mapping does **not** imply substitution permission.
- Mapping does **not** imply comparability (comparison protocol remains sole positive authority).
- No mappings implemented or published in Part 1b.
- No canonical exercises created.
- No heuristic/fuzzy identity matching used as proof.
- No historical evidence rewritten.
- No live consumer migrated.
- Schema and product behaviour unchanged.
- Hosted access was read-only; only `public.exercises_v2` was read.

---

## 17. Proposed Part 2 sequence (after founder answers)

1. Apply Batch A approvals as founder-authored identity mappings (non-operational until publication service rules satisfied).
2. Apply F-02 / F-03 outcomes (ski / wall ball).
3. Author missing canonical exercises only for founder-approved creates (lat pulldown, sleds, BBJ, running per F-01) — separate curation workflow; not silent.
4. Publish approved mappings via existing identity-mapping publication boundary.
5. Keep consumers unmigrated until a later authorised sprint.
6. Re-run safety gate and architecture tripwires.

---

## 18. Numbered founder decisions (compact reply format)

Lee can answer like:

1. **Approve Batch A (direct mappings 1–6, 8–10, 12, 17, 19–21)** — fourteen rows → listed `EX-*`.
2. **F-01 Running:** A create generic outdoor Running / B split outdoor+treadmill / C map to intensity row (not recommended) / D leave unmapped.
3. **F-02 SkiErg:** Confirm map `cohort.exercise.ski_erg` → `EX-050` with protocol/device boundary; banded ski remains distinct — Yes/No/Amend.
4. **F-03 Wall ball:** One `EX-052` with HYROX in protocol/prescription **or** split HYROX vs general — choose.
5. **Create canonical exercises:** lat pulldown; sled push; sled pull; burpee broad jump; (running per F-01) — Approve list / Amend / Defer.
6. **Reject or amend** any Batch A row by number.

---

## 19. Manual-testing classification

```text
MANUAL_TESTING_APPLICABILITY=DEFERRED_TO_FIRST_EXECUTABLE_CONSUMER_INTEGRATION
MANUAL_TEST_PLAN=documented
APP_LAUNCHED_IN_CHROME=false
MANUAL_TESTS_COMPLETED=false
DEFERRED_TEST_TRIGGER=First executable consumer integration of founder-approved mappings
```

---

## 20. Remaining blockers

- Founder answers to decisions 1–6 above.
- Part 2 not authorised until those answers exist.
- Raw export remains local/gitignored; regenerate via same SELECT if needed under new authority.
