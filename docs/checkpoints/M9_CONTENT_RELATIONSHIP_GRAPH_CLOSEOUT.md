# M9 Content Relationship Graph and Versioning — closeout

**Recorded:** 2026-09-19

**Status:** M9 implemented locally and deployed on Cohort Field Manual.

**This is the authoritative M9 implementation and hosted-rollout checkpoint.**

Sprint handoffs, Field Manual preflight, and publication qualification remain
historical evidence. They are not the next-task authority.

```text
M9_CONTENT_RELATIONSHIP_GRAPH_CLOSED=true
M9_IMPLEMENTED_LOCALLY=true
M9_DEPLOYED_FIELD_MANUAL=true
APOLLO_V2_MANIFEST_PUBLISHED=true
SPARTAN_V3_MANIFEST_PUBLISHED=true
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_REGION=eu-west-1
HOSTED_HEALTH=ACTIVE_HEALTHY
HOSTED_PG=17.6
HOSTED_LEDGER_COUNT=90
HOSTED_LEDGER_MAX=20260918120400
CONTENT_PUBLISHERS=1
CONTENT_PUBLISHER_PRINCIPALS=1
CONTENT_GRAPH_MANIFESTS=2
CONTENT_GRAPH_RECONSTRUCTION_JOBS=0
BOOTSTRAP_HELPER_PRESENT=false
FOUNDER_PHONE_BUILD=7
PHONE_RELEASE_REQUIRED_FOR_M9=false
M10_STARTED=false
NEXT_MILESTONE=M10
```

Binding: [`../architecture/Content_Relationship_Graph_and_Versioning_v1.md`](../architecture/Content_Relationship_Graph_and_Versioning_v1.md),
[`../architecture/M9_Manifest_Authority_and_Binding_v1.md`](../architecture/M9_Manifest_Authority_and_Binding_v1.md),
[`../architecture/M9_Content_Graph_Persistence_v1.md`](../architecture/M9_Content_Graph_Persistence_v1.md),
[`../../content/content_graph/v1/README.md`](../../content/content_graph/v1/README.md).

## 1. What M9 delivered

- A versioned structural relationship graph over authored programme content
- Immutable, source-bound content-graph manifests
- Publisher / namespace authority (`cohort_global`)
- Programme-version pinning enforcement on enrolment
- Used-by projections (exercise → block / session / programme version)
- Operational assignment impact analysis (outside graph identity)
- Version-diff projections over published manifests
- Deterministic qualification of legacy Apollo and Spartan v3
- RLS and capability boundaries (schema version 2)
- Source-controlled publication artifacts under `content/content_graph/v1/`

## 2. Authority hierarchy

**Authoritative (authoring sources):**

- authored programmes and programme versions
- session revisions / protocols
- authored blocks
- canonical `EX-*` exercise identities
- programme placements
- compiler and supplemental relationship inputs

**Derived (never an authoring source):**

- Plan Package v1
- content-graph manifest v1
- used-by projections
- impact counts
- version diff

The graph records how authored identities relate. It does not invent
prescription, placements, or exercise identity. Display-name similarity is
never identity, substitution, or relationship authority.

## 3. Hosted schema

Applied additive migrations (Field Manual ledger max `20260918120400`):

| Version | File | SHA-256 |
|---------|------|---------|
| `20260918120000` | `supabase/migrations/20260918120000_content_graph_core.sql` | `09d980e63c59c6673cef9bc5667cab3eb0c9c9a6c5d9dd9aacb18c85bf4e6edb` |
| `20260918120100` | `supabase/migrations/20260918120100_content_graph_publication.sql` | `db93f774a498366e393874ca89ab31591ae20f674b11e6e165ae90d1e2fd0929` |
| `20260918120200` | `supabase/migrations/20260918120200_content_graph_read_models.sql` | `a561023a6a62b698c0f131c3ade4d181df91dfcd7f0daf8543651ef6df07229d` |
| `20260918120300` | `supabase/migrations/20260918120300_content_graph_rls.sql` | `909e9f19872078eb2136e53c2a571f20d7fcd01edbfd86ce0b324f17da36e53c` |
| `20260918120400` | `supabase/migrations/20260918120400_content_graph_reconstruction.sql` | `9b40fb312a06c020d35b063443022214223cae9df695f4c17a10a84cb6bb6655` |

Objects introduced: `content_publishers`, `content_publisher_principals`,
`content_graph_manifests`, `content_graph_reconstruction_jobs`; publication /
hash / capability functions; used-by / unresolved / supersession views;
immutability and assignment-pin triggers; least-privilege RLS.

Publisher bootstrap is **not** a migration. First-party `cohort_global` was
created by a separately authorised bootstrap, then the bootstrap helper was
dropped. Reconstruction jobs were **not** required: publication SQL has no job
prerequisite. Assignment `programme_version_id` is immutable through ordinary
updates.

## 4. Published programmes

| | Apollo v2 | Spartan v3 |
|---|---|---|
| Manifest ID | `46940d28-9ed0-4287-ab18-e2c321b599a5` | `ef94597b-8ac4-4ef5-9672-8c76b6255197` |
| Programme version | `2ba018bd-7dc2-4dfd-8d8e-e35823158920` | `32986922-47d1-46b0-b391-a7931d73033e` |
| Source | `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83` | `b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e` |
| Supplemental | `5bb78fc24df9af9f03b0bddde238b004f64c54c60cef0872640b0d209e4951d0` | `052735532570816fabdd1824730edc4afdc414bc3f2eac8f28db2f23fffd6247` |
| Graph | `2b17ad30ab69a247948677078a1e37e5e7e077bf437cff527cb69937d5fb89e8` | `8ddb918e3e642c85bc150dff0741f4a581a21927375d2365102d945e77ae5715` |
| Composite | `481956c3277f4666ae80766c65e114b69aaf982758917e3de05ca5f8b9157b12` | `8c5989bd8ba360294cb619e721213a94fe19302387f7bf8008c203bfb5538d17` |
| Manifest path | `content/content_graph/v1/cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.manifest.json` | `content/content_graph/v1/cohort_global/spartan/32986922-47d1-46b0-b391-a7931d73033e.manifest.json` |
| Publication path | `content/content_graph/v1/cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.publication.json` | `content/content_graph/v1/cohort_global/spartan/32986922-47d1-46b0-b391-a7931d73033e.publication.json` |
| Manifest file SHA-256 | `01876a268b2194ff72395a7a68f12dc3f9d438ed73b13b36ba2108856b25deb4` | `515362b81902c520d2f71c351739cc79b21b94923b1997fa84e28ce74615e202` |
| Publication file SHA-256 | `fb2378ee6b841d71225e37d6c2823d5b966ac380dcea31366f288957736c0dc1` | `c517b2f0359e2f0f7bc68bb57b64f9c67ab82d09373244c3cda9ca302415eb67` |
| Nodes / edges / unresolved | 300 / 738 / 131 | 83 / 97 / 0 |
| `require_full_resolution` | false | true |
| Hosted published_at | `2026-09-19T09:21:39.212069+00:00` | `2026-09-19T10:05:39.948267+00:00` |
| State | published | published |

Compiler `content-graph-compiler/v1`, graph format `1`, publisher
`00000000-0000-4000-8000-00000000c001` / `cohort_global`.

## 5. Apollo qualification

Plan Package v1 remains frozen at the source hash above. Binder and hosted SBE
retain **58** canonical `EX-*` identities, including distinct `EX-095`,
`EX-137`, `EX-149`, and `EX-129`. Supplemental relationships come from
committed Apollo week SQL (`apollo-sql-relationships/v1`), including structured
warm-ups. **131** explicit `name_only_block:*` declarations remain unresolved;
no canonical exercise ID is unresolved; no fuzzy inference. Lee’s assignment
`b5fc87e3-ca5b-4f02-a2cb-582a38d55c75` stays pinned to Apollo v2.

## 6. Spartan qualification

**37** canonical `EX-*` identities. Supplemental source is hosted-compatible
canonical relationships in
`content/content_graph/v1/sources/spartan_physique_v3.relationships.json`, not
Apollo SQL. Full resolution is required and succeeds with **zero** unresolved.
Archived Spartan v2 (`e75d7374-147f-4493-ba67-021855f51798`) is unpublished.
`BP-001`, `SQ-001`, and `__UNASSIGNED__` are absent.

## 7. Hosted invariant proof

Authorised Field Manual writes across M9 rollout were limited to:

- five migration ledger entries / schema objects (`20260918120000`–`120400`)
- one publisher
- one owner principal
- two immutable manifests

Unchanged versus Phase 2 / qualification postflight content hashes:
lineages, versions, slots, protocols, blocks, SBE, exercises, assignments,
occurrences, sessions, records, result trees, catalogue-eligible pair (Apollo +
Spartan v3), Apollo and Spartan package hashes. Reconstruction jobs remain **0**.

## 8. Security model

- Assigned athletes and catalogue-eligible published versions may read those
  manifests
- Publisher principals read their namespace
- Impact counts require an active publisher principal (or service role)
- Anonymous is denied
- Coaches do not receive a global graph bypass
- Trusted publication uses the service-role / postgres path
- Used-by views are `security_invoker`
- Published manifests are immutable (`trg_content_graph_manifests_immutable`)
- `cohort_athlete_runtime_capabilities` schema version **2**
  (`content_graph_read` / `publish` / `impact`)

## 9. Operational procedure for future programmes

1. Author canonical content.
2. Publish an immutable programme version.
3. Compile the frozen source package (Plan Package v1 today).
4. Generate supplemental relationships from approved repository inputs only.
5. Generate the graph twice from clean isolated runs; require byte-identical
   outputs and identical hashes.
6. Commit the candidate artifact under `content/content_graph/v1/`.
7. Review exact file and identity hashes.
8. Bootstrap a publisher separately if the namespace does not already exist.
9. Call `publish_content_graph_manifest` with the exact committed publication
   JSON.
10. Verify the typed first result (`published`).
11. Retry the exact request once (`already_published`).
12. Verify invariants. Do not infer relationships by display name.

Committing an artifact still does not, by itself, authorise hosted publication.

Local hosted comparison (secrets supplied externally; **not CI**):

```bash
M9_VERIFY_HOSTED=1 ./tool/content_graph/verify_hosted_published_artifacts.sh
```

## 10. Remaining work

- Archived Spartan v2 remains unpublished
- Invalid / test / name-only legacy content remains unpublished
- No generic hosted reconstruction was run
- Athlete-facing graph UI is future work
- Publisher authoring / impact UI is future work
- Explicit audited assignment repin is future work
- Plan Package v2 remains proposal-only
- **M10 has not started**

Founder phone **build 7** remains the current install. M9 backend publication
did not require a phone release.
