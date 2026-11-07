# M1.2 End programme local review

Reviewed on 2026-11-07 in an isolated candidate based on a63e2c8. Hosted deployment, ending Bali and acquiring Hybrid 10K await separate action. M1.2 and Gate A remain open. Founder coaching acceptance and the discretionary authoring UI freeze remain recorded in the existing checkpoints.

## Findings and bounded corrections

The RPC pins auth.uid(), expected athlete, assignment ID and version. It requires the athlete role and an active materialised fixed assignment. Cross-owner and wrong-version requests refuse. Authenticated users receive only the exact RPC EXECUTE grant. PUBLIC, anon and service_role EXECUTE are revoked. The end timestamp is guarded against direct updates, including an authenticated caller setting the materialisation GUC.

The operation shares acquisition's per-athlete advisory lock and locks the exact assignment row FOR UPDATE. Existing canonical fixed and generic starts hold that same row through session/outcome creation. If start wins, end sees its committed in-progress outcome/session and refuses. If end wins, start reads an inactive assignment and refuses. Existing linked performance drafts also block ending.

A nondefault repeatable-read transaction could keep the pre-start session snapshot after waiting for an assignment that start only locked. The new RPC now fails closed unless transaction isolation is read committed. The default API connection configuration must be freshly checked before deployment. PostgreSQL documents the snapshot distinction. [Transaction isolation](https://www.postgresql.org/docs/current/transaction-iso.html)

The RPC writes only the selected assignment's status and ended_at. The existing timestamp trigger also updates updated_at. The stored status is paused for compatibility with build 8's inactive-status readers. The immutable ended_at marker and constraint keep this end terminal. No completed_at is fabricated. A replay returns success for that same already-ended pin and preserves its original timestamp. It never looks up a replacement active assignment. Completed sessions, records, blocks, exercises, sets, occurrence rows, outcomes and schedule projection remain retained.

The prior UI's generic error claimed unchanged training even after a possibly committed request lost its response. End now uses neutral uncertainty wording and a read-only Reload action. An acknowledged success remains a success if later surface refresh fails. Feedback and reload are checked against the initiating athlete identity.

## iPhone flow

Programme → Current programme → End programme opens a confirmation naming the current programme. It says “End [programme name] as your active programme? Your completed sessions will stay in History.” Keep programme cancels without an RPC. End programme submits the exact current pin once and disables duplicate submission.

After acknowledged success, “Programme ended.” appears and the shell's authoritative Programme, Home and Calendar surfaces reload. Current programme clears and View programmes is available. History retains completed records. Acquisition remains an independent athlete choice.

An in-progress refusal says “Finish your in-progress session before ending the programme.” The active pin stays visible. An already-inactive refusal says “This programme is no longer active.” and offers Reload. A session-expiry refusal asks for sign-in. Unknown/transport failure says “Couldn’t confirm whether the programme ended. Reload Programmes to check.” Reload rereads state and never resends end. A refresh failure says “Couldn’t refresh Programmes. Reopen it to check.”

These are source/widget and actual local backend results. iPhone acceptance of build 9 remains pending.

## Exact deployment proposal

Target is Field Manual otnhhdxstdnwccehacku. The only proposed migration is [20261107120000_athlete_end_fixed_programme.sql](../../../supabase/migrations/20261107120000_athlete_end_fixed_programme.sql).

Its SHA-256 is `0bf399e24c589d443aefc9a54a8fdb8578dd67544905a85b8243273ac6db5282`. It adds one nullable ended_at column, an inactive-state constraint, a terminal-marker trigger/function and one owner-authenticated RPC with scoped EXECUTE ACLs. Existing session-start, completion, acquisition, permissions and content definitions remain unchanged. No data-backfill statement is present.

[PACKAGE.json](PACKAGE.json) binds the identities, hashes, expected new ledger row and function definitions. [VERIFY.sql](VERIFY.sql) is executable SELECT-only preflight/postcheck SQL. It never calls the mutation RPC. Its repeated-read read-only snapshot is for evidence capture. The end RPC itself requires read committed.

### Before approval is exercised

1. Hold athlete and Studio/import writers closed. Verify exact project ID/name and ACTIVE_HEALTHY through the existing authorised Management route. Credential issuance requires a separate explicit scope and duration if a new CLI login is needed.
2. Check every package hash. Compare all 135 ordered hosted migration entries by version, name, statement count and statement-array hash to the retained LEDGER_AFTER.json and ORDERED_LEDGER_PROOF.json in m11_callback_a76c7cd_2026_11_05/evidence. The earlier source pins all match this candidate. Their historical statement-array differences remain preserved.
3. Create a disposable deployment copy containing only those exact 135 source files plus this one migration. Exclude the deferred HYROX producer. Preserve every existing checkout, .temp and backup. Expect 136 files.
4. Run VERIFY.sql against the verified connection with the exact PACKAGE.json identities. Require the verified athlete, exactly one exact active Bali assignment and one total active assignment, zero Hybrid assignments, the retained published Hybrid version/scope seal and unchanged recipient eligibility. The end column/function/trigger/constraint must be absent before apply. Existing owner/auth guards, start lock paths, table triggers and unique-active indices must match the reviewed source and retained authority evidence. Require read-committed defaults with no role/database override to another isolation level.
5. Capture current protected-state fingerprints before applying. Resolve unexpected identity/schema/authority drift before any mutation. Current activity history must be retained as the apply baseline. Never restore an older athlete snapshot.
6. On the exact approved session-mode connection, run the CLI dry-run. Require only 20261107120000_athlete_end_fixed_programme.sql. Use that same connection for apply. Check the credential execution/readback reserve before proceeding. No all-pending apply against the normal checkout.

After a separately approved login is prepared, these commands use its in-memory environment variable. Never print it or enable shell tracing.

```sh
supabase db push --db-url "$COHORT_SESSION_DATABASE_URL" --workdir "$COHORT_END_DEPLOY_COPY" --dry-run
supabase db push --db-url "$COHORT_SESSION_DATABASE_URL" --workdir "$COHORT_END_DEPLOY_COPY" --yes
```

Bind the non-secret variables from PACKAGE.json for both preflight and postcheck. The private PG connection environment must point to that same verified session-mode route.

```sh
psql -X -v ON_ERROR_STOP=1 \
  -v athlete_id=79853f15-eac4-42eb-acfd-384bf2a87976 \
  -v bali_assignment_id=d665e909-d946-414b-986e-8b47f40cd44d \
  -v bali_version_id=b1a1b001-0000-4000-8000-ba11b0010001 \
  -v hybrid_version_id=b0290b33-2764-4e5b-ad78-3d4beafbb375 \
  -f docs/checkpoints/m12_end_programme_review/VERIFY.sql
```

### Required postchecks

- Exact original 135 ledger rows unchanged, plus version 20261107120000 named athlete_end_fixed_programme, nine statements, statement-array SHA-256 `0cab6ff74fac859c2301a4be7a45b40a99d1353822a3824638791e3f3aa54bc7`. The resulting hosted ledger count is 136.
- New function definitions match PACKAGE.json. Both are postgres-owned. End is SECURITY DEFINER, volatile, search_path pg_catalog/pg_temp and authenticated-executable only apart from its owner. The trigger function is SECURITY INVOKER and owner-executable only. PUBLIC, anon and service_role cannot execute either function.
- ended_at is nullable timestamptz with no default. The inactive constraint is validated and the end trigger is enabled. All existing function bodies/owners/ACLs, indices, assignment triggers and constraints remain identical.
- VERIFY.sql's protected data counts/hashes remain identical. Assignment hashes intentionally omit the newly added null column. Every ended_at is null after deployment. Exact Bali remains active, Hybrid assignment count remains zero, and publication/access state stays unchanged.
- Repeat the scoped CLI dry-run and require no pending migration. Reconcile partial/unclear results before any retry. Close task-owned connections, revoke any separately approved temporary login through the supported endpoint, verify zero task roles/backends and remove its temporary secrets.
- Release the writer hold after successful reconciliation and compatible-client readiness. Existing build 8 remains compatible with the additive schema. Build 9 is required for End programme. Studio/import source contracts are unchanged.

Deployment approval must authorise only this pinned migration and its verification. It does not authorise invoking end, acquisition, recipient changes or any programme publication.

## Next iPhone build and acceptance

Next candidate is 1.0.0 (9), using bundle uk.cohortperformance.cohort, the existing signing route, verified Field Manual configuration and internal tools disabled. The retained build 8 artifact metadata confirms 1.0.0 (8). No build number or signing setting was changed in this review and build 9 has not been produced.

After reviewed integration, approved deployment and a signed build 9, Lee installs and launches it manually. He verifies the confirmation and Keep programme cancellation first. Any actual end is then his explicit confirmed iPhone action. Verify the inactive pin and retained History read-only before he independently chooses Hybrid 10K and taps Get programme — free. An active session should produce the blocked message. A transport failure requires Reload before another decision.

## Evidence

The earlier candidate's 16 focused tests, zero changed-file diagnostics, six safety groups and fresh/repeat local authenticated acquisition/history proof are retained prior-task evidence. The architecture safety suite was not repeated for these bounded changes. Current review adds widget blocked/lost-response/reload tests, true two-transaction canonical start/end races in both orders, a repeatable-read refusal and executable migration preflight/postcheck rehearsal. Final task results are retained in [VERIFICATION.json](VERIFICATION.json). Thirteen focused unit/widget tests pass, with zero diagnostics across the four changed Dart files. The final fresh/repeat authenticated gates also cover mismatched expected-athlete identity, denied direct end-marker updates and exact preservation of completed blocks, exercises and sets. [Local postcheck readback](LOCAL_POSTCHECK_READBACK.txt)

The single-migration local CLI rehearsal applied only the proposed file and matched exactly the expected five schema/function additions in VERIFY.sql. It preserved all earlier local ledger rows and existing inspected functions, constraints and triggers. This is disposable local deployment evidence.

The candidate remains uncommitted and unpushed at a63e2c8. Existing original checkouts, indices, refs, dirty work and .temp are preserved. No hosted or device control occurred.
