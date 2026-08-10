# Phase 3.1F — Cohort Field Manual Exercise Seed Verification (v1)

**Status:** COMPLETE — applied and verified
**Recorded:** 2026-08-10
**Target:** Cohort Field Manual (`otnhhdxstdnwccehacku`, `eu-west-1`)
**Baseline:** `codex/b4d21b-rebind-path` at
`9960b7347c6e0d1ad24c6f84dcf0c61f6e0e6d9e`

## 1. Authorised migration

Exactly one unchanged migration was authorised and applied:

- `20260809160000_founder_exercise_library_phase_3_1f_part2.sql`
- SHA-256:
  `69ebd998ae4da92e101e92d49c186f9f22bc96baebc3e07faab17c4255efdd6d`
- effect: catalogue data only; no schema, function, policy, athlete, programme or
  completion mutation

The required row fields are `exercise_id`, `name`, `slug`, `published`,
`category`, `movement_pattern`, `equipment`, `primary_muscles`,
`primary_capability`, `loading_options` and `purpose`. The exact approved values
were:

| ID | Name / slug | Published | Category / pattern | Equipment | Primary muscles | Capability / loading | Purpose contract |
|---|---|---:|---|---|---|---|---|
| `EX-128` | Lat Pulldown / `lat-pulldown` | true | Pull / Vertical Pull | Cable Machine | Latissimus Dorsi, Biceps | Strength / Load, Reps, RPE | Founder-approved Phase 3.1F Part 2 canonical addition. Cable vertical-pull identity; not Pull Up. |
| `EX-129` | Running / `running` | true | Running / Locomotion | Running Shoes | Calves, Quadriceps, Hamstrings, Glutes | Endurance / Distance, Time, Pace | Founder-approved Phase 3.1F Part 2 generic Running identity (F-01 A). Not Easy/Threshold/Sprint intensity; outdoor vs treadmill remain environment/equipment/context, not separate identity. Comparability remains protocol-governed. |
| `EX-130` | Burpee Broad Jump / `burpee-broad-jump` | true | Plyometric / Jump | Bodyweight | Quadriceps, Glutes, Chest, Core | Power / Reps, Distance, Time | Founder-approved Phase 3.1F Part 2 combined Burpee Broad Jump identity. Distinct from Burpee (`EX-009`) and Broad Jump (`EX-024`); do not merge performance histories. |
| `EX-131` | Sled Push / `sled-push` | true | Running / Locomotion | Sled | Quadriceps, Glutes, Calves | Power / Load, Distance, Time | Founder-approved Phase 3.1F Part 2 Sled Push identity. Distinct from Sled Pull. Load, distance and surface remain prescription/context. |
| `EX-132` | Sled Pull / `sled-pull` | true | Running / Locomotion | Sled | Hamstrings, Glutes, Grip, Core | Strength / Load, Distance, Time | Founder-approved Phase 3.1F Part 2 Sled Pull identity. Distinct from Sled Push. Load, distance, rope and surface remain prescription/context. |

The migration checks all eleven fields before treating an existing complete set
as an idempotent no-op. A partial or conflicting set raises an exception. Its
single PostgreSQL `DO` statement and multi-row `INSERT` are atomic, so a raised
failure cannot leave a partial five-row seed.

## 2. Local validation and isolation

Focused local-only validation passed:

- migration scope, identities and fail-closed behaviour: 10 passed;
- founder-approved identity mappings: 16 passed;
- authoritative 127-row catalogue review: 5 passed;
- total: 31 passed, 0 failed, 0 skipped.

The private application workdir contained the 43 ledger-matched migrations plus
only the authorised migration. Its dry run listed exactly that one pending file,
with the reviewed hash. No other migration, seed, fixture, deployment or
migration-history repair was included. The previously retained private logical
backup remains outside Git and was neither disclosed nor committed.

## 3. Hosted preflight and apply

Authoritative target metadata identified Cohort Field Manual in `eu-west-1` as
`ACTIVE_HEALTHY`. Read-only preflight observed:

- migration ledger: 43 entries, maximum `20260803180000`;
- all nine Phase 1.2–1.7 uplift versions: present exactly once;
- `20260809160000` and later versions: absent;
- catalogue: 127 rows;
- `EX-128`–`EX-132`: absent;
- approved name/slug collisions: zero.

The isolated apply executed the authorised migration once and exited
successfully. The CLI emitted a non-fatal post-apply migration-cache warning
because the isolated private workdir did not contain a pg-delta CA cache file.
Independent read-only postflight is the authoritative result.

## 4. Postflight and preservation

Postflight observed:

- migration ledger: 44 entries, maximum `20260809160000`;
- `20260809160000`: present exactly once; later versions: zero;
- all nine earlier uplift versions: still present exactly once;
- catalogue: 132 rows;
- `EX-128`–`EX-132`: each present exactly once;
- all five rows: exact match across all eleven approved fields.

The other 127 catalogue rows retained the preflight count and server-side
digest. Aggregate counts and server-side digests for profiles, programme
assignments, programme versions, historical training-session records and slot
outcomes also matched preflight. No unrelated row, athlete, programme,
completion or protected record changed.

Only Cohort Field Manual was contacted and mutated. Cohort Staging was neither
contacted nor mutated. No production application code changed or deployed.

## 5. Boundary and next decision

This evidence does not authorise or implement
`founder_programme_yaml_import`, another Plan Package consumer, product-UI Gate
2, application deployment or Phase 3.2. Phase 3.1 remains incomplete pending a
separately authorised first consumer.

Next founder decision: authorise the bounded implementation of
`founder_programme_yaml_import` as the first real Plan Package consumer.

```text
PHASE_3_1F_SEED_APPLIED=true
PHASE_3_1F_SEED_VERIFIED=true
PHASE_3_1F_ROWS_PRESENT=true
PHASE_3_1F_CATALOGUE_COUNT=132
FIRST_CONSUMER_IMPLEMENTED=false
PRODUCT_UI_GATE_2_VERIFIED=false
APPLICATION_DEPLOYED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```
