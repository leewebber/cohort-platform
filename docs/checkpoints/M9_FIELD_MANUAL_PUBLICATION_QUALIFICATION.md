# M9 Field Manual publication qualification (Phase 3A)

**Recorded:** 2026-09-19
**Status:** Read-only hosted qualification complete. Candidate manifests generated locally.
**Paused for founder approval of Phase 3B writes.** Hosted reconstruction jobs and
manifest publication were **not** executed.

```text
M9_FIELD_MANUAL_PUBLICATION_QUALIFICATION_COMPLETE=true
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_REGION=eu-west-1
HOSTED_HEALTH=ACTIVE_HEALTHY
HOSTED_PG=17.6
HOSTED_LEDGER_COUNT=90
HOSTED_LEDGER_MAX=20260918120400
CONTENT_PUBLISHERS=1
CONTENT_PUBLISHER_PRINCIPALS=1
CONTENT_GRAPH_MANIFESTS=0
CONTENT_GRAPH_RECONSTRUCTION_JOBS=0
BOOTSTRAP_HELPER_PRESENT=false
ORIGIN_MAIN=5953525d299a763447747bb77e07d8e56b7552a3
BRANCH=chore/m9-field-manual-publication-qualification
HOSTED_MUTATIONS=0
NOTHING_PUSHED=true
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
CANDIDATES_COMMITTED=false
M10_STARTED=false
PHASE_3B_AUTHORISED=false
```

Binding: [`../architecture/M9_Manifest_Authority_and_Binding_v1.md`](../architecture/M9_Manifest_Authority_and_Binding_v1.md),
[`../architecture/M9_Content_Graph_Persistence_v1.md`](../architecture/M9_Content_Graph_Persistence_v1.md),
[`../architecture/M9_Legacy_Reconstruction_Runbook_v1.md`](../architecture/M9_Legacy_Reconstruction_Runbook_v1.md),
[`../architecture/M9_Publisher_Bootstrap_Runbook_v1.md`](../architecture/M9_Publisher_Bootstrap_Runbook_v1.md),
[`./M9_FIELD_MANUAL_ROLLOUT_PREFLIGHT.md`](./M9_FIELD_MANUAL_ROLLOUT_PREFLIGHT.md).

Restrictive local checkpoint (not in git):
`AgentStores/.../m9-field-manual-publication-qualification-checkpoint`.
It holds hosted counts/hashes, identifier-safe inventory, generation summary,
and candidate JSON. Candidates are **not** committed until a later task decides
repository ownership.

## A. Repository and target preflight

| Check | Result |
|-------|--------|
| Branch | `chore/m9-field-manual-publication-qualification` created from `5953525` |
| HEAD | `5953525d299a763447747bb77e07d8e56b7552a3` |
| Worktree at start | clean |
| Fetched `origin/main` | `5953525d299a763447747bb77e07d8e56b7552a3` (unchanged) |
| Repo `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` (untouched) |
| Target | Cohort Field Manual `otnhhdxstdnwccehacku` eu-west-1 `ACTIVE_HEALTHY` |
| PostgreSQL | `17.6` / `17.6.1.155` |
| Ledger | **90 / 20260918120400** |
| Graph rows | publishers **1**, principals **1**, manifests **0**, jobs **0** |
| Publisher | `00000000-0000-4000-8000-00000000c001` `cohort_global` Cohort first-party active |
| Owner principal | `79853f15-eac4-42eb-acfd-384bf2a87976` role `owner` |
| Bootstrap helper | **absent** |
| Assignment pin | `b5fc87e3-ca5b-4f02-a2cb-582a38d55c75` → `2ba018bd-7dc2-4dfd-8d8e-e35823158920` active |

No stop condition fired.

## B. Secure read-only checkpoint

Local 0700 store includes target identity, ledger, graph counts, publisher/principal
ids, programme lineage/version ids, package hashes, structural counts/hashes,
assignment pins and aggregate lifecycle counts, catalogue/default identities,
source/supplemental input hashes, candidate-generation tool file hashes, and
query timestamps. No complete athlete profiles, auth payloads, credentials, or
performance actuals were stored. One inventory `created_by` email-shaped token
was redacted in the checkpoint copy.

## C. Zero-write proof (pre-content snapshot)

Recorded **before** inventory dumps. Hosted
`content_graph_record_reconstruction` was **not** called: even `dry_run=true`
INSERTs a job row. Reconstruction was reproduced only by
`ContentGraphReconstructionService` locally. Hosted
`publish_content_graph_manifest` was **not** called with any candidate.

See Section O for the matching post snapshot.

## D. Programme-version classification

Classes: **1** fully eligible · **2** approved supplemental · **3** reconstructable,
not publishable now · **4** unresolved · **5** invalid/conflicting.

| Lineage / version | State | Publisher evidence | Package hash | Supp. source | Sessions | Blocks | Places | Unique EX-* | Unresolved rel. | Assignments a/p/c | Catalogue / default | Class | Eligibility |
|-------------------|-------|--------------------|--------------|--------------|----------|--------|--------|-------------|-------------------|-------------------|---------------------|-------|-------------|
| `APOLLO-BUILD-12-WEEK` `a5ba5ec1-…` / `2ba018bd-…` v2 | published | `library_scope=cohort_global` + `owner_type=global` → `cohort_global` | `81033429…dd0b83` frozen | committed Apollo week SQL `apollo-sql-relationships/v1` | 84 | 224 hosted / binder graph | 84 | **58** | 25 hosted name-only blocks; 131 explicit SQL `name_only_block:*` | 1/0/0 operational | catalogue-eligible; not a graph default | **2** | **Publishable** with `require_full_resolution=false` and explicit unresolved array |
| `SPARTAN-PHYSIQUE` `f5b44f26-…` / `32986922-…` v3 | published | same first-party evidence | `b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e` | hosted authored SBE (`canonical-relationship-source/v1`); **not** Apollo SQL | 6 | 32 | 6 | **37** | 0 name-only; 0 invalid | 0/0/0 | catalogue-eligible | **1** | **Publishable** |
| `SPARTAN-PHYSIQUE` / `e75d7374-…` v2 | archived | first-party `cohort_global` | `b27e9a9fc24215bf3aa37a9c1d26775ba97cec4152fcd0390d8e92218b1b5ed7` | hosted SBE | 6 | 32 | 6 | 34 | 0 | 0 | not catalogue | **3** | Reconstructable; **no candidate** this task (archived, not current catalogue) |
| `SPARTAN-PHYSIQUE` / `7454ffd4-…` v1 | published coach_private | coach owner UUID only; **not** `cohort_global` | **missing** | hosted SBE 34 EX | 6 | 32 | 6 | 34 | — | 0 | no | **5** | Reject: no source hash; publisher not first-party |
| `COHORT-FOUNDER` / `d584b724-…` | published coach_private | coach owner | **missing** | hosted SBE 13 EX | 3 | 12 | 3 | 13 | 0 | 0 | no | **5** | Reject |
| `COHORT-FOUNDATION-TEST` / `aaaaaaaa-bbbb-…0002` | draft | test `created_by=dev-coach` | **missing** | 8 EX | 3 | 3 | 3 | 8 | 0 | 0 | no | **5** | Test/dev; reject |
| `COHORT-HYBRID-FOUNDATION-TEST` / `e80ec2ac-…` | draft | `owner_id=dev-coach` (non-UUID) | **missing** | 8 EX | 3 | 2 | 3 | 8 | 0 | 0 | no | **5** | Ambiguous ownership; reject |
| `COHORT-T` `test1` / `6d2d2c36-…` | draft | coach owner | **missing** | none | 1 | 0 | 1 | 0 | `__UNASSIGNED__` | 0 | no | **5** | Invalid slot; reject |
| `FOUNDER-ACCEPTANCE-PROGRAMME` / `bbbbbbbb-…0002` | draft | test `dev-coach` | **missing** | `BP-001`/`SQ-001` | 1 | 5 | 1 | 0 | 4 name-only + 2 invalid tokens | 0 | no | **5** | Invalid tokens; reject |
| `COHORT-C` `9df020c6-…` | lineage only | leftover | n/a | none | 0 | 0 | 0 | 0 | — | 0 | no | **4** | No version; no graph |

Display names were not used as identity or ownership evidence.

## E. Apollo qualification

| Requirement | Result |
|-------------|--------|
| Pinned version `2ba018bd-7dc2-4dfd-8d8e-e35823158920` | Exact pin on the single active assignment |
| Plan Package SHA-256 `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83` | Hosted hash and binder hash match; schema v1 unchanged |
| Publisher `cohort_global` | Proven by scope/owner_type, not by display name |
| Supplemental = committed Apollo SQL | Week executable + structured warmup SQL; hash `5bb78fc24df9af9f03b0bddde238b004f64c54c60cef0872640b0d209e4951d0` |
| Structured warm-up relationships included | Present in week SQL binder |
| 58 unique `EX-*` | Binder and hosted SBE both **58** |
| `EX-095`, `EX-137`, `EX-149` distinct | All present and distinct on hosted SBE |
| `EX-129` not merged | Present as its own id |
| Name-only recovery remains unresolved | 131 explicit `name_only_block:*` in supplemental (SQL-declared). Hosted currently has **25** blocks without SBE. No guessed edges |
| No fuzzy inference | Binder unresolved prefixes only `name_only_block:` / `legacy_tmp:` (none of the latter in this run) |
| Hash excludes row UUID/timestamp/catalogue/assignment | Graph hash unchanged after adding an operational assignment (`hash_with_assignment_unchanged=true`) |

**Permitted unresolved:** explicit `name_only_block:*` declarations. They are represented, not guessed.

**Publication-blocking unresolved:** unknown/non-`EX-*` exercise edges, or any unresolved array when `require_full_resolution=true`.

Binding rejects *unresolved canonical exercises*, not explicit name-only blocks.
Default publication payload uses `require_full_resolution=false`. Apollo is
therefore **qualified**, not rejected. Forcing full resolution **must** fail
(`unresolved_reference` / `full_resolution_required`). That rule was not
weakened.

## F. Spartan qualification (independent)

| Requirement | Result |
|-------------|--------|
| Lineage / version | `f5b44f26-9917-4ff2-b4d4-4e0e37bb6fb5` / `32986922-47d1-46b0-b391-a7931d73033e` v3 |
| Full hosted package hash | `b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e` (prefix `b4bfaab4` is corroboration only) |
| Publisher | `cohort_global` via `library_scope` + `owner_type=global` |
| 37 unique `EX-*` | Hosted SBE and candidate graph |
| Canonical resolution | 0 unresolved canonical EX; 0 invalid tokens |
| Session/block/placement | 6 published protocols, 32 blocks, 6 placements, 0 name-only |
| Supplemental | Derived from hosted SBE used-by edges only. Hash `052735532570816fabdd1824730edc4afdc414bc3f2eac8f28db2f23fffd6247` |
| Apollo SQL reused? | **No** |
| Local week-1 YAML file hash | `f54f230c…` — **not** the hosted package hash; not used as source |
| Publication | Qualified (class 1). Archived v2 is a separate prior, not this candidate |

A package hash alone was not treated as qualification.

## G. Legacy / other content

- `BP-001` / `SQ-001`: one SBE row each; **invalid** EX-* identity; on Founder Acceptance draft only.
- `__UNASSIGNED__`: one draft slot on `COHORT-T` / `6d2d2c36-…`.
- Name-only protocols/blocks: Apollo class-3 declarations (permitted if explicit); Founder Acceptance name-only blocks stay unpublished.
- Drafts / retired / test fixtures / missing `package_content_hash` / unproven publisher: **no candidates**.

## H. Candidate generation

Canonical implementation: `ApolloLocalGraphBinder` + `ContentGraphService` /
`ContentGraphCanonicaliser`. Isolated clean runs, twice each.

| | Apollo v2 | Spartan v3 |
|--|-----------|------------|
| Compiler | `content-graph-compiler/v1` | same |
| Graph format | 1 | 1 |
| Source package hash | `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83` | `b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e` |
| Supplemental hash | `5bb78fc24df9af9f03b0bddde238b004f64c54c60cef0872640b0d209e4951d0` | `052735532570816fabdd1824730edc4afdc414bc3f2eac8f28db2f23fffd6247` |
| Graph structural hash | `2b17ad30ab69a247948677078a1e37e5e7e077bf437cff527cb69937d5fb89e8` | `8ddb918e3e642c85bc150dff0741f4a581a21927375d2365102d945e77ae5715` |
| Composite identity | `481956c3277f4666ae80766c65e114b69aaf982758917e3de05ca5f8b9157b12` | `8c5989bd8ba360294cb619e721213a94fe19302387f7bf8008c203bfb5538d17` |
| Nodes / edges | 300 / 738 | 83 / 97 |
| Double-run | byte-identical payloads | byte-identical payloads |
| Candidate file SHA-256 | `7cad2dc991f8b089d61fe2b058a1fbf3ca55b1c1d3d2478720f8a96500e2d915` | `8e09179bf93d9e9d480c9284e33b79e9f45ebd1357e5db47c10709cfe57b0fa0` |

No timestamps or local paths in canonical identity. No assignment or athlete
identifiers in manifest content. Publication request payload uses hosted
programme-version UUID + publisher UUID `00000000-0000-4000-8000-00000000c001`.

Tool file SHA-256 (inputs to generation):

| File | SHA-256 |
|------|---------|
| `apollo_local_graph_binder.dart` | `04184121dedfa0cec4107442c024a7a259a43e3def663d547891d0b1385a2e9c` |
| `content_graph_canonical.dart` | `3a3b2aaa22ce1f6b252083f49b42982d543d92554f98ffbbc8a3ded83c8074ad` |
| `content_graph_manifest.dart` | `672c55de10449d38040e749612fd0408edbee675c9b66b3ab6e96c83f8248ab1` |
| `content_graph_service.dart` | `6d05a575f278bf16d53e6f7ff4ef745bb3e5962f5f353ef6c28dbc4172a4897c` |

## I. Validate without publishing hosted

Domain `InMemoryContentGraphManifestRepository`:

| Case | Apollo | Spartan |
|------|--------|---------|
| First exact publication | `published` | `published` |
| Exact retry | `alreadyPublished` | `alreadyPublished` |
| Changed graph, same composite | `conflictingIdentity` | `conflictingIdentity` |
| Unsupported compiler | `unsupportedFormat` | `unsupportedFormat` |
| `require_full_resolution=true` | `unresolvedReference` | `published` (empty unresolved) |
| Unauthorised actor | `unauthorised` | `unauthorised` |

Disposable local SQL (hosted schema, **not** Field Manual) using the exact
candidate payloads:

| Case | Apollo | Spartan |
|------|--------|---------|
| First exact publication | `published` | `published` |
| Exact retry | `already_published` | `already_published` |
| Changed graph, same composite | `conflicting_identity` / `version_already_has_manifest` | — |
| Changed package hash | `hash_mismatch` / `source_package_mismatch` | — |
| Unsupported compiler | `unsupported_format` | — |
| Wrong publisher UUID | `unauthorised` / `missing_publisher` | — |
| `require_full_resolution` after success | `already_published` (existing row wins) | `already_published` |

First-publish `require_full_resolution` for Apollo is proven on the domain
validator (`unresolved_reference`). After a successful publish, the SQL RPC
returns `already_published` before re-checking full resolution.

Hosted `publish_content_graph_manifest` was never invoked with these payloads.

## J. Used-by, impact, diff

Hosted read-model counts (views; no write):

| Projection | Apollo v2 | Spartan v3 |
|------------|-----------|------------|
| exercise → block rows | 990 | 52 |
| exercise → session rows | 979 | 49 |
| exercise → programme-version rows | 979 | 49 |
| session → programme-version rows | 84 | 6 |
| unique EX-* | 58 | 37 |
| unresolved-reference count (no published manifest) | n/a (0 manifests) | n/a |
| supersession rows | 0 | 0 |

Local graph projections: Apollo used-by reports **1** active assignment; that
count is absent from the graph hash. Operational impact preview (assignment
table only): active **1**, paused **0**, completed **0**. No athlete names.

Spartan v3 vs archived v2 local structural diff: **4** `breakingExecution`
entries (exercise add/remove). Graph hashes differ
(`8ddb918e…` vs `927de056…`). No eligible published prior manifest exists, so
hosted `content_graph_version_diff` cannot yet return `ok`.

## K. Proposed Phase 3B actions (do not execute)

Each unit is separately authorisable. Catalogue/default changes and assignment
repins stay **outside** Phase 3B.

### K1. Apollo reconstruction record (optional audit)

| Field | Value |
|-------|-------|
| Function | `content_graph_record_reconstruction` |
| Table | `content_graph_reconstruction_jobs` +1 |
| Version | `2ba018bd-7dc2-4dfd-8d8e-e35823158920` |
| Publisher | `cohort_global` `00000000-0000-4000-8000-00000000c001` |
| Source / supplemental / graph / composite | see Section H |
| Expected RPC | `dry_run` then optional `applied` with `rows_written=0` on exact retry |
| Idempotency | same `job_key` + fingerprint → noop; fingerprint change → `source_changed_during_resume` |
| Rollback | DELETE unpublished job row. Does not touch authored content |

Not required for publication; recommended only as an audit trail.

### K2. Apollo manifest publication

| Field | Value |
|-------|-------|
| Function | `publish_content_graph_manifest` |
| Table | `content_graph_manifests` +1 |
| Version / publisher / hashes | Section H |
| Expected RPC | first `published`; exact retry `already_published` |
| Row-count change | manifests 0→1; jobs unchanged unless K1 ran |
| Idempotency | composite + graph match |
| Forward repair | none in-place; published rows are immutable |
| Rollback | founder-approved DROP of that manifest row/objects only; not an in-place rewrite |

### K3. Spartan reconstruction record (optional, separate)

Same shape as K1 for `32986922-47d1-46b0-b391-a7931d73033e` and Spartan hashes.
Do not reuse Apollo supplemental or job_key.

### K4. Spartan manifest publication (separate)

Same shape as K2 for Spartan hashes. Do not bundle with Apollo.

## L. Candidate artifact security

Candidates contain no credentials, JWTs, emails, athlete/profile data,
assignment ids, or performance results. Stored only in the restrictive
checkpoint. **Not committed.**

## M. Tests and gates

| Check | Result |
|-------|--------|
| M9 graph binding / matrix / persistence / explorer | passed |
| Reconstruction dry-run (domain) | passed; hosted RPC not called |
| Publication validation (domain) | passed (Section I) |
| Used-by / impact / diff | local + hosted read models (Section J) |
| RLS/capability (Gate AX + static migration test) | static passed; Gate AX in local DB gate |
| Apollo binder | passed **twice** |
| Spartan binder | two isolated hosted compiles, byte-identical |
| Plan Package package tests | `packages/cohort_plan_package` dart test passed |
| Assignment-pinning / enrolment tests | passed |
| Migration static (`content_graph_migration_test`) | passed |
| `git diff --check` | passed |
| Local exact-candidate SQL validation | passed (disposable local DB) |
| Local DB Gate AX (full local DB gate) | **ALL LOCAL DB GATE CHECKS PASSED** |
| Phase 2 safety gate | **PASS** (6/6 groups) |
| Full `flutter test` | **not re-run** for the docs-only commit; no application/test source changes |

## N. Permission boundaries

Authorised this task: hosted SELECT, local dry-run, local candidates, docs.
**Not** authorised: hosted reconstruction job, hosted publish, publisher/principal
mutation, catalogue/default change, assignment repin, training-data mutation,
phone rebuild, git push, M10.

## O. Final invariant comparison

Repeated Section C query after all hosted reads. Must match Phase 2 closeout.

| Invariant | Pre | Post | Match |
|-----------|-----|------|-------|
| Ledger | 90 / `20260918120400` | identical | yes |
| Publishers / principals | 1 / 1 | identical | yes |
| Manifests / jobs | 0 / 0 | identical | yes |
| Helper | absent | absent | yes |
| Publisher / principal | `cohort_global` + owner `79853f15-…` | identical | yes |
| Pin | `b5fc87e3-…` → `2ba018bd-…` | identical | yes |
| Content/training hashes | Phase 2 values | identical | yes |
| Health | `ACTIVE_HEALTHY` | `ACTIVE_HEALTHY` (projects list) | yes |
