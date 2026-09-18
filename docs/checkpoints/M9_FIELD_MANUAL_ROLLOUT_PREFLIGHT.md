# M9 Field Manual rollout preflight

**Recorded:** 2026-09-18
**Status:** Preflight corrected locally. **Paused for founder approval of hosted schema-only apply.**
Hosted migrations, publisher bootstrap, reconstruction, and manifest publication were **not** executed.

```text
M9_FIELD_MANUAL_ROLLOUT_PREFLIGHT_COMPLETE=true
M9_FIELD_MANUAL_PREFLIGHT_CORRECTIONS=true
MIGRATION_TIME_PUBLISHER_SEED=removed
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_REGION=eu-west-1
HOSTED_HEALTH=ACTIVE_HEALTHY
HOSTED_PG=17.6
HOSTED_LEDGER_MAX=20260914121000
M9_MIGRATIONS_HOSTED=absent
ORIGIN_MAIN=8655c9de3ef7d07035cc9ffe1f6c56c6c5bbc43b
BRANCH=chore/m9-field-manual-rollout-preflight
SCHEMA_COMPATIBILITY=compatible
CONFLICTING_PREREQUISITE=false
ASSIGNMENT_PIN_SAFE=true
HOSTED_MUTATIONS=0
NOTHING_PUSHED=true
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
M10_STARTED=false
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
```

Binding: [`../architecture/Content_Relationship_Graph_and_Versioning_v1.md`](../architecture/Content_Relationship_Graph_and_Versioning_v1.md), [`../architecture/M9_Content_Graph_Persistence_v1.md`](../architecture/M9_Content_Graph_Persistence_v1.md), [`../architecture/M9_Publisher_Bootstrap_Runbook_v1.md`](../architecture/M9_Publisher_Bootstrap_Runbook_v1.md), [`../architecture/Phase_1_Migration_Chain_v1.md`](../architecture/Phase_1_Migration_Chain_v1.md), [`../architecture/M9_Legacy_Reconstruction_Runbook_v1.md`](../architecture/M9_Legacy_Reconstruction_Runbook_v1.md).

## Corrections after founder decision

1. **Publisher bootstrap decoupled.** `20260918120000` no longer INSERTs `cohort_global`. Applying `120000`–`120400` creates schema only (zero publisher/manifest/reconstruction rows). Publication returns `unauthorised` / `missing_publisher` until the manual bootstrap is separately authorised.
2. **Graph SELECT no longer treats every coach as a global published-manifest reader.** Access uses assigned athlete, catalogue eligibility, publisher principal, or existing `cohort_programme_version_is_dev_coach_readable` programme ownership.

### Migration file hashes (SHA-256)

Preflight hashes (superseded for any hosted apply):

| File | Preflight SHA-256 |
|------|-------------------|
| `20260918120000_content_graph_core.sql` | `8e18d8207fb36aa9aae888d879b55822fe4b06c1240323954800bc6cf52ecb36` |
| `20260918120100_content_graph_publication.sql` | `4443cae0411c86010b85e5d35326b16b4659bbe823790e9937a76f523a972a0c` |
| `20260918120200_content_graph_read_models.sql` | `95eff642cadcd2c4e1064056eee0ee23254ea045ad1dd060cf8777de156682a7` |
| `20260918120300_content_graph_rls.sql` | `284310bcd59ffa9061d48a357f28f69231bfa6aaa14ea62a318c649e31ee1471` |
| `20260918120400_content_graph_reconstruction.sql` | `9b40fb312a06c020d35b063443022214223cae9df695f4c17a10a84cb6bb6655` |

Corrected hashes (use these):

| File | SHA-256 | Changed? |
|------|---------|----------|
| `supabase/migrations/20260918120000_content_graph_core.sql` | `09d980e63c59c6673cef9bc5667cab3eb0c9c9a6c5d9dd9aacb18c85bf4e6edb` | **yes — supersedes preflight** |
| `supabase/migrations/20260918120100_content_graph_publication.sql` | `db93f774a498366e393874ca89ab31591ae20f674b11e6e165ae90d1e2fd0929` | **yes** (`missing_publisher`) |
| `supabase/migrations/20260918120200_content_graph_read_models.sql` | `a561023a6a62b698c0f131c3ade4d181df91dfcd7f0daf8543651ef6df07229d` | **yes** (read helper, impact/diff) |
| `supabase/migrations/20260918120300_content_graph_rls.sql` | `909e9f19872078eb2136e53c2a571f20d7fcd01edbfd86ce0b324f17da36e53c` | **yes** (scoped SELECT) |
| `supabase/migrations/20260918120400_content_graph_reconstruction.sql` | `9b40fb312a06c020d35b063443022214223cae9df695f4c17a10a84cb6bb6655` | unchanged |

Manual bootstrap (not a migration): `supabase/manual/content_graph_bootstrap_cohort_global.sql`.

Do not treat this document as authority to apply hosted schema, run bootstrap, reconstruct, publish manifests, change catalogue defaults, or repin assignments.

## A. Repository preflight

| Item | Value |
|------|--------|
| Branch | `chore/m9-field-manual-rollout-preflight` |
| HEAD | `8655c9de3ef7d07035cc9ffe1f6c56c6c5bbc43b` |
| Fetched `origin/main` | same SHA; worktree began clean |
| Repo migration-chain maximum | `20260918120400_content_graph_reconstruction.sql` |
| Repo `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` (keys only; unchanged) |
| Founder build | `1.0.0+7` remains `pubspec.yaml`; latest stamp `c50530d`; no newer build-number commit exists |
| Apollo Plan Package SHA-256 | `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83` (hosted Apollo v2 matches) |

### Migration file hashes (SHA-256) — historical preflight table replaced above

### Build 7 production compatibility

Installed founder IPA remains build 7 (`c50530d`). Current `origin/main` still carries `1.0.0+7` but includes later Dart capability keys. Hosted `cohort_athlete_runtime_capabilities` today is **schema_version 1** (`overdue_recovery`, `backfill_results` only). After `20260918120300`, the same RPC becomes **schema_version 2** with additive `content_graph_*` keys. Build 7:

- does not require graph manifests for Home, Calendar, Progress, or workout start
- treats a missing capability RPC as unavailable (`PGRST202` / `42883`)
- ignores unknown JSON keys if it predates the graph fields; current repo client maps absent keys to `false`
- is not broken by empty `content_graph_manifests`

## B. Hosted target

Proven via `supabase projects list` plus linked read-only `db query` / `migration list` / `db push --dry-run` from a disposable workdir (not `supabase/.temp`).

| Field | Value |
|-------|--------|
| Name | Cohort Field Manual |
| Project ref | `otnhhdxstdnwccehacku` |
| Region | `eu-west-1` |
| Health | `ACTIVE_HEALTHY` |
| PostgreSQL | `17.6` (hosted report `17.6.1.155` in prior CLI status) |
| Extensions (relevant) | `uuid-ossp` 1.1, `pgcrypto` 1.3, `pg_stat_statements` 1.11, `supabase_vault` 0.3.1 |
| Ledger | `supabase_migrations.schema_migrations` — **85** versions, **min** `20260713140000`, **max** `20260914121000` |
| M9 five | **all absent** |

`supabase db push --linked --dry-run` (no apply) listed exactly:

1. `20260918120000_content_graph_core.sql`
2. `20260918120100_content_graph_publication.sql`
3. `20260918120200_content_graph_read_models.sql`
4. `20260918120300_content_graph_rls.sql`
5. `20260918120400_content_graph_reconstruction.sql`

Staging project `tsbadngzgvsyfqjupkng` was observed as inactive and was **not** targeted.

## C. Schema compatibility matrix

No conflicting prerequisite. Graph objects are missing as expected.

| Object / assumption | Verdict | Notes |
|---------------------|---------|--------|
| `programme_lineages.id` UUID, `code` TEXT | exact match | 8 lineages |
| `programme_versions.id` UUID; lifecycle `draft\|published\|archived` | exact match | CHECK present |
| `programme_versions.library_scope` / `owner_type` | compatible variation | `cohort_global`/`coach_private`; `global`/`coach` |
| `programme_versions.package_content_hash` TEXT nullable | compatible variation | required for later publication; some versions null |
| `programme_versions.supersedes_version_id` | missing prerequisite (additive) | column added by `120000`; currently absent |
| `programme_assignments.programme_version_id` UUID **NOT NULL** FK `ON DELETE RESTRICT` | exact match | pin already required at rest |
| Existing assignment UPDATE paths | compatible variation | SET cursor/status/hash/revision only; **no** `SET programme_version_id` |
| `cohort_programme_assignment_protect_materialisation` | compatible variation | already blocks pin changes except postgres+GUC; M9 trigger is stricter (no bypass) |
| Catalogue enrolment `enrol_athlete_in_catalogue_programme_version` | exact match | INSERT new pin; old row `reassigned` + `superseded_by` |
| Catalogue eligibility + one-eligible-per-lineage index | exact match | Apollo v2 + Spartan v3 eligible |
| `replace_approved_cohort_global_programme_version` | exact match | does not rewrite assignment pins |
| `performance_protocols.protocol_id` TEXT PK | exact match | lifecycle/content_kind CHECKs present |
| `session_blocks.block_id` UUID; `session_id` TEXT | exact match | |
| `session_block_exercises.exercise_id` TEXT, no FK to `exercises_v2` | exact match | M9 does not add FK |
| `exercises_v2.exercise_id` TEXT PK | exact match | 169 `EX-###`, all published, no duplicates |
| `programme_version_session_slots.protocol_id` TEXT; version via weeks/days | exact match | used-by views already join this way |
| Publisher/ownership on programmes | compatible variation | `owner_type`/`owner_id`/`created_by`/`library_scope`; no `content_publishers` yet |
| Programme immutability triggers | exact match | `cohort_reject_published_programme_content_mutation` on versions + slots |
| Capability RPC | compatible variation | hosted schema_version **1**; `203` replaces with **2** additively |
| Used-by views/functions | missing prerequisite (additive) | installed by `202` |
| RLS helpers `cohort_auth_is_athlete` / `cohort_auth_is_coach` | exact match | `cohort_auth_uid_text` absent; new policies do not require it |
| `publish_content_graph_manifest` and pin/immutability triggers | missing prerequisite (additive) | |
| Migration ledger convention | exact match | timestamp filenames in `schema_migrations` |
| `pgtcrypto` `digest` for `content_graph_sha256_hex` | exact match | `pgcrypto` 1.3 |
| Graph tables/RPCs | missing prerequisite (additive) | expected |
| Hosted-only leftovers | unexpected hosted-only | `COHORT-C` lineage with 0 versions; `BP-001`/`SQ-001` SBE tokens; draft slot `protocol_id=__UNASSIGNED__` on `test1` |

## D. Hosted content inventory (aggregate / identifier-safe)

### Lineages (8)

`APOLLO-BUILD-12-WEEK`, `COHORT-C` (no versions), `COHORT-FOUNDATION-TEST`, `COHORT-FOUNDER`, `COHORT-HYBRID-FOUNDATION-TEST`, `COHORT-T`, `FOUNDER-ACCEPTANCE-PROGRAMME`, `SPARTAN-PHYSIQUE`.

### Programme versions (9)

| Lifecycle | n |
|-----------|---|
| published | 4 |
| draft | 4 |
| archived | 1 |

Library scope: `cohort_global` 5, `coach_private` 4.

Catalogue-eligible (published + approved_for_global + unarchived + cohort_global):

- Apollo v2 `2ba018bd-7dc2-4dfd-8d8e-e35823158920` hash `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`
- Spartan Physique v3 `32986922-47d1-46b0-b391-a7931d73033e` hash `b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e`

### Sessions / blocks / exercises

| Metric | n |
|--------|---|
| `performance_protocols` | 245 (published 105, draft 140) |
| protocols with `programme_version_id` | 15 |
| `session_blocks` | 299 |
| `session_block_exercises` | 1121 (canonical `EX-*` 1119; non-EX 2) |
| unique SBE exercise ids | 102 |
| SBE unresolved vs `exercises_v2` | 2 (`BP-001`, `SQ-001`) |
| `exercises_v2` | 169 canonical `EX-###`; 0 malformed; 0 duplicate ids |
| slots | 113 |
| slots with missing protocol | 1 (`__UNASSIGNED__` on draft `test1` `6d2d2c36-cb40-41ae-adcc-f9dde2aeb580`) |
| blocks without SBE | 36 (Apollo contributes 25) |

### Assignments

| Metric | n |
|--------|---|
| assignments | 1 (`b5fc87e3-ca5b-4f02-a2cb-582a38d55c75`) |
| status | `active` |
| lineage | `APOLLO-BUILD-12-WEEK` |
| pin | `2ba018bd-7dc2-4dfd-8d8e-e35823158920` (exists, published) |
| materialised hash vs version | match (frozen Apollo hash) |
| distinct athletes | 1 |
| occurrences | 84 |
| occurrence pin mismatch | **0** |
| supersession graph rows | none (`supersedes_version_id` absent) |

No private athlete profiles or performance actuals were dumped.

## E. Assignment-pin risk audit

Inspected hosted functions whose bodies mention `UPDATE public.programme_assignments`, plus repository migration SET lists.

| Path | Class | Pin change? |
|------|-------|-------------|
| `enrol_athlete_in_catalogue_programme_version` | 1 initial creation (INSERT) | No UPDATE of pin; replacement creates a new row |
| `start_fixed_programme_from_enrolment` / `materialise_athlete_plan_from_enrolment` | 1 / cursor | No |
| complete / advance / swap / overdue / schedule apply / undo | cursor, status, `schedule_revision` | No |
| `replace_approved_cohort_global_programme_version` | catalogue default, not assignment | No |
| Direct `UPDATE … SET programme_version_id` | none found in current functions | — |
| Historical import repair | unused on Field Manual for this column | No live path |
| Legitimate explicit repin RPC | **does not exist** | — |

**Verdict:** installing `content_graph_prevent_assignment_repin` does **not** block required current enrolment, materialisation, calendar, Train today, overdue recovery, or completion. Enrolment remains INSERT. A future authorised repin RPC is **not** required before schema deployment. No assignment has a missing/invalid pin. No occurrence is materialised from a different version than the pin.

## F. Publisher mapping proposal (do not insert extra rows)

`20260918120000` no longer inserts a publisher. First-party `cohort_global` is created only by the separately authorised bootstrap in `supabase/manual/content_graph_bootstrap_cohort_global.sql` (stable id `00000000-0000-4000-8000-00000000c001`). Schema apply must leave publisher tables empty.

| Content | Stable authority | Mapping |
|---------|------------------|---------|
| First-party Cohort catalogue | `library_scope=cohort_global`, `owner_type=global` | `cohort_global` |
| Apollo lineage `a5ba5ec1-1901-46b7-b198-ec4c338331d6` / version `2ba018bd-…` | lineage code + version UUID + package hash | `cohort_global` |
| Spartan catalogue v3 `32986922-…` / archived v2 | lineage `f5b44f26-…`, version UUIDs + hashes | `cohort_global` |
| Coach-private Founder Block / Spartan v1 / `test1` | `owner_type=coach`, `owner_id` UUID `79853f15-eac4-42eb-acfd-384bf2a87976` | **supplemental ownership evidence**; do not invent a second namespace in this deploy |
| Hybrid foundation draft | `owner_id=dev-coach` (non-UUID token) | **ambiguous** |
| Foundation Test / Founder Acceptance drafts | `created_by=dev-coach`, no package hash | test/dev; not first-party publish candidates |
| `COHORT-C` lineage | UUID `9df020c6-982d-40a6-aea8-41c656c7d8c2`, zero versions | leftover; no graph |
| `BP-001` / `SQ-001` | non-canonical tokens | **invalid** for EX-* graph identity |

No extra publisher rows should be inserted in the schema-deploy task.

## G. Reconstruction dry-run

Hosted reconstruction RPC is absent. Dry-run was reproduced locally from:

- hosted metadata (read-only counts/ids/hashes)
- committed Apollo Plan Package + week SQL binder
- Gate AX `content_graph_record_reconstruction` dry_run=true on disposable local DB

No hosted job row was written. No manifest was published.

| Version | Source hash | Supplemental | Format/compiler | Resolvable | Unresolved / conflict | Publish later? |
|---------|-------------|--------------|-----------------|------------|------------------------|----------------|
| Apollo v2 `2ba018bd-…` | yes, frozen | committed Apollo week SQL; hosted unique `EX-*` via slots = **58** | `content-graph-compiler/v1`, format 1 | class 1 hosted SBE 991 rows / 58 ids; class 2 binder 58 ids | 25 Apollo blocks without SBE (name-only, class 3); no guessed edges | Allowed only in a **later** publication task if unresolved array is explicit |
| Spartan v3 `32986922-…` | yes | hosted SBE 37 unique `EX-*` (class 1); no Apollo SQL | same | 37 EX | name-only remainder | later task; do not publish in schema deploy |
| Spartan archived v2 | yes (`b27e9a9f…`) | hosted SBE | same | reconstructable historically | not catalogue | later, optional |
| Spartan coach v1 `7454ffd4-…` | **missing** | 34 unique EX | — | class 1 partial | cannot satisfy source hash | **reject publication** |
| Founder Block `d584b724-…` | **missing** | 13 unique EX | — | class 1 partial | no package hash | **reject** |
| Drafts without hash | missing | sparse | — | — | missing source | **reject** |
| `test1` `6d2d2c36-…` | missing | `__UNASSIGNED__` slot | — | — | invalid slot | **reject** |

### Apollo qualification

- Plan Package hash **unchanged** on package file and hosted version
- **58** unique `EX-*` in supplemental binder **and** hosted Apollo SBE
- Distinct variants remain distinct (`EX-095` / `EX-137` / `EX-149`, `EX-129`)
- Structured warm-up present (81 Apollo blocks matching warm-up title/type; week SQL included)
- Name-only content remains unresolved (no display-name inference)
- No guessed relationships in binder tests (two identical regenerations)

## H. Migration impact simulation (local disposable)

Local `./supabase/tests/run_local_db_gate.sh`:

1. Hosted-faithful schema-only baseline fixture
2. Full timestamped chain through `20260914121000` then `20260918120000`–`20400`
3. Repeat reset / re-apply (upgrade gate, including re-apply of `203` after Backfill overwrite of capabilities)
4. Gate AX plus C–AW
5. Enrolment still inserts assignments after pin trigger
6. Pin UPDATE raises `content_graph_assignment_pin_immutable`
7. Capability probe remains callable

**Migration-time row writes:** zero publisher, principal, manifest, reconstruction, assignment, programme, occurrence, result, or catalogue rows. Gate AX asserts `schema_only_zero_publishers` before explicit bootstrap.

Hosted `db push --dry-run` (preflight) listed those five files only. The manual bootstrap file is not in `supabase/migrations/`.

## I. RLS simulation

Proven in Gate AX with `anon`, `authenticated` athlete, coach, and service_role-shaped calls on a production-shaped local schema.

| Case | Result |
|------|--------|
| Unauthenticated | denied |
| Assigned athlete reads published assigned / retired-but-pinned manifest | allowed |
| Catalogue-eligible published visibility | allowed (same as programme catalogue SELECT) |
| Athlete unrelated / unpublished | denied |
| Athlete INSERT/UPDATE/DELETE manifests | denied |
| Athlete impact / other-namespace diff | denied (`unauthorised` or unresolved) |
| Publisher principal | own active namespace, including draft graph rows |
| Other publisher private namespace | denied unless separately catalogue-visible |
| Coach | only `cohort_programme_version_is_dev_coach_readable` (own `coach_private`) plus catalogue-consumer path |
| Unrelated coach private graph | denied |
| Inactive publisher membership | cannot use namespace path |
| Forged principal INSERT | denied |
| Trusted `publish_content_graph_manifest` | typed outcomes; `missing_publisher` before bootstrap |
| Build 7 Home/Calendar/Progress/workout | no new table required |

Existing `programme_versions` / assignment RLS was not weakened. Used-by views remain `security_invoker`. Impact is publisher-principal or service_role only. `content_graph_publish` is not granted to generic coaches.

## J. Recovery plan (do not execute)

### Pre-deployment inventory snapshot

See appendix. Capture again immediately before any authorised apply: ledger max, the five file hashes, assignment pin UUID, Apollo/Spartan hashes, table counts.

### Rollback order (dependency-safe)

Only if **no** published manifests exist (true until a later publication task):

1. Drop reconstruction: trigger/functions `content_graph_record_reconstruction`; table `content_graph_reconstruction_jobs`
2. Restore `cohort_athlete_runtime_capabilities` body from `20260913120000` (schema_version 1)
3. Drop RLS policies from `203`; revoke graph GRANTs
4. Drop views/functions from `202`
5. Drop `publish_content_graph_manifest`, `content_graph_publisher_may_operate`, `content_graph_composite_identity`, `content_graph_sha256_hex`, `content_graph_is_service_role`
6. Drop `trg_content_graph_assignment_pin_immutable` + `content_graph_prevent_assignment_repin`
7. Drop `trg_content_graph_manifests_immutable` + `content_graph_prevent_published_mutation`
8. Drop `content_graph_manifests`
9. Drop `programme_versions.supersedes_version_id` and index
10. Drop `content_publisher_principals`, `content_publishers`
11. If Phase 2 bootstrap was applied separately, `DROP FUNCTION content_graph_bootstrap_cohort_global(uuid)` (that function is **not** in the migration chain)

Canonical authored tables (`programme_*`, `performance_protocols`, `session_blocks`, `session_block_exercises`, `exercises_v2`, assignments, occurrences, results) are **not** dropped.

### Ledger

After a successful hosted apply, `schema_migrations` will contain the five versions. Dropping objects while leaving ledger rows is **unsafe** (future reset/repair drift). Prefer: keep objects and forward-repair, **or** founder-authorised `migration repair --status reverted` of those five versions **after** object drop. Never repair unrelated historical versions.

### Manifests / pins

- Rollback of schema **before** publication removes empty graph tables only.
- After a later publication task, published rows are immutable; rollback is DROP of Sprint 2 objects, not in-place rewrite.
- No assignment repin is required for rollback or apply.

### Stop conditions where rollback is unsafe

- Any published `content_graph_manifests` row exists
- Unknown extra publisher principals were added
- Ledger repaired incorrectly
- Need to keep schema_version 2 clients depending on graph keys (none in production build 7 today)

## K. Proposed future authorised sequence (not executed)

### Phase 1 — schema only

1. Re-verify Field Manual ref `otnhhdxstdnwccehacku`, health, ledger max still `20260914121000`
2. Recapture counts/hashes using **corrected** file hashes above
3. Apply `20260918120000`–`20260918120400` individually in order
4. Verify schema/objects after each file
5. Verify `cohort_athlete_runtime_capabilities` schema_version 2 keys; `content_graph_publish` false without a principal
6. Confirm build 7 Home/Calendar/Programmes/Progress/workout
7. Confirm **zero** publisher/manifest/reconstruction/authored/assignment mutations
8. Read-only postflight
9. **Stop**

### Phase 2 — separately authorised publisher bootstrap

1. Review `supabase/manual/content_graph_bootstrap_cohort_global.sql`
2. Install the function, then `SELECT content_graph_bootstrap_cohort_global('<principal-uuid>')` with an explicit principal
3. Verify `created` / retry `already_exists` / conflict isolation
4. **Stop** (no reconstruction, no publication)

### Phase 3 — separately authorised reconstruction/publication

1. Dry-run reconstruction against hosted schema
2. Approve exact programme versions
3. Apply reconstruction
4. Publish manifests
5. No catalogue/default or assignment changes

### Permission boundaries (non-implied)

| Permission | Schema deploy | Bootstrap | Reconstruction/publication |
|------------|---------------|-----------|----------------------------|
| Five migrations | this phase | no | no |
| `cohort_global` row | **forbidden** | this phase | no |
| Reconstruction apply | no | no | this phase |
| Manifest publication | no | no | this phase |
| Catalogue / default-version changes | no | no | **still no** |
| Assignment repin | no | no | **still no** |

## L. Tests and gates

| Check | Result |
|-------|--------|
| `git diff --check` | pass |
| `test/supabase/content_graph_migration_test.dart` | pass |
| `test/supabase/phase1_migration_chain_test.dart` | pass |
| `test/content_graph/*` (app package) | pass |
| Apollo binder twice | pass, pass (58 EX, frozen hash) |
| `packages/cohort_plan_package` `dart test` | pass (25) |
| Enrolment + materialisation tests | pass |
| `test/features/progress/time_eligible_discipline_test.dart` | pass (includes assignment-local day rollover) |
| `./supabase/tests/run_local_db_gate.sh` (fresh + reapply, Gate AX) | **ALL LOCAL DB GATE CHECKS PASSED** |
| `./tool/testing/run_phase2_consolidation_safety_gate.sh` | **PASS** |
| Full `flutter test` | **pass** (`+3021 ~6`) |
| Changed-file `flutter analyze` | **No issues found** (`content_graph_persistence_test.dart`, `content_graph_migration_test.dart`) |
| Full `flutter analyze` | **710 issues found** (existing baseline; includes `server/trusted_plan_package_import` unresolved URIs). **Zero new issues** in files this correction changed. |

## M. Blockers and stop conditions

1. Hosted reconstruction/publication remain **unauthorised** until Phase 3.
2. Publisher bootstrap remains **unauthorised** until Phase 2; schema-only must stay empty of publisher rows.
3. Coach-private / `dev-coach` rows need supplemental ownership evidence before any non-global publisher seed.
4. `BP-001` / `SQ-001` and `__UNASSIGNED__` must stay unresolved/invalid; never guessed.
5. Do not repair the hosted ledger to “match” older timestamps.
6. `origin/main` moved, dirty worktree, or target ≠ Field Manual → stop.
7. Do not apply the superseded preflight hashes of `120000`–`120300`.

No conflicting hosted prerequisite blocks the five additive files.

## Appendix — recovery snapshot (no secrets)

```json
{
  "captured": "2026-09-18",
  "project_ref": "otnhhdxstdnwccehacku",
  "project_name": "Cohort Field Manual",
  "ledger_max": "20260914121000",
  "ledger_count": 85,
  "m9_present": false,
  "counts": {
    "lineages": 8,
    "versions": 9,
    "protocols": 245,
    "session_blocks": 299,
    "session_block_exercises": 1121,
    "exercises_v2": 169,
    "slots": 113,
    "assignments": 1,
    "occurrences": 84,
    "occurrence_pin_mismatch": 0
  },
  "apollo": {
    "lineage_id": "a5ba5ec1-1901-46b7-b198-ec4c338331d6",
    "version_id": "2ba018bd-7dc2-4dfd-8d8e-e35823158920",
    "assignment_id": "b5fc87e3-ca5b-4f02-a2cb-582a38d55c75",
    "package_content_hash": "810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83",
    "hosted_unique_ex": 58,
    "hosted_sbe": 991,
    "slots": 84
  },
  "catalogue_eligible_version_ids": [
    "2ba018bd-7dc2-4dfd-8d8e-e35823158920",
    "32986922-47d1-46b0-b391-a7931d73033e"
  ]
}
```
