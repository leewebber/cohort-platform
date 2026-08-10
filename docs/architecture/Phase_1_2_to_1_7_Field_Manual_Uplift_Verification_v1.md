# Phase 1.2–1.7 — Cohort Field Manual Uplift Verification (v1)

**Status:** COMPLETE — founder-accepted permanent evidence
**Classification:** bounded nine-migration hosted schema/RPC uplift
**Recorded:** 2026-08-10
**Branch / baseline HEAD:** `codex/b4d21b-rebind-path` /
`e54f82ec1ec5807d260c8839cd5b3eb2fcdb2fe2`

## 1. Authority and boundary

The founder authorised exactly the nine Phase 1.2–1.7 migrations from
`20260731120000` through `20260803180000` on Cohort Field Manual. The operation
excluded the Phase 3.1F seed, application deployment, first-consumer work,
product-UI Gate 2, Cohort Staging, Athlete E, migration-history repair, and
destructive rollback.

Observed hosted identity before mutation:

- project: Cohort Field Manual
- ref: `otnhhdxstdnwccehacku`
- region: `eu-west-1`
- status: `ACTIVE_HEALTHY`

No Cohort Staging database connection or mutation was made.

## 2. Immutable migration set

| Version / file | SHA-256 | Intended effect |
|---|---|---|
| `20260731120000_authored_plan_package_import.sql` | `94c5a39a308faed1f70d3dc5fbfa9aa7c73e61d9a1b799cd285816473aa5e435` | Plan Package provenance, child tables, catalogue RLS, immutability and service-role import/publish/approve RPCs |
| `20260801120000_athlete_catalogue_enrolment.sql` | `9426294573bc430b4a9fe744494c03fd9397b106fe10e58d3921af9ece899e85` | Exact-version athlete catalogue enrolment contract |
| `20260801140000_athlete_plan_materialisation.sql` | `e073890930da8aab2fb3992222b5756c8eae0f32757dfaf973f7327c28845ffc` | Materialisation provenance, cursor initialisation and RPC |
| `20260801150000_harden_materialisation_write_guard.sql` | `fcf3b9f014a12293dd46383894f64516a650ce2daaeaaeb2abdbe506e5308cc4` | Privileged-role materialisation write-guard correction |
| `20260801160000_complete_programme_session_and_advance.sql` | `26f9fbbc8c7b7db4fafce4b50302fb386107e897f08c271ff6f2bd6a5262d883` | Atomic completion identity and authored cursor advancement |
| `20260803120000_add_programme_schedule_projection.sql` | `483f552a88c1a76427c67ac102c80315fa57cdece06ae625c7e17711f529681a` | Durable schedule projection, occurrence and operation schema |
| `20260803140000_apply_programme_schedule_move_swap.sql` | `4c0145bdfe30ef12276e3569adf1502e3511ff73521b4c44e44baa434b45b1e8` | Exact-preview Move/Swap and RPC-only schedule guards |
| `20260803160000_apply_programme_schedule_push_skip.sql` | `9ad73e5dd2c4a697875956b9c618a2d888b2e10777b5d08a09b33a3093415f7e` | Exact-preview Push/Skip |
| `20260803180000_apply_programme_schedule_undo_horizon.sql` | `97643372e6b09aaea424b9aff989ee05f1dc7aae242a65c7d567b3f9d6558cda` | Scheduling horizon and one-level Undo |

The separate migration
`20260809160000_founder_exercise_library_phase_3_1f_part2.sql` was not present
in the isolated apply set and was not applied.

## 3. Preflight

Read-only hosted preflight observed:

- migration ledger: 34 entries, maximum `20260730150000`;
- authorised nine present in ledger: 0;
- later migrations after that baseline: 0;
- all probed material effects of the nine: absent;
- Phase 3.1F seed in ledger: absent;
- exercise catalogue: 127 rows;
- `EX-128`–`EX-132`: 0 rows.

Privacy-preserving counts and server-side digests were recorded for profiles,
programme lineages/versions/assignments, training-session records, slot
outcomes, protocols and exercises. No individual athlete row or identifier was
returned.

## 4. Recovery readiness

Hosted metadata reported PITR disabled and no physical backup. Before mutation,
a fresh logical recovery set was therefore created outside Git with directory
mode `0700` and file mode `0600`. The full roles/schema/data dump hashes were:

- roles: `25873cec56a2cc6514e204f420231777f85c03da818caa7090cdcdfa89776ecd`
- schema: `b25b71522bb371221dd4b1a5a361448452f0a820b31f1d407b0c470e7a4514c8`
- data: `27e03dfee30568113b99ad116cd021a5242ccdf9ca379f0644c30faa3c7b9efc`

A separate public-schema recovery slice was retained and successfully restored
into an ephemeral local Supabase PostgreSQL instance. Protected table counts
and digests matched the hosted preflight:

- public schema:
  `8c2400d16abd907e532027f7f2cb1e617ac507457d133bbbefda2c80ad0888db`;
- public data:
  `0ba913be465d1396e5bd52116793d171e2a511990af4014c2951a90ebbc287a4`.

A full-data restore rehearsal was not completed: it stopped against the
available newer local Supabase image on a managed Auth schema-version mismatch
(`audit_log_entries.ip_address`). It did not contact or alter hosted state. The
authorised uplift affects `public`, and the public recovery slice restored and
hash-verified successfully. Recovery ownership is the founder/project owner;
the route is restore from the retained pre-uplift logical set to a
version-compatible Supabase project, never destructive down migrations.

## 5. Isolation and apply

The private apply workdir contained the 34 ledger-matched baseline migrations
plus only the authorised nine pending migrations. Its dry run listed exactly
the nine files above, in order; all hashes matched the reviewed repository
files. No seed, fixture, application deployment or history repair was included.

The same isolated set applied all nine migrations successfully in order. The
CLI emitted a post-apply cache warning because a private pg-delta CA file was
not present in the isolated workdir. The push exited successfully, and
independent read-only ledger and schema postflight established the authoritative
result.

## 6. Postflight

Observed postflight:

- migration ledger: 43 entries, maximum `20260803180000`;
- every authorised version: present exactly once and in order;
- unauthorised later migrations: 0;
- Phase 3.1F seed ledger entry: 0;
- exercise catalogue: 127 rows;
- `EX-128`–`EX-132`: 0 rows;
- expected new tables: 8/8;
- expected new/altered columns: 21/21;
- key RPC/function names: 8/8;
- key triggers: 6/6;
- expected policies: 21/21;
- expected RLS-enabled new tables: 8/8.

Privilege probes confirmed service-role-only Plan Package import, authenticated
athlete access to enrol/materialise/complete/ensure/apply RPCs, and no anonymous
import/apply execution.

Pre-existing-column digests and counts for programme relationships,
programme versions, lineages and slot outcomes matched preflight. Full-row
digests and counts for profiles, historical training-session records,
protocols and exercises also matched. No programme data, protected identity,
historical completion, or catalogue row was rewritten.

## 7. Limits and next decision

This was schema/RPC deployment evidence. It did not rerun Staging Gate 1,
perform Field Manual product-UI testing, implement a live Plan Package consumer,
deploy application code, seed `EX-128`–`EX-132`, clean up Athlete E, or start
Phase 3.2.

Next proposed decision: authorise the isolated Phase 3.1F five-row seed
deployment to Cohort Field Manual. That operation is not authorised by this
report.

```text
FIELD_MANUAL_UPLIFT_APPLIED=true
FIELD_MANUAL_UPLIFT_VERIFIED=true
FIELD_MANUAL_MIGRATIONS_APPLIED=9
PHASE_3_1F_SEED_APPLIED=false
PHASE_3_1F_ROWS_PRESENT=false
PRODUCT_UI_GATE_2_VERIFIED=false
APPLICATION_DEPLOYED=false
FIRST_CONSUMER_IMPLEMENTED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```
