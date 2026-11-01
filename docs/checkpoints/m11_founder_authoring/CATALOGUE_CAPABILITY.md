# M1.1 — exact catalogue write/retention operation

2026-11-01. **LOCAL IMPLEMENTATION ALLOCATION ONLY; NOTHING PROVISIONED/APPLIED.**
This closes the planning gap behind “ask the catalogue owner”. It does not close the
technical capability gap. [Allocation](ALLOCATION.md) and the existing exact
[WRITE_SET.json](../m11_catalogue_setup_creation/WRITE_SET.json) control the content.
No repeat hosted lookup, credential search or credential issuance occurred here.

## Precise route determination

| Route inspected | Result |
|---|---|
| App `ExerciseRepository` / `ExerciseCatalogueService`, importer repository | SELECT/read routes; no create operation. |
| `ExerciseKnowledgePublicationService` | Owner checks and immutable publication semantics, but in-memory persistence only; `actingOwner: founder` cannot create genuine legacy hosted records. |
| v3 `exercise_publication_producer.dart` and approval/outbox package | Retains already genuine published definition/events for a different contract; does not create legacy `exercises_v2` identities and is not provisioned as this legacy writer. |
| Phase 3.1F data-only seed/apply | Established legitimate operator route, exact-row conflict/replay guards and retained pre/post receipts. Can be reused once an authorised operational DB apply connection is provisioned/identified. That connection is not established available now. |
| Read-only Management API/CLI authentication | Prior status/SELECT success proves those operations only; not a write capability. Unrestricted Management API SQL is excluded. |

Recommendation: **reuse the data-only catalogue seed/apply route, and build a small
operator-only prepare → apply → verify/retain adapter for this exact three-record
batch.** Provision its normal operational connection separately. Do not build a
permanent catalogue administration UI/service or activate v3 to solve three rows.
The database seed is a genuine producer operation when executed by its authorised
operator; generated local rows or a checked “published” UI box are not.

This route is provisionable in design, not currently usable or independently proved
provisioned. There is no evidence that a new general catalogue backend is required.
The missing build is the bounded, reviewable operation/receipt adapter; the missing
environment action is authenticated, authorised operator DB apply access. Neither
is supplied by founder ownership alone. If that access is unavailable, the result
remains capability-blocked with the exact ready operation retained; do not fall back
to generic SQL, assumed credentials or new permanent grants. An organisation that
cannot provision its documented operator route would need a separately allocated
server-enforced write endpoint; that larger implementation is not a hidden dependency
of the recommended seed route.

## Fixed semantic write set

| Selected setup | Required identity evidence | Protected insufficient lead |
|---|---|---|
| Bilateral chest-supported dumbbell row | Two DBs and chest support; no invented grip/bench angle | EX-090 |
| Seated supported neutral-grip DB shoulder press | Near-upright back support, two DBs, neutral grip, strict/no leg drive | EX-037 |
| Two-dumbbell reverse lunge | DBs at sides, neutral grip, one side then other; no added depth/stride/box | EX-026 |

All use source kg external load **per dumbbell**; lunge reps are per leg. These
programme logging conventions stay separate from identity and are verified at graph
binding. Do not copy sets/reps/RIR/tempo or actual loads into a catalogue identity.
Do not update/delete/repurpose the three protected IDs or historical consumers.
Prefer an owner-verified exact **distinct** existing identity, otherwise create a
real distinct identity. No ID, database key, version/event or timestamp is assigned
in this allocation. Do not guess the next EX number from the old 132-row catalogue.

## Concrete implementation package

Proposed paths (names are allocation targets, not existing executable commands):

- `tool/catalogue/m11_setup_operation.py`: operator command with `prepare`, `apply`,
  `verify-retain`. Strict three-operation allowlist, no arbitrary SQL/file execution
  mode, no query endpoint, default offline/dry. Use the existing reviewed data-only
  seed pattern and a normal operator DB connection. No UI/database credentials.
- `tool/catalogue/m11_setup_operation_test.py`: pure manifest/receipt guards plus
  disposable local database role, transaction, collision and recovery proofs.
- `docs/checkpoints/m11_catalogue_operation/`: implementation handoff, manifest/seed
  hashes, exact field/role/provisioning plan, local evidence and later sanitised
  immutable raw preflight/apply/postflight receipt set. Actual rows only after apply.
- A small Studio catalogue-evidence reader under
  `lib/features/programme_studio/`: verifies project/query/manifest/row hashes and
  returns exact legacy bindings; it never marks a draft as a published definition.

### Prepare (offline first; later authorised preflight)

1. Read the approved WRITE_SET plus selected source and hash both. Reject additional
   operations/unknown fields, altered setups and updates to protected IDs.
2. Read a caller-supplied authenticated catalogue snapshot and schema/constraint
   receipt, with target, operator and capture provenance. In local tests it must be
   explicitly labelled synthetic. Never claim stale data is fresh hosted truth.
3. Compare name/slug/equipment/setup/execution/load semantics and required fields.
   Text search only discovers candidates. Explicit owner-reviewed exact-match evidence
   determines reuse; NULL is unknown, ambiguity/conflict refuses. Do not select by
   normalised name similarity or silently enrich a protected row.
4. Allocate real IDs only against a fresh target inventory during the later operator
   preparation; pin proposed IDs/slugs and all inserted fields in the operation
   manifest. Use the established EX identity convention and actual DB keys/defaults;
   do not create a canonical ExerciseDefinition version/event for a legacy row.
   No new bridging mappings are authorised by this batch.
5. Generate a **data-only** transactional seed and exact manifest: target ref,
   operator principal/role, source/write-set digests, request ID, chosen existing/new
   identities, exact payloads and expected pre-state. Protect all existing rows,
   particularly the three leads. Approval pins seed and manifest SHA-256; later
   changes require re-prepare, not substitution under the old digest.
6. Unknown required catalogue taxonomy/fields cannot be inferred from coaching
   language. Reuse established valid defaults or explicitly review that exact field
   before apply. No muscle/category/setup invention to satisfy a schema constraint.

### Apply (later, authorised operator only)

- Accept only a hash-pinned reviewed manifest/seed and exact expected target. A
  user-controlled “founder” string or desktop feature flag grants nothing.
- Open the specifically authorised DB connection through the ordinary operator
  route; verify server/database identity and effective role before any write.
  Credentials come from an approved secret reference, are never echoed/logged,
  embedded in command arguments or copied into browser/file/Git artifacts.
- Establish a bounded writer hold for this catalogue batch. A transaction must
  recheck exact pre-state/dedup/allocation while holding a lock that excludes
  competing catalogue inserts. Choose and prove the actual locking/role contract
  against the real schema in the implementation; an advisory lock alone is not
  sufficient if other legacy writers do not participate. Do not grant UPDATE/DELETE
  merely to acquire a table lock: use the existing authorised operator/owner apply
  role and prove that no update/delete statement exists in the pinned seed.
- Re-check the actual primary/unique constraints on IDs and slugs. Never assume a
  slug constraint exists. Collision/partial/mismatched state aborts the **whole**
  batch. If preparation intentionally reuses exact verified distinct rows, pin that
  reuse; do not opportunistically adopt a different concurrent row during apply.
- If all planned new rows are absent, insert only the pinned missing records. If
  all already exist byte/field-exact for this same operation, return replay/no-op.
  Any other partial state refuses for reconciliation. No `ON CONFLICT DO UPDATE`,
  silent skip, update, delete or unrelated association/consumer mutation.
- `published=true` is permitted only as the actual approved legacy producer write,
  with real database-generated fields retained. No invented publication evidence,
  no v3 event, no source definition version if the legacy schema lacks it.
- Before commit compare full protected existing-row state and required catalogue
  postconditions. Any unexpected delta rolls back. Return explicit applied/replayed/
  refused/unknown status; timeout alone is not proof of failure or permission to
  allocate another identity.

### Verify and retain

Perform fresh readback with the same normal authenticated operator route. Capture
actual full resulting rows, target, DB principal, request ID, operation/seed/source
hashes, actual DB/server timestamps and before/after digests. Preserve raw response
bytes and their hash plus a separately canonicalised row digest. Retain real legacy
row provenance with NULL fields intact; definition versions/events remain absent
where the source does not provide them. Retention status must not fabricate history.

Durably save the sanitised receipt bundle before admitting it into Studio. A matching
seed replay plus exact readback recovers a lost commit acknowledgement; do not execute
new IDs on retry. Compare all pre-existing catalogue rows and protected consumer
counts/digests against the agreed preflight scope. No completed/started prescription
or assignment may change. Feed only exact matching genuine results to the existing
v1/v2 row-intake guard, then run full strength graph admission. Updating the global
Exercise Knowledge snapshot or a transitional mapping dataset is outside this batch.

Local logs alone are not tamper-proof proof of hosted execution. Keep the normal
operator/deployment audit record and authorization reference; bind returned data to
that authenticated operation, retain it as immutable evidence and independently
read back. Do not relabel a local fixture receipt as a live producer receipt.

## Authentication, authorisation and history requirements

- **Authentication:** actual operational DB identity via the established secure
  connection. Existing founder app authentication is not presumed to have database
  INSERT authority. Verify transport and actual role; no service secret in Studio.
- **Authorisation:** explicit target + exact three-record operation digest + named
  principal/role + time-bounded apply scope. Effective DB access must be reviewed.
  Prefer existing controlled operator privileges, no new anon/authenticated table
  grants. Any temporary login/role membership/credential issuance is its own later
  provisioning action, followed by expiry/revocation verification. Do not claim a
  client wrapper narrows a privileged DB role at the server: this is a trusted
  operator operation, never an untrusted-client API.
- **Deduplication:** exact identity/setup review before allocation, locked transactional
  recheck, actual unique constraint checks, exact retry, fail on ambiguity/partial
  state. No lowercasing/fuzzy matching as identity authority.
- **History:** insert/reuse only; old rows/IDs/consumers remain unchanged. Native
  legacy rows have no invented version lifecycle. Immutable evidence snapshots and
  immutable future session/programme revisions preserve their actual observed
  meaning; subsequent catalogue corrections require a separate reviewed operation.
- **Audit:** who authorised and operated, actual target/time, what exact fields,
  seed/request/source hashes, preflight/conflict decisions, inserted/reused IDs,
  actual row bytes, successful or refused transaction and verified readback,
  protected-state invariants and credential expiry. No secrets or athlete data.

## Later environment actions — exact separate authority

After local implementation/review, request **one bounded provisioning/apply package**:

1. Name Field Manual `otnhhdxstdnwccehacku`, the real operator principal and ordinary
   connection/role issuer. Authorise identifying an existing approved connection;
   if none exists, explicitly authorise a short-lived operational login and its
   exact effective role scope/expiry. This is presently unprovisioned. No key reset,
   reusable app writer, PUBLIC/authenticated grant or v3 activation follows.
2. Authorise fresh SELECT-only identity/health/schema/constraint/role/pre-state checks
   and a catalogue-writer hold; resolve exact IDs/required fields and produce the
   final three-record manifest/seed. This is not a repeat movement-choice audit.
3. Review and authorise the exact final hash-pinned **data-only seed**, through that
   connection, with transactional rollback/readback/retention. If the established
   deployment path records a seed in the migration ledger, authorise that single
   data operation and exact ledger action explicitly. No schema DDL, general
   `db push` batch or unrelated held migration is included.
4. Verify actual retained rows/protected-state postconditions, expire task login,
   end hold after success/failure accounting, and commit only sanitised evidence.
   Bind the three actual records locally; do not publish programmes or assign users.

There are **no schema migration files to apply for this recommended route**, and no
production endpoint to deploy. The implementation creates an operator tool and a
reviewable data seed; the database operation and any credential provisioning remain
separately authorised. If local proof demonstrates that this exact route requires
DDL or broader persistent privileges, stop with the concrete delta before making it.
A routine “ask owner” instruction is not an implementation result.

No part of this allocation authorises the four later steps today.
