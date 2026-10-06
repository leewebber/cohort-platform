# Performance Tracking C2 programme-attribution — hosted deployment

**Verified:** 2026-10-06. **Status:** HOSTED_APPLIED_SELECT_VERIFIED; production unwired.
Target: **Cohort Field Manual** `otnhhdxstdnwccehacku`, eu-west-1, ACTIVE_HEALTHY before and after.
[Reviewed handoff](./PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md) and
[approved proposal](../architecture/Performance_Tracking_C2_Programme_Attribution_Authority_Proposal_v1.md).

## Exact integration and deployment

The six reviewed linear commits, zero merges, were strictly fast-forwarded from
`005d53dc9b822d7e8075c75e5679324b93edebf2` through
`79e4d9154c6d1dc6f6e69a468e917d6d00186cf0` in the preceding authorised integration.
Before this apply, clean HEAD equalled cached origin/main at that exact approved tip.
No fetch/push/ref changes were performed in this deployment task.

| Applied migration | SHA-256 |
|---|---|
| `20261005140000_tracking_publication_artifact_retention.sql` | `b0380ba02c0e778b505019a7dc55e62a7d2c7a7642c4c9b454d5b595a62c4cdb` |
| `20261005141000_tracking_programme_coherent_read.sql` | `a603d560108cc6a2d75f915e710948951e3a6c9ed5042f371d57af838583931d` |

Fresh disposable linked workdir contained copied production migrations/config;
repository supabase/.temp was excluded. Exact HEAD/clean worktree, target/health,
ledger **115 / 20261005130000**, pending-object absence, both repository/copied
hashes, all 24 evidence baselines (including all 21 previously recorded tables),
and six existing authority/security fingerprints passed. The linked dry-run
listed exactly the above two files in timestamp order.
`supabase db push --linked --yes` applied only that pair; no roles, seeds, include-all or repairs.

CLI 2.109.1 returned success, with a pg-delta migration-catalog cache warning
about a missing certificate file. This warning was resolved as a verification
question by independent hosted SELECT checks and the final successful dry-run;
no certificate/permission remediation or bypass was attempted.

## Current-task SELECT-only verification

[Exact 43 SELECT checks](./PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_CHECKS.md)
**passed**. Ledger **117 / 20261005141000** matches the exact old
115-version set plus these two entries, each exactly once. Final health remains
ACTIVE_HEALTHY; final linked dry-run reports `Remote database is up to date.`

All six functions are postgres-owned with exact committed source bodies and
fixed `search_path=pg_catalog, pg_temp`:

| Function | Language / volatility / security | Client execution | Source MD5 |
|---|---|---|---|
| `cohort_tracking_artifact_immutable` | plpgsql / VOLATILE / INVOKER | none | `7f5be35f604e8b793ab4d80b4cd0dc24` |
| `cohort_tracking_canonical_text` | sql / IMMUTABLE / INVOKER | none | `11bfd80b6cfbac93453a8a117e9675c7` |
| `cohort_tracking_scope_seal` | sql / STABLE / INVOKER | none | `6dc3232cc0c08632eebc2abcfd166fcc` |
| `cohort_tracking_payload_graphs_match` | plpgsql / IMMUTABLE / INVOKER | none | `4d661c8e769ebd08fb6b4db7222c3d76` |
| `publish_private_exact_programme_version_retained_v1` | plpgsql / VOLATILE / DEFINER | service_role only | `4fe3b1f7a4d9a6d266972f9706a968d4` |
| `read_performance_tracking_programme_history_v1` | sql / STABLE / DEFINER | authenticated only | `07f2506dadb5bbd1781a9c4944a2e5e3` |

PUBLIC/anon have no execution. Private helpers also deny authenticated/service_role.
The combined reader's exact UUID/JSONB argument names, no defaults, and JSONB
return type were checked. Existing independent read, correction, original
publication functions, grants/RLS, columns, constraints and triggers retain
identical authority fingerprints; no mutation RPC or restricted validator ran.

Artifact table is postgres-owned, RLS-enabled, with no policies or direct
PUBLIC/anon/authenticated/service_role privileges (including inherited access).
Its enabled BEFORE ROW UPDATE/DELETE trigger invokes the exact immutable helper;
seven validated CHECKs, primary key and programme-version foreign key with
ON DELETE RESTRICT are present. Artifact row count is **zero**: no publication,
legacy backfill or fabricated seal occurred. Immutability was inspected as
metadata, without attempting forbidden hosted writes.

All 24 existing evidence counts/digests below remain unchanged. The recorded
training_sessions authenticated SELECT/RLS-disabled discrepancy is preserved;
this is neither intended authority for the combined reader nor permission repair.
Normal database protections do not claim resistance to privileged out-of-band
administrator changes. No hosted concurrency test was run: approved local proof
at the reviewed tip (51 affected tests, three correction races, one publication
race, six safety groups) is reused, without tests/builds in this task.

## Compatibility baseline

All 21 counts/digests recorded at independent-C2 deployment still match. Three
additional publication-scope relations are now captured. Existing running shape:
11 programme versions, 188 slots, 184 unstructured, four authored/mapped; B2
benchmark/revision counts 1/1, frozen snapshots 4, corrections 0. Full-row digest
statements and their exact ordering/delimiter are embedded in the postcheck SQL;
use those unchanged. Fingerprints here use independently recorded expressions,
not the older composite fingerprint method. No restricted running-validator
execution is implied by document counts or metadata source checks.

| Existing relation | Rows | Whole-row MD5 |
|---|---:|---|
| `content_graph_manifests` | 2 | `79ca291a0373dcbca703200002ed6d5b` |
| `performance_protocols` | 317 | `8b53719eaa6d4ba73c7519184dd6e6d0` |
| `performance_result_corrections` | 0 | `d41d8cd98f00b204e9800998ecf8427e` |
| `programme_assignments` | 3 | `93783bee2b6eea7303ffabf9ccf94107` |
| `programme_lineages` | 10 | `ec342621cd2c7ad7769ccd1ee8947133` |
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
| `session_block_exercises` | 1648 | `98685d8c71553379c3d8f31e5a8f8ae4` |
| `session_blocks` | 495 | `51e8b026a8a6c782bb2dfc9b49338ae3` |
| `session_lineages` | 306 | `b0e5d34b2e9bcfbffea94faef16dc948` |
| `training_block_results` | 63 | `09c061feae3a51d899b15cbe2e35cee3` |
| `training_exercise_results` | 183 | `95fa7f233464700beb2a462731b390ae` |
| `training_session_records` | 24 | `991c35c77cf81b5b966728c7bed3bf7f` |
| `training_sessions` | 47 | `8e4a15439d61ca42505bc4f34fba966e` |
| `training_set_results` | 411 | `ebe23fafe37ebed93134c1ab91196983` |

Existing authority fingerprints (exclude only new reviewed objects):
- relations: `6aced221c1d48d960f94e2b46edb05b2`
- functions: `19d2b470cf1ec0e3d9de427140aadc65`
- policies: `5b587989dc9f0a9dd1af89b2a4276437`
- triggers: `ad7cff8ab29367ab16a970c86e64f5d4`
- columns: `feeb9d40daf7d52d1b62d8267f1d742c`
- constraints: `2b1e4d6ff8bd2e10314dbc32d5326c62`

## Scope and closeout

New combined authority and future-only trusted private-publication retention are
deployed. The independent reader still refuses programme claims; the combined
reader/typed bridge remain unwired. Existing versions without retained proof
remain `programme_scope_unproven`; empty artifact retention means no existing
programme has acquired proof through this deployment. Separate scope seals do
not put protocol bodies into original v1/v2 hashes. Tracking never grants
prescription eligibility or reconstructs unavailable historical inputs.

Disposable linked files were removed; repository supabase/.temp content hashes
are unchanged. Only documentation is committed locally after verification;
no push, real publication, athlete/programme writes, production wiring, permission
widening, UI, selection/manual storage, tests/builds or next-slice implementation.
Further operations require separate founder authority.
