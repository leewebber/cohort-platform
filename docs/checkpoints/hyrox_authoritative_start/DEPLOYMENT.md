# Deployment and recovery procedures — prepared, not executed hosted

No hosted inspection, permissions change, migration apply, real publication/assignment,
benchmark, consent or session write occurred. [Exact bytes/order](MIGRATIONS.json).

1. Obtain separate target-specific founder deployment authority and verify the project,
   connection identity, ledger, current function bodies/default grants, RLS and role graph.
   Run [PREFLIGHT.sql](PREFLIGHT.sql) read-only only under that authority. Initial deployment
   requires the three new schemas/ledger versions absent. Already present or partial state
   requires inspection, not manual ledger repair or blind rerun. Compare protected published
   artifact/canonical/snapshot digests with an approved preflight inventory.
2. Verify the complete prerequisite chain. The five security migrations `20261007120000`,
   `20261007130000`, `20261008120000`, `20261008121000`, `20261009120000` precede the two
   `20261022120000`/`20261022121000` prerequisites. Earlier checkpoint deployment claims are
   dated; current hosted state was not inspected. Do not silently bundle pending prerequisite
   files into an approval for this milestone. Use the full committed ordered migration
   inventory and verify exact bytes/ledger, including B2/C2 and canonical ownership guards.
3. Apply the approved exact additive files, in order: `20261023120000` retained exercise
   versions/retirements/approved dependencies, `20261023121000` strict private publication,
   then `20261023122000` review/consent/canonical start. Each is transactional. Review the
   dedicated producer role's existing attributes and every membership; unexpected authority
   aborts. No role default privileges are broadened. No real definition or programme is seeded.
4. Verify exact migration ledger/order/hash and run [POSTCHECK.sql](POSTCHECK.sql). Compare
   old canonical private body hashes, existing public overload/function IDs and effective
   grants to preflight. Verify no PUBLIC/anon access, no service athlete commands or version
   registration, no orphan publication claims, RLS and immutable/restrictive retention links.
   Record old v1/v2/B2 artifacts and snapshots unchanged using read-only approved checks.
   Do not create real athlete data to demonstrate a postcheck.
5. Keep v3 client/server rollout disabled until an actual authorised publication producer,
   verified exact approved definition artifacts/events and explicit exercise-to-kind approvals
   are available. Provision the NOLOGIN capability only to a separately reviewed trusted
   backend identity, with minimal membership and credentials never in app/service payloads.
   The ordinary service role can resolve/publish programmes, not register definitions. The
   current catalogue cannot be backfilled without demonstrable exact version/provenance.
6. Configure the Founder-authenticated v3 facade on the trusted publication host; no HTTP
   route was auto-enabled. Transfer/consolidate approved programme content, compile every
   actual supported source and obtain required publication approval. Unsupported package
   shapes remain refused pending separately reviewed additive support. Mount authenticated
   review/selection/replacement/withdrawal and canonical-token propagation in the app; render
   and capture frozen targets through existing runners. Complete device/native/browser and
   four-phone checks under separate authority. No device distribution is part of this task.

## Recovery

Prefer a forward restriction over destructive rollback. Under explicit incident authority,
disable the v3 publication route/client feature; revoke EXECUTE on
`publish_private_exact_programme_version_v3(jsonb)` and, if needed, the new two-argument
public occurrence-start overload and review/consent commands. Keep the existing one-argument
canonical entry available for v1/v2 and already frozen owned resumes, subject to the incident
plan. If disabling consent commands, record that withdrawal is temporarily unavailable and
block future v3 starts as well. Disable the producer capability without deleting versions.

Retain all immutable published versions, retirement events, programme artifacts, evidence,
corrections, consents and started/completed snapshots. Never delete ledger rows or restore
old snapshots by rewriting history. For an interrupted file, inspect transaction and ledger
state before retrying exact bytes. Defective future rules require new explicit rule/contract
versions and fresh consent, never mutation of accepted history. Restoring old function entry
points requires an inspected forward migration, preserved body/ACL equality and regression
proof. No destructive down-migration or hosted restore has been performed.

Local proof includes full fresh/repeat migration replay, metadata scripts, privileged mutation
refusals, actual-role HTTP isolation, canonical rollback after injected snapshot failure,
completed historical preservation and deterministic evidence/consent/source/version races.
This is disposable local proof, not production persistence deployment evidence.
