# Performance Tracking C2 — independent History hosted deployment

**Verified:** 2026-10-05; apply receipt 2026-10-05T12:20:30.368516+00:00.
**Status:** INDEPENDENT_C2_INTEGRATED_HOSTED_SELECT_VERIFIED.
Programme attribution remains BLOCKED; bridge/adapter remain unwired.

**Target:** Cohort Field Manual, `otnhhdxstdnwccehacku`, `eu-west-1`;
ACTIVE_HEALTHY before/after apply, PostgreSQL 17.6.

**Clean implementation HEAD and freshly fetched origin/main:**
`144ba110f8de938dc3fbd3e9cbb9a83fd21cf4ba`.
The reviewed four linear C2 commits were integrated by founder-authorised strict
fast-forward from `72c1281f0966f2a6485873f6071b0e000ba1e000`; zero merges.
C1's seven reviewed commits, both audits and original implementation are preserved.
Deployment documentation was subsequently integrated on origin/main at
`005d53dc9b822d7e8075c75e5679324b93edebf2` by authorised strict fast-forward.
The [bounded programme-attribution proposal](../architecture/Performance_Tracking_C2_Programme_Attribution_Authority_Proposal_v1.md)
is documentation only; it adds no deployment or permission authority. Recorded
hosted evidence below was not refreshed for that proposal.

Binding: [independent-reader review](./PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md),
[reader handoff](./PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
[preserved adapter handoff](./PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md),
[read-boundary proposal](../architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md)
and [approved tracking contract](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md).
Founder authority was limited to this migration, prepared SELECT postchecks and
local documentation. No witness expansion or production wiring was authorised.

```text
PERFORMANCE_TRACKING_C2=INDEPENDENT_HISTORY_READ_INTEGRATED_HOSTED_VERIFIED
PERFORMANCE_TRACKING_C2_COHERENT_READER=INDEPENDENT_HOSTED_VERIFIED_PROGRAMME_WITNESS_BLOCKED
PERFORMANCE_TRACKING_C2_HOSTED_MIGRATION_APPLIED=true
PERFORMANCE_TRACKING_C2_PRODUCTION_WIRED=false
PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION=BLOCKED
COHORT_5K_TEST_INGESTION=BLOCKED
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## Exact operation and guards

Applied exactly once:
[20261005130000_performance_tracking_coherent_history_read.sql](../../supabase/migrations/20261005130000_performance_tracking_coherent_history_read.sql).
SHA-256 (repository and fresh disposable copy):
`1625ee58a2400946b0ac73ed2933e52ee3ef55fa7b40922cc0f70cd7459544cf`.

Before apply, exact clean HEAD/origin equality and divergence 0/0 were fetched
and checked. Target health/identity, ledger **114 / 20261005120000**, function
absence, recorded SELECT/RLS/helper/role/correction authority, package/data and
running compatibility baselines matched the previous preflight exactly. A fresh
workdir copied config/migrations and was explicitly linked to the target. Linked
CLI and SELECT ledgers matched; dry-run listed only this file. All recorded
baselines, Git/hash guards and one-file dry-run were repeated immediately before
`supabase db push --linked --yes` from that workdir. No include-all/repair flags,
other migration, mutation RPC, validator bypass or permission repair was used.

## SELECT-only post-apply verification

All prepared checks passed; no data-mutating RPC was invoked:

- Ledger **115 / 20261005130000**, with exactly this addition and all prior
  versions unchanged. Final linked CLI ledger has 115 matched local/remote rows;
  final `db push --linked --dry-run` reports up to date, no pending migration.
- `public.read_performance_tracking_history_v1(uuid,jsonb)` returns JSONB;
  SQL, STABLE, SECURITY INVOKER; fixed `search_path=pg_catalog, pg_temp`;
  exact argument names and one SQL NULL::jsonb default; normal postgres owner.
- Function body exactly matches committed SQL (source MD5
  `0ced1cfb29b3393128fc96055bb9f810`). Authenticated EXECUTE present;
  PUBLIC/anon/service_role EXECUTE absent. Authenticated has neither superuser
  nor BYPASSRLS; anon/service_role do not inherit authenticated privileges.
- All existing public relation ACL/RLS, policies and function definitions are
  unchanged when excluding only the new C2 function. Authority fingerprint:
  `98551d6ee80df50a24bc533c9534eb5f`. History column/schema fingerprint:
  `547f4e1376c624489158ddda772c043a`. Existing trigger definitions and
  enabled states also unchanged.
- Existing correction function body matches committed interval-correction SQL:
  source MD5 `ced29cd50ce06c9a8f7304f4bd132dc7`, definition MD5
  `befa2b796a69fd9762a222e5a50214af`. SECURITY DEFINER, VOLATILE,
  `search_path=public, pg_temp`, authenticated EXECUTE, no PUBLIC/anon execution.
  Append-only audit trigger and B3/history synchronization guards remain enabled.
- History record/result/audit SELECT and owner/parent RLS remain intact;
  authenticated has no direct audit INSERT/UPDATE/DELETE. Schema/auth.uid and
  owner-policy helper permissions are unchanged. Coach helpers are STABLE
  SECURITY DEFINER with no training_sessions dependency. Parent/audit contradictions
  remain zero; 21 records retain session links, largest child/audit collection 65.
- Existing whole-row counts/digests below are identical before/after apply.
  Package/version hash digest: `3aaba5f506e8ce27d0087dab5474cbae`.
  B2 benchmark evidence/revision and four frozen targets are unchanged.
- Running compatibility remains 11 versions, 188 slots, 184 unstructured,
  four authored/mapped documents and zero advisory-step overlaps. Authored
  document digest `8f0dd0f6cc436acd7a1244c922864f52` and B4 validator definition
  `f25dcbb155234b30114a733e42541c8b` remain unchanged; its body matches
  committed B4 authority. **No restricted validator execution was attempted in
  this apply task**, and none was bypassed. Earlier preflight's denied execution
  remains recorded; this is metadata/count/digest compatibility proof, not a
  fresh full authored-document validation.

Digest method for table rows (replace `<relation>` with the recorded table):

```sql
SELECT count(*) AS rows,
  md5(coalesce(string_agg(to_jsonb(t)::text, E'\n'
    ORDER BY to_jsonb(t)::text), '')) AS digest
FROM public.<relation> t;
```

Counts/digests from this exact expression matched before and after. Digests are compatibility comparisons, not
new immutable measurement revisions or trust credentials. Point-in-time evidence
must be refreshed for any later operation; unexplained drift must not be reset.

| Existing relation | Rows | Unchanged compatibility MD5 |
|---|---:|---|
| `content_graph_manifests` | 2 | `79ca291a0373dcbca703200002ed6d5b` |
| `performance_protocols` | 317 | `8b53719eaa6d4ba73c7519184dd6e6d0` |
| `performance_result_corrections` | 0 | `d41d8cd98f00b204e9800998ecf8427e` |
| `programme_assignments` | 3 | `93783bee2b6eea7303ffabf9ccf94107` |
| `programme_occurrence_running_target_snapshots` | 4 | `3051e0761c69f8dce4ad2fe3582f27ef` |
| `programme_schedule_occurrences` | 159 | `1e917b91142989e41e24ecb892b91adc` |
| `programme_schedule_projections` | 3 | `4233c77490ecd2630930ee96c622b2b3` |
| `programme_slot_outcomes` | 19 | `cef070f5ebb77ec823861d171e049f2b` |
| `programme_version_days` | 181 | `d2958bf65a61a706c74d7c6641b1ef72` |
| `programme_version_phases` | 4 | `345584b891b959a3c36d82ccf9d259a4` |
| `programme_version_session_slots` | 188 | `d69b784c44a5dd655031c3ab78899814` |
| `programme_version_weeks` | 29 | `aef4f0e0fb035197d98a84bfcc0eb6a8` |
| `programme_versions` | 11 | `efa3ffebac4022e49d79d80cbba79afe` |
| `running_5k_benchmark_evidence` | 1 | `ab4ab22a621bb2fdc4bb4f768280ddd0` |
| `running_5k_benchmark_evidence_revisions` | 1 | `601fd79026f98f49100aa08c39ecd3a3` |
| `session_blocks` | 495 | `51e8b026a8a6c782bb2dfc9b49338ae3` |
| `training_block_results` | 63 | `09c061feae3a51d899b15cbe2e35cee3` |
| `training_exercise_results` | 183 | `95fa7f233464700beb2a462731b390ae` |
| `training_session_records` | 24 | `991c35c77cf81b5b966728c7bed3bf7f` |
| `training_sessions` | 47 | `8e4a15439d61ca42505bc4f34fba966e` |
| `training_set_results` | 411 | `ebe23fafe37ebed93134c1ab91196983` |

## Preserved permission discrepancy and remaining boundary

Hosted authenticated **already has training_sessions SELECT**, with that table's
RLS disabled. This differs from the disposable local baseline's denied SELECT.
Its pre-existing grants/RLS were preserved byte-for-byte in metadata fingerprints;
C2 does not query that relation or repair it. The local proof that independent
History works without parent SELECT remains valid. Do not describe hosted SELECT
as missing, or treat its presence as permission to add a programme witness.

The deployed immutable independent RPC still refuses every supplied programme
claim; missing retained links and contradictions remain explicit failures. No
assignment/version/package/occurrence/outcome/actual-session/protocol/block/running
witness or canonical artifact delivery has been implemented or admitted. A future
witness slice must review actual target access and prove the complete coherent
chain plus server-attested canonical bytes; broad existing SELECT does not supply
that proof. The separately proposed narrow witness authority is not approved by
this deployment. No client-supplied hash or reconstructed package is trusted.

Current actuals/audit membership can support independent observations only.
Incomplete audits/tied timestamps cannot establish previous inputs or a latest
field revision; historical reconstruction remains refused. Tracking grants no
prescription eligibility. B2 policy, target snapshots and blocked Cohort benchmark
ingestion remain unchanged. Persistence/selection/manual entry, calculations,
scoring, profiles/tests, UI, schema v3 and next slices remain separately scoped.

The RPC deployment is catalog/permission/data-compatibility verified. No hosted
athlete RPC invocation or production bridge/UI consumer was exercised. Local
ownership/completeness/bounds and three concurrency races remain attributed to
immutable reviewed C2 proof; tests and builds were not rerun. No real programme,
athlete or assignment writes, publication, production wiring, pushes or next-slice
implementation. Repository supabase/.temp is unchanged. Fresh disposable linked
files are removed; only this sanitized committed record is retained. Stop before
pushing the local documentation commit.
