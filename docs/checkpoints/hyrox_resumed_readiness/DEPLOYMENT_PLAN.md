# Exact schema-only approval package — not applied

Target: **Cohort Field Manual / `otnhhdxstdnwccehacku` / eu-west-1**.
Reviewed source: **`4bc3b0f406aa71deeabd8da7a533477467326335`**; all 130 migration
files still match their reviewed Git bytes. [MIGRATIONS.json](MIGRATIONS.json) contains the
freshly determined eight missing files, exact order and SHA-256s. The actual complete
122-entry prefix, names and statement-array fingerprints are in [LEDGER.json](LEDGER.json).
A ledger statement-array hash is not a raw SQL-file hash.

This package requests a later, bounded **eight-file schema-only** deployment and read-only
postchecks. No schema deployment, dry-run/link, grant, producer provisioning, content
retention/publication, assignment or athlete write has occurred in this readiness task.
The earlier six-file plan is historical. All five security prerequisites are already
applied and freshly checked; do not silently add any other migration.

## Exact effects and exclusions

The eight files install eleven currently absent tables, closed owner-scoped evidence /
review / consent / snapshot / duration contracts, immutable definition/artifact retention,
strict v3 admission and canonical start wrappers. The **only data seeds** are the three
reviewed run/row/squat calculation dependency records. No exercise definition, programme,
source graph, athlete record, benchmark declaration, consent or assignment is seeded.

`cohort_exercise_version_publisher` is currently absent. Schema deployment creates only
its NOLOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOBYPASSRLS capability role
and the specified narrow function grants. PostgreSQL 17 may retain only its creator's
ADMIN-only membership, with SET/INHERIT false. No usable producer membership, credential,
login or service grant is included. Current service-role privilege does not grant retention.

[FUNCTION_EFFECTS.json](FUNCTION_EFFECTS.json) pins the three intentionally replaced live
bodies and final source hashes. Preserve their existing OIDs/ACL behavior; the fixed helper
stays private, generic start preserves its observed authenticated/service access, and the
interval normalizer remains pure/invoker with its existing grants. Preserve original
canonical-start bodies in the two private `*_pre_v3` copies. The other **170 existing
function definitions/ACLs** remain exact. Final wrappers/delegates/new guards and their
closed grants must match source; do not replace complete comparisons with name presence.
No change to existing global default privileges is authorised. Their retained broad
creation defaults are documented; every new privileged object needs its explicit revokes.

Even after schema-only installation, v3/HYROX Base remains unavailable: there is no real
configured event producer/durable delivery, published definition/version/event inventory,
48-source artifact or athlete consent/assignment. Cloud Run remains the legacy receiver;
no image, route, traffic, IAM, environment or secret version changes are included.

## Pause, drain and apply — later authority required

1. Reconfirm exact target/name/region, health, reviewed source and remote main relationship.
   Rehash all eight files and compare the complete live ordered ledger. Require exactly
   this missing set and absent/compatible partial objects. Stop on changed source, another
   missing file, unknown entry, name/body/security drift or an unexplained partial state.
2. Establish a **new current writer hold** if this readiness window has ended. The named
   operator closes Cohort/debug clients; reconciles pending submissions; holds direct SQL,
   publication/import scripts, legacy import callers, jobs, integrations and retries. Name
   each mechanism/operator/reversal. There is no implemented repository maintenance switch.
   Reinspect control-plane jobs/queues/triggers, DB job catalogs, reconstruction tracking,
   subscriptions and in-flight activity. Do not disable anything or alter traffic/IAM under
   schema-only authority if an unexpected writer appears; stop and request exact authority.
3. Drain read-only immediately before apply. Require adequate `pg_stat_activity` visibility
   and zero other active/open client transactions, write/idle transactions, unobservable
   clients, protected non-read locks, prepared transactions and enabled logical subscriptions.
   A momentary zero is not a durable hold. Capture fresh 19-table and six-source aggregate
   fingerprints, full catalog/ACL/RLS/default/membership metadata, source pins and legacy
   function OIDs/bodies. Never reuse this task's data hashes as a later current baseline.
4. Use the existing operational authentication and supported normal Supabase migration flow
   in a task-owned disposable working directory containing reviewed config/migrations only.
   Exclude `.env`, seeds, secrets and every preserved repository `.temp`; never relink an
   old checkout. If obtaining access requires a new password, credential, role/capability
   grant or provisioning, stop for separate authority. No password or secret value goes
   into evidence, command output or Git.
5. Only after explicit eight-file apply authority, run the ordinary linked dry-run. It must
   list exactly these eight filenames in order. No `--include-all`, repair, role import,
   seed flag, ad hoc grant or substitute SQL. Do not apply a handpicked subset to conceal
   an unexpected dry-run result. Repeat narrow target/ledger/hash/drain checks before apply.
6. Apply the approved ordinary batch, retaining the hold. Each file contains transactional
   DDL; the **whole batch is not atomic**. Source transactions, ledger recording and lost
   acknowledgements must be reconciled independently after any error. Do not infer rollback
   from an exit code or a ledger entry alone.

## Required postchecks before reversing the hold

- Exact ordered ledger **130 / `20261024130000`**, matching all source version/name entries;
  ordinary final dry-run empty. No assumption that the old 122-count postcheck is a generic
  post-apply gate: it describes the actual pre-apply baseline only.
- Repeat complete catalog/role/default/effective-grant/RLS/column/sequence/policy/trigger/FK
  inspection. Use the unchanged contracts in the [storage](../hyrox_v3_canonical_storage/POSTCHECK.sql),
  [authority](../hyrox_authoritative_start/POSTCHECK.sql) and [runner](../hyrox_athlete_runner/POSTCHECK.sql)
  plans plus [POSTCHECK_SUPPLEMENT.sql](POSTCHECK_SUPPLEMENT.sql). The supplement pins the
  atomic retention wrapper, final validator, duration overloads/private delegate, duration
  table ownership/RLS/immutable trigger and record guard. Every required object/body/grant
  check must pass, not merely return rows. Its SELECT syntax was tested pre-apply against
  known absence; **no post-apply pass is claimed**.
- Require the publisher role unusable as above, no unexpected member/ancestor or external
  EXECUTE on private helpers/guards. Ordinary service must not retain definitions. Preserve
  existing implicit/PUBLIC/default behavior only where the exact reviewed source preserves
  it (for example the pure interval normalizer); no newly inferred authority.
- Compare original start bodies against the source-pinned hashes in FUNCTION_EFFECTS.json;
  confirm unchanged public one-argument fixed-start identity and legacy generic service
  access, exact changed wrapper OIDs, and all 170 untouched existing functions. Existing
  v1/v2/B2 and independent C1/C2/C3 paths stay intact; no fallback to unresolved v3.
- Repeat prerequisite security checks with **CORRECTED_POLICY_COMPARISON.sql**, not the
  historically malformed array-string comparator. Keep its original false result visible.
  Do not run the old 'unaffected functions' check blindly after intentionally changing three
  bodies: compare the explicit source deltas and private copies, while preserving the rest.
- Run [POSTCHECK_DATA.sql](POSTCHECK_DATA.sql) only after all eleven tables exist. Require
  dependency rows=3 with exact reviewed rule/benchmark JSON and all other new tables=0.
  Preserve the 19 protected and six source aggregate fingerprints exactly under the hold.
  Require zero retained-link ownership/protocol/parent contradictions. No real smoke writes,
  benchmark/consent/start/completion/correction, programme assignment or content publication.
- Refresh project and all service health plus unchanged receiver configuration. Release only
  the same demonstrated writer hold after all checks pass; the operator explicitly reverses
  it. Do not imply native/client acceptance from metadata. Producer/content/client stages
  remain gated separately.

## Partial failure and recovery limits

Stop at the first failure and **retain the writer hold**. Capture exact failed file/time,
CLI result, current ordered ledger, transaction/drain state, affected objects/body/ACLs and
protected aggregates read-only. Prior files may be committed. A failed source transaction
may roll back, but a lost acknowledgement or ledger-recording boundary can leave committed
objects; prove the state instead of inferring it. Never rerun the complete batch blindly.

If the exact failed file fully rolled back and an environmental cause is resolved, propose
only the newly verified remaining suffix for fresh authority. If committed objects lack a
ledger receipt, or a ledger entry disagrees with effects, stop for a reviewed recovery plan;
no migration repair, ledger deletion, history rewrite or 'mark applied' is authorised.
Source defects require a separately reviewed forward repair. No editing applied migration
bytes, down migration, compensating deletion/retirement, backup restore or fabricated data.

Do not invent an available v3 disablement switch on the legacy receiver. Any new RPC
restriction, server pause/traffic/IAM/credential/configuration change or project re-pause
requires exact separate authority; resumption authority is not incident-mutation authority.
If a restriction is later proposed, account for **all** start overloads and preserve frozen
history/completion. Keep clients held until approved repair and full postchecks, or a
separately approved safe restricted state.
