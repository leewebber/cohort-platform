# M1.2 End programme deployment proposal

This is the controlling deployment proposal for the reviewed End programme release. The retained m12_end_programme_review directory is the original review snapshot. Its source, evidence and two corrections are preserved byte for byte. Deployment and installed transition acceptance remain pending. M1.2 and Gate A stay open.

The approved integration source is implementation commit `c02a050442e988aa7b90e70734bd01173d08f6aa`. Its only proposed migration is `supabase/migrations/20261107120000_athlete_end_fixed_programme.sql`, SHA-256 `0bf399e24c589d443aefc9a54a8fdb8578dd67544905a85b8243273ac6db5282`. The release documentation commit descends from that implementation and preserves its application and migration bytes. [Machine-readable pins](PACKAGE.json)

The migration adds nullable `ended_at`, its inactive-state constraint and protected terminal-marker trigger, plus `end_my_fixed_programme(uuid,uuid,uuid)` with owner-authenticated execution. Only that exact assignment can change status to paused and receive its immutable end marker. Exact completed History, existing session-start/completion authorities and acquisition's one-active rule remain preserved. Non-read-committed end transactions refuse. The app handles an uncertain response with Reload and retains acknowledged success if refresh fails.

## Required authority and connection

Approval must cover this one migration and one new temporary read-write CLI login through the existing Field Manual Management `/cli/login-role` endpoint. The expected session user is `cli_login_postgres`, with its existing non-inherited SET ROLE postgres membership. Previous login authorities are consumed and closed. The publication service key is outside this deployment route.

Expected target is **Cohort Field Manual `otnhhdxstdnwccehacku`**, database system identifier `7656985631720456337`. Use the existing session pooler `aws-0-eu-west-1.pooler.supabase.com:5432`, database postgres, verify-full TLS and the retained CA. The temporary connection username includes the verified project suffix. Fresh endpoint, membership and provider-expiry verification must pass. The pooler's transaction listener on 6543 is excluded from this package.

Task use ends 30 minutes after issuance or at earlier actual provider expiry. Preserve at least 90 seconds of execution/readback reserve before apply and bound commands to that deadline. No replacement login is included. Password stays in child-process environment, with a password-free CLI URL. No credentials enter chat, logs or Git. Keep the client hold until successful reconciliation and client compatibility checks.

## Preparation before issuance

1. Verify published main ancestry and every PACKAGE.json pin. Retain the reviewed fresh/repeat race, History, owner-scope and single-migration readback proof. The installed Supabase CLI is 2.109.1 with SHA-256 `b7be23f4e211b75c00a3df5fcd1f96f3905983c74ff3189bfc69ad5b0f7132c4`, identical to the successful retained session-mode proof. CLI/CA changes require offline preparation before any login.
2. Use the existing Management connection to freshly verify project ID, name and ACTIVE_HEALTHY, with all required services healthy. If inactive or unhealthy, stop. Obtain a fresh explicit acknowledgement that Cohort and Studio/import writers are closed, then verify observed drain and absence of unexpected CLI roles/backends or prepared transactions.
3. Re-read all **135** hosted migration entries through `20261104120000`. Compare ordered version, name, statement count and statement-array SHA-256 exactly with retained LEDGER_AFTER.json and ORDERED_LEDGER_PROOF.json. Preserve the four historical local-replay representation differences through their retained hosted hashes. This baseline has not been re-read during release preparation.
4. Require the new column, constraint, trigger and both functions to be absent. Compare current existing owner/auth guards, canonical/generic starts, completion, acquisition, assignment triggers/constraints/unique-active indices and ACL/RLS against the pinned source and retained hosted authority evidence. Require read-committed defaults and no conflicting authenticated/authenticator role/database override. Stop on unexpected drift.
5. Re-read the bound application identity and exact Bali assignment from PACKAGE.json. Require an email-confirmed athlete, that exact materialised fixed Bali pin active, one total active pin, zero Hybrid assignments and the retained published Hybrid version/scope seal. Capture current protected row counts/hashes, including all completed History child rows and recipient eligibility. Current legitimate training history becomes the deployment baseline. Earlier athlete snapshots must never be restored.
6. Read back the accepted native allowlist union and retain a comparison fingerprint of other auth settings in memory. This deployment proposes no auth-setting write. Prepare the final apply/postcheck commands and all comparisons before issuance.
7. Create a new task-owned offline deployment copy using the script below. It extracts exactly the 135 pinned baseline source files plus this migration from the implementation commit and verifies every hash. It excludes the deferred HYROX producer and never copies .temp or links a project. The copy must contain exactly 136 migration files. The script was exercised successfully and refuses an existing destination.

```sh
python3 docs/checkpoints/m12_end_programme_release/prepare_deployment.py /private/tmp/<new-task-owned-directory>
```

## Fresh operator checks and exact apply

After separately authorised issuance, independently verify the connection identity, database system identifier, role attributes, exact existing membership, TLS and provider expiry. Repeat the pinned read-only inventory and protected-state capture through that same session route. Bind the non-secret psql variables from PACKAGE.json. Use private PG connection variables, PGPASSWORD and PGOPTIONS selecting the existing postgres role. Use a unique task application name for later backend closeout.

```sh
psql -X -v ON_ERROR_STOP=1 \
  -v athlete_id=79853f15-eac4-42eb-acfd-384bf2a87976 \
  -v bali_assignment_id=d665e909-d946-414b-986e-8b47f40cd44d \
  -v bali_version_id=b1a1b001-0000-4000-8000-ba11b0010001 \
  -v hybrid_version_id=b0290b33-2764-4e5b-ad78-3d4beafbb375 \
  -f docs/checkpoints/m12_end_programme_review/VERIFY.sql
```

VERIFY.sql uses a consistent read-only evidence snapshot. The mutation RPC's read-committed requirement is independent of that read-only snapshot. Supplement it with the project/health, native-auth, operator-identity and protected publication/catalogue checks above through the existing Management read-only route. Do not invoke the end RPC as a deployment smoke test.

The CLI URL is password-free, explicitly selects the same session host/port/project/user and verified TLS settings, and uses the same one login as the readback connection. It must not use linked-project automatic issuance.

```sh
supabase db push --db-url "$COHORT_SESSION_DATABASE_URL" --workdir "$COHORT_END_DEPLOY_COPY" --dry-run
supabase db push --db-url "$COHORT_SESSION_DATABASE_URL" --workdir "$COHORT_END_DEPLOY_COPY" --yes
```

Require the successful dry-run to list **only** `20261107120000_athlete_end_fixed_programme.sql`. Check the 90-second execution/readback reserve immediately before the second command. Send apply once. Any error or unclear acknowledgement stops further mutation and requires independent read-only reconciliation before a new decision.

## Required postchecks and closeout

1. Repeat VERIFY.sql and the independent Management reads. Require **136** hosted entries, with the original 135 entries exact and one new version `20261107120000`, name `athlete_end_fixed_programme`, nine statements and statement-array SHA-256 `0cab6ff74fac859c2301a4be7a45b40a99d1353822a3824638791e3f3aa54bc7`.
2. Require the new function definition hashes in PACKAGE.json. Both functions are postgres-owned, volatile and use pg_catalog/pg_temp search_path. End is SECURITY DEFINER and executable by authenticated and its owner. The trigger function is SECURITY INVOKER and owner-executable only. PUBLIC, anon and service_role EXECUTE must be absent. Preserve all existing function bodies/owners/ACLs and assignment table policies/ACLs/indices/triggers/constraints.
3. Require nullable timestamptz ended_at without a default, the validated inactive-state constraint and the enabled trigger. Every existing ended_at remains null. Protected data counts/hashes must equal fresh preflight, with assignment fingerprints omitting only the new null column. Exact Bali remains active, Hybrid assignment count stays zero, and publication/recipient state, catalogue and auth settings match the fresh preflight.
4. Run the same scoped CLI dry-run and require an empty pending set. Retain genuine readback and integrity evidence. A failed or time-limited check requires reconciliation, with the hold maintained until its outcome is established.
5. Close task-owned connections. Revoke the one login with supported Management DELETE `/cli/login-role`, targeting only the verified task capability. Verify zero task roles/backends independently and remove temporary credential material. Record actual expiry/revocation. A task-use deadline alone does not establish credential expiry.
6. Release the client hold only after exact schema/data reconciliation and compatible-client readiness. Build 8 remains compatible with this additive schema. Build 9 exposes End programme. Studio/import contracts are preserved. Programme authoring and discretionary UI polish remain frozen.

## Exact approval wording

> I approve only `20261107120000_athlete_end_fixed_programme.sql` at SHA-256 `0bf399e24c589d443aefc9a54a8fdb8578dd67544905a85b8243273ac6db5282` from the published M1.2 release package for Field Manual `otnhhdxstdnwccehacku`. I authorise one fresh temporary read-write CLI login through the existing cli_login_postgres / postgres session-mode route, limited to 30 minutes from issuance or earlier provider expiry, with no replacement. Freshly verify the exact ledger-135 baseline, protected state and hashes. Proceed only if dry-run lists that one migration and the 90-second reserve remains. Apply once, verify ledger 136 and all postchecks, revoke, verify zero task roles/backends and remove temporary secrets. Deployment includes no end-programme RPC, acquisition, publication, recipient or athlete-data writes. I will confirm the client hold for that deployment window.

## Signed build and the next installed step

The existing release wrapper produced signed **1.0.0 (9)** from implementation commit c02a050, with production Field Manual configuration, the existing anon client key, exact native callback and internal tools disabled. Deep strict signature verification, embedded current profile, certificate, team, bundle/version and release AOT checks passed. The registered device set matches the profile embedded in the previously installed build 8. Profile expiry is **2026-11-13 11:20:51 UTC**. [Build receipt](BUILD_RECEIPT.json)

The artifact is `/private/tmp/cohort-m12-release.kwq3ZsxY/source/build/ios/iphoneos/Runner.app`. It has been built and verified locally. Manual installation/launch and End programme acceptance remain pending. After successful approved deployment, Lee can use the existing Xcode Devices and Simulators Installed Apps route to install that exact Runner.app and launch Cohort manually. Programme → End programme → Keep programme verifies cancellation first. Any subsequent end requires Lee's deliberate confirmation, followed by a read-only verification of the inactive Bali pin and retained History before his independent Hybrid 10K acquisition.
