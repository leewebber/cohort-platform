# Refreshed package for one later live attempt

**Prepared locally only. No live preflight, credentials or apply authorised here.**
The former single login was consumed/revoked. This document does not request or
issue another one. D8 and programme publication remain separate.

## Fixed inputs and collision policy

SHA256.json pins the changed operator/test code, unchanged exact WRITE_SET.json,
unchanged OPERATION_REQUEST.json and selected strength source, unchanged state
query, decisions template and synthetic rehearsal manifest/seed/receipts.
No live ID, live manifest/seed or new genuine trust pin is assigned by this package.

The template deliberately has null exact_setup_review_reference values: it cannot
prepare until fresh actual candidate review is referenced. The action is create
only for an unchanged no-exact-match inventory; the tool refuses if an exact
existing target now requires explicit reuse review. No movement/dose approval repeats.
Any required extra field or unexpected target/schema/identity drift stops the batch.

Existing exercise IDs must remain globally unique under the actual primary key.
Existing unrelated duplicate slug groups remain fully pinned protected pre-state.
Each chosen target slug must have no lookup-equivalent existing row for creation,
or exactly one row matching the reviewed reused ID. Collision-only edge trimming
conservatively includes whitespace/BOM; no case folding, fuzzy identity matching
or slug-based source binding is introduced.

## Before any future credential issuance

1. Verify current source/live main ancestry and pinned operation/request bytes.
   Keep older worktrees/dirty files/indices/.temp/backups intact.
2. With separately authorised access, verify exact Field Manual target
   otnhhdxstdnwccehacku, healthy services and the normal approved connection.
   Resolve the public CA, psql PATH and verify-full service configuration first;
   use task-owned secure files, no shared trust-store or global setting changes.
3. Confirm one-login scope, actual principal/existing role, exact expiry/closeout
   procedure and absence of unrelated CLI sessions before issuance. Use at most
   30 minutes from issuance or earlier provider expiry; no automatic replacement.
   The previous provider TTL was 300 seconds, not 30 minutes.
4. Capture fresh full catalogue/schema/constraints/indexes and five consumer guards
   through the normal authenticated connection. Compare the previously retained
   evidence without relabelling it current. Resolve any unexpected drift before
   proceeding; do not use the local rehearsal or expired former authorisation.

## Normal operator initialization and fresh preparation

The adapter now selects the role explicitly from the pinned manifest. During
preflight the reviewed normal operator connection must similarly use:

    db = m11_setup_operation.Psql(APPROVED_SERVICE_ALIAS, role=ACTUAL_REVIEWED_ROLE)
    raw, state = m11_setup_operation.inspect_state(db)

This sends fixed, quoted SET ROLE before queries through the service's existing
membership. It creates no grants. Do not rely on pooler startup role options.
Verify actual session principal/current role, DB/system/server identity, TLS and
native expiry. Snapshot classification is AUTHENTICATED_OPERATOR_PREFLIGHT with
exact raw_state bytes, actual provenance/audit reference and timezone-aware expiry.
Do not copy the synthetic snapshot's identity, expiry or consumer fixture digests.

Complete DECISIONS.template.json against that fresh full inventory, retaining the
three exact source meanings and all null/unknown optional fields. Protect EX-026/
037/090. Neither EX-029 nor EX-141 is a lookup/binding dependency of this batch;
neither can be edited, renamed, merged, deleted or rebound.

Generate a NEW output directory using the unchanged command interface:

    python3 tool/catalogue/m11_setup_operation.py prepare --snapshot FRESH_AUTHENTICATED_SNAPSHOT --decisions REVIEWED_DECISIONS --request-id ONE_STABLE_REQUEST_ID --out NEW_PREPARED_DIRECTORY

Review its exact manifest/seed SHA-256, target, principal/role and remaining
lifetime BEFORE apply. Those live digests cannot be known from this local task.

## Apply, retention, recovery and closeout

Use only the generated seed and manifest with their newly reviewed hashes and the
normal approved libpq service, through the documented apply/verify-retain commands.
The tool derives SET ROLE from manifest.operator_authorisation.role; there is no
free-form role/SQL/DSN CLI option.

The unchanged transaction takes EXCLUSIVE on exercises_v2 and SHARE on the five
fixed consumers; lock timeout 5 seconds, statement timeout 60 seconds. It rechecks
every pre-existing row, exact schema/indexes/constraints and consumer guards before
and after insertion, forces deferred effects, and aborts any unexpected change.
Therefore an added or changed duplicate member or target lookup alias since prepare
is rejected under lock even when the alias is outside the three proposed raw slugs.
No new unique constraint, migration or permission change is needed.

Exact same-operation retry is a no-op audit case. Partial/mismatched state refuses.
Unknown acknowledgement never permits new IDs: preserve the pinned operation and
independently read back/audit the same IDs. Do not compensate with deletes, allocate
replacement identities, or use ON CONFLICT UPDATE.

Retain actual raw preflight/apply/independent readback and normal operator audit;
verify every old row, all five consumer counts/digests, exact new/reused rows and
unchanged duplicate groups. Use the newly pinned receipt/query/file/row hashes.
The state query and receipt format are unchanged; no version/event is manufactured.
Only genuine authenticated retained evidence may receive an independent Studio
trust pin and support later exact-bound revisions/explicit occurrence selection.

Stop using the login at completion or its earlier deadline. Close task clients and
check any idle pooler backends separately. Remove temporary secret material. Use
supported revocation only after confirming no other operator is affected; verify
zero task backends and the resulting credential state. Do not equate local deletion,
task timeout or client exit with provider expiry/revocation.

Then attempt complete local strength admission from genuine rows. Programme D8,
publication/access, held schemas and the installed real-programme journey remain
separate. Nothing here closes M1.1 or Gate A.
