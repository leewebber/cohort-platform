# M9 existing-system audit

**Scope:** Repository at `c50530d`. No Field Manual contact.

## Inventory (minimum)

| Area | Source of truth | Stable ID | Mutable | Immutable when published | Version boundary | Consumers | Missing relationship | Legacy | Production identity |
|------|-----------------|-----------|---------|--------------------------|------------------|-----------|----------------------|--------|---------------------|
| `exercises_v2` | Hosted catalogue + repo seeds EX-073+ | `EX-*` | name, cues, taxonomy text | `exercise_id` | none (no row versions) | Player hydrate, M9.4 | no FK from blocks | EX-001–072 hosted-only | **row** |
| Aliases | Knowledge YAML only | not identity | aliases | n/a | n/a | founder import | not on `exercises_v2` | name/slug import | names are not IDs |
| Equipment/movement | row text + knowledge YAML | tokens | yes | n/a | n/a | templates, filters | not a graph edge | dual stores | mixed |
| Blocks | `session_blocks` / `session_block_exercises` | block UUID | draft only | published protocol | session revision | execution loader | no FK to exercises | `protocol_steps` | **row** |
| Session bank | `performance_protocols` + `content_kind` | lineage UUID | draft | `protocol_id` | M9.1 revision | slots, TMP catalogue | template≠live slot | TMP-* | **row** (`protocol_id`) |
| Programme | `programme_lineages` | lineage UUID/`code` | metadata | code unique | versions | catalogue | — | legacy `programmes` | lineage |
| Programme version | `programme_versions` | version UUID | draft | published row + hash | `version_number` | assignment, import | — | — | **row** + package hash |
| Package hash | Plan Package v1 canonical JSON | SHA-256 | never after publish | hash | schema v1 | import, materialise | no exercise manifest | — | **package** for schedule |
| Compiler | `packages/cohort_plan_package` | schema 1 | n/a | golden hash | schema version | founder import | no EX-* | v1 frozen | package |
| Draft/publish | lifecycle + RPCs | version UUID | draft | published trigger | lifecycle | import/publish/approve | visibility≠lifecycle | — | row |
| Authored progression | `authored_progression` JSONB on slots | slot UUID | draft | published child tables | version | player notes | not a template field | — | row |
| Assignment pin | `programme_assignments.programme_version_id` | assignment UUID | cursor/schedule | pin + hash | enrolment time | Home/Calendar | — | — | **row** |
| Materialisation | `materialised_package_content_hash` | assignment | once | snapshot | Start Programme | prepare | — | — | package snapshot |
| Occurrences | `programme_schedule_occurrences` | occurrence UUID | disposition | version+hash pin | schedule ops | Calendar | — | — | derived |
| Prepared plan | 1.4B package | programmed key | current session only | assigned version | prepare | Workout Player | — | — | assigned content |
| Protocol vs session | `protocol_id` vs `training_sessions.id` | both | execution | protocol published | — | evidence | easy to confuse | — | both rows |
| Seed catalogue | TMP-001–010 Dart+SQL | TMP-* | seed | published templates | — | training library | no EX on some steps | prose steps | row |
| Apollo v2 | YAML schedule + SQL protocols | `APOLLO-W*-*` | no (published) | 84 protocols | lineage version 2 | dogfood | package has no EX-* | — | protocol row + EX-* in blocks |
| HYROX | TMP-006 + marketing stub | none executable | n/a | n/a | n/a | none | no programme | stub | unresolved |
| Catalogue/enrol | eligibility + enrol RPC | version UUID | approval flag | pin | enrolment | athlete catalogue | UI polish later | — | version row |
| Used-by | M9.2/M9.4 derived JOINs | — | n/a | n/a | query time | coach studio | no persisted graph | — | derived |
| Replacement | replace RPC | lineage | catalogue pointer | old version remains | lineage lock | service_role | no athlete migrate | — | version row |
| Ownership | owner_* columns | publisher | draft | published owner | namespace | RLS | external UI absent | — | row |
| Archive | `archived_at` / retired | version | lifecycle | content remains | — | catalogue | visibility vs retire | archived≈retired | row |

## Duplicate concepts (do not consolidate until proven)

- Session template (`TMP-*` / `content_kind`) vs programme session (`protocol_id` in a slot)
- Programme lineage vs programme version
- `protocol_id` vs `training_sessions.id`
- Exercise display name vs `EX-*`
- `session_blocks` vs `training_block_results`
- Plan Package vs materialised assignment hash snapshot

## M9.2/M9.4

Read-only derived slices already exist. M9 Sprint 1 adds a **local canonical graph contract** that those slices must eventually implement, without duplicating a cache of performance evidence.
