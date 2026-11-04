# Exact three-setup operation — offline implementation

> **Authorised attempt, 2026-11-04:** [inactive-target stop and credential closeout](inactive_target_2026_11_04/HANDOFF.md)
> record fresh Field Manual **INACTIVE**. The specific single-login authority is
> granted but unused: no issuance, database query, apply or new retention/admission.
> Resume needs separate hosted-state authority; then rerun fresh preflight. The
> previous access question below is satisfied, and its evidence stays historical.

> **2026-11-04 continuation:** [bounded founder acceptance and actual access outcome](operator_connection_2026_11_04/HANDOFF.md)
> freeze discretionary authoring UI polish. The operation/rehearsal below are unchanged.
> No usable existing connection was identified; the prior deployment login was expired
> and removed. [Specific temporary-login decision](operator_connection_2026_11_04/ACCESS_DECISION.md)
> names the established route, access scope and one exact founder action. No issuance,
> apply, genuine retention or new strength admission occurred. D8/M1.1/Gate A stay open.

Status: **IMPLEMENTED_AND_LOCALLY_REHEARSED; CONNECTION_UNPROVISIONED;
NO_HOSTED_APPLY_OR_RETENTION.** Scope remains the [approved operation](../m11_founder_authoring/CATALOGUE_CAPABILITY.md).
[OPERATION_REQUEST.json](OPERATION_REQUEST.json) retains the exact three intents,
source/write-set hashes, protected leads and logging contracts. It intentionally
contains no assigned real IDs and no invented executable hosted seed.

## Delivered operation

`tool/catalogue/m11_setup_operation.py` implements `prepare`, `apply`,
`verify-retain`. With no snapshot, prepare writes the fixed offline request. With
a complete operator snapshot and three explicit reviewed decisions, it produces
canonical manifest JSON, data-only SQL and SHA-256 pins. No arbitrary SQL/DSN mode,
Management API route, schema DDL, permanent writer, grants or credential search exists.

The fresh complete inventory supplies EX-number allocation. Name matching is never
identity authority. Exact setup/equipment/execution fields and explicit owner review
control reuse; null/ambiguous/conflicting fields refuse. Protected EX-026/037/090 are
never updated, deleted or repurposed. No bridging mappings or definition/event
versions are created. Optional taxonomy is left unknown; extra required fields need
an explicit reviewed field reference. The actual schema, PK and indexes are pinned;
slug uniqueness is also checked explicitly without assuming a unique slug index.

Apply takes exact reviewed manifest/seed hashes and the expected project. The
normal libpq service reference resolves credentials outside the tool; connection
strings/passwords are never accepted as arguments or logged. SSL `verify-full` is
enforced. Actual database, system identifier, server address/port, session principal,
effective role and SSL state must equal the authenticated preflight. Authorisation
names the actual principal/role, external review reference and timezone-aware expiry.
An expired scope refuses before writes. This wrapper does not narrow a privileged
operator role at the database server.

The transaction takes EXCLUSIVE on `exercises_v2`, excluding ordinary competing
INSERT writers even if they do not use advisory locks. It takes short SHARE holds
on the five protected consumer relations below. Lock timeout is five seconds;
statement timeout is sixty seconds. This hold/role contract is part of the later
reviewed operational scope, not an available hosted capability today. Only pinned
INSERTs occur. Exact absent state inserts; exact fully present state returns
`EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED`. Partial/mismatched/dedup/allocation or
pre-existing state drift refuses the entire batch. No compensating DELETE or
ON CONFLICT UPDATE is used. A timeout/failed process is an unknown outcome, not
permission to allocate another identity.

Readback retains raw preflight bytes, actual apply response, manifest, SQL,
independent raw readback and a receipt with separate file/canonical row digests.
All pre-existing catalogue rows, including null fields, and protected consumer
counts/digests must match. The five fixed protected relations are
`performance_protocols`, `session_blocks`, `session_block_exercises`,
`training_sessions`, `programme_assignments`; only counts/digests leave these
relations, with no athlete rows in receipts. No assignment, started/completed
prescription or actual is written. Retention uses exclusive file creation; earlier
evidence is never overwritten. Lost acknowledgements require same-ID replay,
independent readback and the normal external operator audit; exact matching rows
alone do not prove who created them.

The Studio reader requires an independently established receipt SHA-256 and audit
reference, exact target/source/write-set/raw-file/row bindings and genuine operator
classification. It rejects synthetic rehearsal. Its returned evidence retains legacy
rows with absent definition versions/events. No genuine operation trust pin is
installed in this build. Receipt installation invalidates review; existing revision
bytes remain unchanged, so binding a retained setup requires a later session draft
and explicit occurrence selection.

## Exact separate provisioning dependency

1. Name Field Manual `otnhhdxstdnwccehacku`, the authorised connection issuer,
   actual session principal and effective existing operator/owner apply role.
   Provision/identify a normal secure libpq service with certificate verification.
   If no approved connection exists, a separately authorised short-lived login,
   effective role membership, expiry and subsequent revocation must be reviewed.
   No app/anon/authenticated grant, reusable service secret or v3 activation follows.
2. Authorise identity/health/schema/constraint/index and full catalogue preflight,
   fixed consumer counts/digests, and the bounded holds above. The role must already
   be entitled to obtain server identity, inspect all catalogue rows and acquire
   these holds. Do not add UPDATE/DELETE merely to obtain a lock. If unavailable,
   report the exact role/lock delta for separate decision; no implicit DDL/grants.
3. Capture `state_sql()` through that normal authenticated connection and preserve
   its exact raw bytes. Snapshot keys are `kind`, `target_ref`, `provenance`,
   `operator_authorisation`, `audit_reference`, `state`, `raw_state`. Genuine kind is
   `AUTHENTICATED_OPERATOR_PREFLIGHT`; local proof uses `SYNTHETIC_LOCAL_FIXTURE`.
   `operator_authorisation` is exactly `principal`, `role`, `reference`, `expires_at`.
   The parsed state must equal raw JSON and contains actual identity/capture time,
   columns, constraints, indexes, rows and fixed consumer guards.
4. Review three decisions in the approved variant order. Each has exactly
   `source_variant`, `action` (`create`/`reuse`), `reuse_id` (null for create),
   `slug`, `exact_setup_review_reference`, `reviewed_extra_fields`,
   `field_review_reference`. Unknown fields or overriding fixed setup data refuse.
   Generate the final manifest/seed using the fresh inventory. Review and authorise
   their exact hashes, target, principal/role, expiry and hold window before apply.
5. Apply only that operation, independently verify/retain all raw results, establish
   the external audit/receipt trust pin, expire/revoke temporary access and verify
   expiry. Import genuine evidence locally and create later exact-bound strength
   revisions. Programme approval/publication/access/assignments remain separate.

There is no schema migration or endpoint deployment for this route. If the normal
deployment process requires a data-seed ledger record, authorise that one exact
ledger action separately; the tool does not silently write a ledger.

## Commands

Today, offline (use a new output path; evidence files are never overwritten):

```sh
python3 tool/catalogue/m11_setup_operation.py prepare --out /private/tmp/m11-request.json
M11_LOCAL_DB=1 python3 -m unittest discover -s tool/catalogue -p m11_setup_operation_test.py -v
```

Only after the separately authorised provisioning/preflight above:

```sh
python3 tool/catalogue/m11_setup_operation.py prepare --snapshot reviewed-snapshot.json --decisions reviewed-decisions.json --request-id m11-reviewed-request --out prepared-operation
python3 tool/catalogue/m11_setup_operation.py apply --manifest prepared-operation/manifest.json --manifest-sha256 REVIEWED_MANIFEST_SHA256 --seed prepared-operation/seed.sql --seed-sha256 REVIEWED_SEED_SHA256 --expected-target otnhhdxstdnwccehacku --service APPROVED_SERVICE_ALIAS --out apply-ack.json
python3 tool/catalogue/m11_setup_operation.py verify-retain --manifest prepared-operation/manifest.json --manifest-sha256 REVIEWED_MANIFEST_SHA256 --seed prepared-operation/seed.sql --seed-sha256 REVIEWED_SEED_SHA256 --expected-target otnhhdxstdnwccehacku --service APPROVED_SERVICE_ALIAS --apply-receipt apply-ack.json --out retained-operation
```

The last commands are instructions for a later authorised operator, not actions
performed here. Local tests use one uniquely named, network-disabled cached
PostgreSQL container, then remove only that task-owned container. They do not
establish live catalogue IDs, publication evidence or hosted retention.
