# One bounded deployment plan, currently blocked before apply approval

Target: **Cohort Field Manual / otnhhdxstdnwccehacku / eu-west-1**.
Reviewed application/schema source: **55c38bbee7015bc16b25dd6d4fef4eb01900195f**.
This documentation continuation changes no runtime/migration bytes. Source manifest:
[128-file published inventory](../hyrox_athlete_runner/MIGRATIONS.json), independently
SHA-256-checked against every working file and published Git blob; [conditional subset](MIGRATIONS.json).

**Not apply-ready:** actual ledger/catalogs are inaccessible while the project is INACTIVE.
No pending-file claim, writable connection, verified current hold or executable deployment
approval is inferred. The procedure below must stop at every unresolved gate. No hosted
operation described below was executed except the read-only metadata probes in INSPECTION.json.

## A. Operational restoration and read-only gate — separate authority first

1. Obtain authority to resume only the identified Supabase project and an agreed writer
   maintenance window. Confirm who controls all phones/app clients, legacy Cloud Run import
   callers, scheduled jobs, direct SQL writers and queues. Cloud Run is currently Ready and
   may reconnect when Supabase resumes. Do not resume the database before the operator's
   writer hold is established. No silent project restore, route, IAM or traffic change is allowed.
2. The previously described method was a founder-controlled hold on clients/external writers,
   then aggregate SQL drain checks, with deliberate reversal of the same hold afterward.
   There is no repository-owned maintenance switch, job controller or verified server
   pause/resume endpoint. **That dated method is not a verified current hold.** Before apply,
   require a current receipt naming each writer class, its exact reversible hold mechanism,
   operator, observed effect and reversal; account for queued/retrying requests. If the
   operator cannot demonstrate a complete hold, stop and separately review a concrete
   traffic/job-control change. Do not invent a deployment-script shutdown flag.
3. After separately authorised resumption, reconfirm project ID/name/region, ACTIVE_HEALTHY
   and actual database version/identity. Under the standing read-only inspection authority,
   run [READ_ONLY_PREFLIGHT.sql](READ_ONLY_PREFLIGHT.sql) in a read-only transaction; collect
   complete ordered ledger metadata, then conditional inventory only for tables actually
   present. Check [V3_INVENTORY.sql](V3_INVENTORY.sql) only once all its tables exist.
4. Reconcile **all 128** expected ledger entries against exact versions/names and historical
   receipts. Ledger SQL statement fingerprints are useful drift metadata but are not
   raw-file SHA-256s; statement splitting/newline normalisation precludes pretending they
   are. Match the exact retained SQL source and pre/post function bodies/owners/ACLs too.
   An unknown version, gap, different name/body/security property, partial schema, or
   unexplained prior execution stops preparation for inspection. Never repair the ledger.
5. Refresh function identities/bodies/security/search paths, inherited and PUBLIC effective
   grants, table/column/sequence ACLs, RLS policies, role graph (including PG17 SET/INHERIT/
   ADMIN options), defaults, immutability triggers, restrictive FKs and exact source pins.
   Compare to reviewed source and the preceding storage/authoritative/security preflight
   contracts. Source hashes alone cannot certify hosted schema. Broad service membership,
   usable publisher membership before provisioning approval, external execution of private
   helpers, missing owner policies or unexplained PUBLIC/default authority is a stop.
6. Confirm no retained unresolved legacy v3 programme pins/artifacts, partial publication
   claims, incompatible existing v3 performance packets, or snapshots needing a reviewed
   recovery/resume policy. Inspect presence/count/fingerprint metadata only; do not read
   athlete values or reconstruct targets. Preserve approved v1/v2/B2 and C1/C2/C3 contracts.

## B. Schema-only batch — later exact approval, no producer/content/client rollout

If and only if the current ledger is the complete exact **122-file prefix**, all six
following versions/schema objects are absent, all safety/security preconditions pass and
no unexplained drift exists, propose this **six-file** batch in timestamp order:

| Order | Filename | SHA-256 |
| --- | --- | --- |

| 1 | `20261022120000_hyrox_base_declared_evidence.sql` | `2ad14f089cd035bda16599214623a2d3cba9ec178be6855bdf88b71aa647e444` |
| 2 | `20261022121000_v3_unresolved_authority_guard.sql` | `bffce413245eb8d71e5a4dcbc9f73ab36c91c58ec5ee8fec6e23c71dedba6cf0` |
| 3 | `20261023120000_authoritative_exercise_versions.sql` | `78e392109342873d74125982763e6c4629508c9e7282ddd9bd66ba4bc39baa61` |
| 4 | `20261023121000_v3_authoritative_publication.sql` | `3bbb2534706a633e7584a76f076c30e5a815ecf84f55ef85a51c6ebb40b33ef1` |
| 5 | `20261023122000_v3_programme_consent_start.sql` | `33f7b9ef63bea7393c1355319b3812cd7d4c461efcb686b9b6aaa7ab0dd97398` |
| 6 | `20261023130000_v3_athlete_review_state.sql` | `261619275e9007446f9502b24f61bf3e1d085f50562600e9ab8bb1e9b22cc98d` |


These are a **conditional source manifest**, not the actual pending set. If the five earlier
security prerequisites below are missing, stop and obtain an explicitly reviewed expanded
prerequisite plan/authority; this six-file proposal cannot silently include them:

| Prerequisite filename | SHA-256 |
| --- | --- |
| `20261007120000_history_read_permission_remediation.sql` | `7c5ce19e72ddd438acfe9db23a5b3c4abed65bdeb6db8faa82e8e7df70910ff7` |
| `20261007130000_completion_ownership_and_parent_guard.sql` | `d0a6a4b16a60376c3d7d97420b9e5e423efaf12d6d636b16064bfa7143fcbbe5` |
| `20261008120000_completion_result_identity.sql` | `604309505ca646801951d92fb6e305ae070bf1a6c1854338d633fc015f809320` |
| `20261008121000_completion_link_locking.sql` | `33712db05d2439b7c42729b8e5f57f66a6992ef3cf1ce26a807f5bb15cc4e8cd` |
| `20261009120000_backfill_authenticated_execute.sql` | `282e8b24ade00ac19370519e5b03b302d763209afe7d847f777e098ae934e976` |


Any other missing prerequisite similarly stops this proposal. If all 128 versions already
exist, do not apply anything; perform catalog compatibility/postchecks instead. Partial
suffixes require an inspected per-file transaction/ledger/schema receipt and a newly exact
remaining-file proposal, not an assumed retry. A fresh linked dry-run is still required
before later deployment; none ran against this inactive database.

After exact target/file/hash approval and a verified hold:

1. Export the approved committed `supabase/config.toml` and migration files into a disposable
   directory. Exclude `.temp`, `.env`, secrets and seeds; do not relink or change a preserved
   checkout. Revalidate source HEAD/manifest, remote alignment and target independently.
2. Require the ordinary linked dry-run to list **only the authorised exact files in order**.
   Do not use `--include-all`, role/seed imports, ad hoc grants or a migration-repair command.
3. In the held window, require the six aggregate drain counts in READ_ONLY_PREFLIGHT.sql
   to be zero with adequate visibility: no other active/open client transaction, write/idle
   transaction, unobservable activity, protected non-read locks, prepared transaction or
   enabled logical replication subscription. Recheck immediately before apply. Visibility
   failure/null is failure; a momentary zero without a writer hold is insufficient.
4. Capture a fresh pre-apply protected baseline with the existing
   [19-aggregate SELECT](../security_remediation_readiness/postchecks/protected-evidence.sql),
   plus relevant existing v3 aggregate fingerprints and legacy function/ACL/constraint/trigger
   identities. Explain historical differences separately; do not silently replace old
   checkpoint digests. During a verified hold the new pre/post baseline must be identical
   for all protected data. No completion/reset of live records is permitted to manufacture a drain.
5. Apply only the approved ordinary migration batch. Each file has its own transaction;
   the batch is **not atomic**. Keep the writer hold through all files and postchecks.
   The new DDL explicitly creates an unassigned NOLOGIN capability role and grants its
   narrow retention functions. Approving that schema object does not authorise a usable
   login, membership, credential or producer operation.

## C. Postchecks before reversing the writer hold

Require fresh ACTIVE_HEALTHY and exact expected ordered ledger. Run the preceding
[storage postcheck](../hyrox_v3_canonical_storage/POSTCHECK.sql),
[authoritative postcheck](../hyrox_authoritative_start/POSTCHECK.sql) and
[athlete review-state postcheck](../hyrox_athlete_runner/POSTCHECK.sql), plus this checkpoint's
catalog/inventory SELECTs. The authoritative assertion script describes the **unprovisioned
schema-only stage**: it intentionally rejects usable publisher memberships. Do not weaken
that assertion to accommodate separately provisioned identities without a new stage-specific
security review. Inspect effective defaults including implicit PUBLIC access when `proacl`
is null; direct ACL text is not sufficient.

Compare function body/identity and effective-grant deltas to the exact migration changes:
legacy private bodies stay equal, existing public overload identities and B2 bodies stay
protected, only reviewed wrappers/new overloads/guards change. Verify new owner-only reader,
no external execution of guards/calculators, correct canonical overload grants, immutable
snapshot/record guards and dimensional interval-result rules. Inspect new source-retention
RLS/ACL/FKs/triggers and the empty transient-claim table. Run prior security metadata
checks without treating their dated ledger constants as current generic checks.

Repeat the protected 19-aggregate baseline and any existing v3 fingerprints: exact match
under the hold. Verify no source artifact/benchmark/consent/start/history row was created
by schema deployment; dependency-rule rows are the explicitly reviewed seed exception.
Run retained-link consistency/link-health aggregate checks and require zero contradictions.
If all checks pass, require an empty final dry-run, record the receipt and have the named
operator reverse **the same demonstrated writer holds**. Verify health and normal legacy
service metadata after resume without issuing real athlete commands. No actual reopening
is claimed until observed. Keep v3 publication/provisioning and client rollout disabled.

## D. Partial failure and incident recovery

- On error, **retain the writer hold**. Capture failing file, time, transaction/lock state,
  actual ledger and object/body/ACL inventory read-only. A failed transactional file should
  leave none of its objects/ledger entry; prove this rather than guessing. Prior files may
  already have committed. Do not rerun the whole batch, delete ledger entries or mark it applied.
- If the cause is environmental and the exact failed file rolled back completely, inspect
  compatibility again and obtain authority for the exact remaining suffix before retrying
  unchanged bytes. A source defect requires a separately reviewed forward repair; never
  edit a migration already applied or expose a partially secured completion path.
- Prefer a forward restriction on **new v3** publication/starts, preserving immutable
  definitions, retirements, evidence, consent, snapshots, completion and actuals. A specific
  incident plan must identify the relevant public start overload/wrapper, not assume that
  revoking only the two-argument overload blocks every new v3 start. Preserve supported
  owned frozen resumes and v1/v2 only where the inspected incident design proves safe.
  If consent withdrawal becomes unavailable, block future v3 starts as well. No downgrade.
- Producer disablement, transport traffic/IAM changes, RPC revocation or a repair migration
  each require exact target-specific incident authority. The live legacy import service
  has no implemented v3 route to toggle today. Avoid destructive down migrations, history
  recalculation, source deletion, restore/backfill or compensating athlete writes.
- Only release the hold after approved forward repair and full affected postchecks, or a
  separately approved safe restricted state. Never claim availability from a ledger entry.

## E. Separate later approvals, deliberately outside schema deployment

Operational project resumption; schema-only missing-file batch; trusted producer identity/
credential/capability provisioning; verified publication-event implementation; HTTP facade
wiring/deployment and pinned configuration; exact definition/artifact/content approval and
publication; real programme assignment; client distribution and founder/device acceptance
are distinct actions. [PROVISIONING](PROVISIONING.md) lists their prerequisites and decisions.
No new architecture choice is manufactured to replace the accepted contracts.

## Evidence reuse and remaining uncertainty

The published 55c38bb checkpoint's 991 affected tests, fresh/repeat authenticated app →
repository → SQL chain, 129 API/race assertions and 136 vectors per pass, six safety groups,
analysis and terminal builds remain exact prior local evidence. All eight retained raw-log
hashes match the committed verification manifest in this task. Runtime/migration source is
unchanged. No new findings justify re-running full regressions/builds merely for read-only
preflight. New SQL here is prepared inspection text and has **not** been executed/validated
against the inactive hosted catalogs. No local fixture can fill the missing hosted ledger
or producer/artifact proof. This plan remains blocked until the active read-only gate passes.
