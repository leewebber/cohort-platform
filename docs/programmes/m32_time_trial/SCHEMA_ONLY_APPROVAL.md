# M3.2 schema-only deployment approval

The migration source is `ec21aa448ecb823a663fd60dbf80dba1085e9e5f`. The release review adds documentation only, and signed build 1.0.0 (12) remains tied to the exact app source in that commit. [Trial and migration pins](TRIAL_PINS.json) · [Disposable replay](LOCAL_DB_PROOF.json)

## Exact approval wording

> I confirm Cohort, Studio and import clients are closed for this window. I approve deploying only `20261108130000_approved_strength_time_options.sql` from the reviewed M3.2 release containing `ec21aa4` to Field Manual `otnhhdxstdnwccehacku`, SHA-256 `a55b63fbf79eca1e2d37bc376668bda75c371b93aac5fd86a2eaf14dbe8e68cc`.
>
> I authorise one fresh temporary read-write `cli_login_postgres` / `postgres` login through the established session-mode route. Task use ends 30 minutes after issuance or at earlier provider expiry. No replacement is authorised. Prepare before issuance. Freshly verify the published source, project identity and health, writer drain, exact ordered ledger 138, migration and connection pins, expected schema, and protected state. Proceed only if the dry-run on that same connection lists this migration alone and at least 90 seconds remain for apply and readback.
>
> Apply once and verify the exact ordered ledger 139, the new empty approval table and exact RPC grants, unchanged protected state and an empty final dry-run. Stop and reconcile on drift, insufficient reserve or failure. Close task-owned connections, revoke the login through the supported endpoint, verify zero task roles and backends, and remove temporary secrets. This approval is schema-only. Trial publication, eligibility, assignment, installation and athlete-data writes remain separate.

## Required checks

- Confirm the established verified TLS session listener on port 5432, database system identifier `7656985631720456337`, exact role and membership, and actual provider expiry. Start from a fresh unlinked deployment copy with the 138 pinned source files and the new migration. Exclude `20261026120000_durable_publication_approval_events.sql`. Freshly compare the 138 hosted rows by ordered version, name, statement count and statement-array SHA-256. Require the three new objects to be absent. Record auth settings and the current protected programme, assignment, History, catalogue and eligibility fingerprints before applying.
- The next ledger entry must be `20261108130000`, `approved_strength_time_options`, ten statements, statement-array SHA-256 `5a02fa26b316849d6dbbd6468d3cb6afd4f6e6ceaf1904a94dc6bfcace92531b`. Verify the earlier ledger entries exactly and require a final dry-run with no pending migrations.
- Require `programme_strength_time_approvals` to be empty, RLS-enabled, protected by the immutable trigger, and without direct grants to PUBLIC, anon, authenticated or service_role. Verify the source-pinned SECURITY DEFINER functions and `search_path=pg_catalog, pg_temp`. Among API roles only service_role can execute `publish_private_strength_time_option_v1(jsonb,jsonb)`, and only authenticated can execute `read_my_approved_time_option_v1(uuid,uuid,uuid,text)`. Read back the protected fingerprints. Use SELECT-only postchecks and release the writer hold after reconciliation and client readiness.
