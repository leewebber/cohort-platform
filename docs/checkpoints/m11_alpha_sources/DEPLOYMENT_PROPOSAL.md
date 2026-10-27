# Alpha hosted proposal — prepared, not authorised or executed

2026-10-27. [M1.1 handoff](HANDOFF.md). Existing controlling detail:
[M1.2 deployment](../m12_acquisition/DEPLOYMENT.md) and
[manifest](../m12_acquisition/MIGRATIONS.json). No new migration is proposed here.

## First approval that can unblock ordinary acquisition

Approve only the exact M1.2 schema operation on **Cohort Field Manual**,
project `otnhhdxstdnwccehacku`:

- File: `supabase/migrations/20261026110000_training_setup_private_alpha_acquisition.sql`
- SHA-256: `59cb7a97e5c5bcd6e5bc230631a1c34942ce4cd7610aa253b1556510df7248f5`
- Dated expected base: ledger130 / tip20261024130000; not refreshed in this task.
  Expected result: ledger131 / tip20261026110000.
- Scope: two empty closed RLS tables; four authenticated-only setup/catalogue/acquire
  RPCs, two closed helpers, and exactly two existing eligibility/visibility helper
  body replacements preserving their ACLs/owners. No broad/default grants or seeds.
- Consequence: compatible clients require saved timezone setup, and operators can
  later grant exact private v1/v2 eligibility. This creates no accounts, content,
  assignments or athlete evidence and does not enable Garmin or the v3 producer.

Execution under that separate authority must establish writer hold, fresh exact
target/ledger/security/catalog/protected-data baseline and manifest hashes. Use a
reviewed disposable deployment copy containing the recorded applied prefix130 plus
this file only; no existing `.temp`, fixtures or deferred producer migration.
Require an ordinary dry-run showing exactly one file; stop on any mismatch.
Any operational credential issuance/login action requires its explicit scope too.
Apply once, verify expected ledger, closed effective role/table/column/RPC privileges,
two intended helper body deltas, unchanged old ACLs/owners and protected data, then
verify an empty dry-run and release the hold only on successful postchecks.
No `--include-all`, ledger repair, default-privilege changes or global repository push.
On failure inspect state and retain evidence; no automatic rollback/deletion/replay.

Do not ship the M1.2 client against an unverified older backend: setup fails visibly
unavailable. Schema deployment alone will still leave genuine programmes unavailable.
The producer's old ledger130 manifest would need a fresh review after this operation;
its file `20261026120000_durable_publication_approval_events.sql` remains excluded.

## Later content/access approval — not yet concrete enough to request

After source admission, present one manifest per genuine programme with exact
approved source/review/body digests, immutable version and canonical package hash,
reviewed graph identities/hash, scope seal expectation, owner, metadata and target
rules. Request the bounded retained private v1/v2 service publication operation;
verify its exact response and stored graph/artifact without assigning an athlete.
Do not invoke the publishing CLI as a dry-run or copy old publication identities.

Separately verify normal accounts and request only the intended athlete/version
eligibility rows, with explicit expiry/revocation policy. Eligibility makes the
offer discoverable and acquirable; it neither enrols nor replaces existing training.
The athlete explicitly acquires through normal setup/detail/start date. If an active
assignment conflicts, stop for a separately reviewed decision; no direct assignment
DML or legacy replacement shortcut. Account creation, hosted smoke writes and
authenticated training/benchmark/device scenarios require their own bounded approval.

Exact real publication/access approval cannot yet be supplied because the sources,
versions, recipients and policies are not known. Do not request blanket permission
now. Distribution and device acceptance remain separate from these hosted operations.
