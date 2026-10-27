# M1.2 deployment handoff — not authorised to apply

Source implementation is local. Do not distribute the new client before compatible
schema is verified. New authenticated setup fails visibly unavailable against an older
backend; it does not silently skip onboarding or fall back to generated training.

## Exact schema boundary

See MIGRATIONS.json. One new file:
`20261026110000_training_setup_private_alpha_acquisition.sql`.
Expected recorded base is Field Manual ledger130 / tip20261024130000. This is a dated
receipt, not fresh target proof. Repository has 132 production source files: the 130
recorded applied files, this M1.2 file, and the still-deferred producer file
`20261026120000_durable_publication_approval_events.sql`. This task applied nothing hosted.

The new file deliberately sorts before that unapplied producer. A separately authorised
M1.2 deployment must use a reviewed disposable copy of the exact deployed prefix130 plus
this one hash-pinned file, with no .temp copied from older checkouts. Do not run ordinary
repository-wide db push to accidentally apply both pending files, use include-all/repair,
or edit/move an already-applied file. The local gate uses exactly this independent path.
Reconfirm the actual ledger/target and full exact pending set before any future decision.
If the base differs, stop and review; do not adopt these expectations as live truth.

Only after separate deployment authority: establish the required writer hold/preflight,
verify exact target/catalog/security/current data and file hashes, inspect an ordinary
one-file dry-run, apply only the approved file, then verify ledger131 / tip20261026110000,
RLS/closed table and column privileges, authenticated-only four-RPC ACLs, closed internal
helpers, preserved old function ACLs/owners, exact intended two helper body changes and
unchanged protected data/authorities. No account/eligibility/content/assignment seeds.
Any operational login/credential action needs its own authority. No test fixture enters
that copy. No role/default-grant widening is part of this handoff.

The retained producer PROVISIONING/MIGRATIONS manifests still expect ledger130. A later
M1.2 apply would invalidate that old expected-before ledger; refresh/review its exact
manifest before any separately authorised producer operation. Do not resume it here.

## Recipient and content operations stay separate

The closed eligibility table is a minimal exact-recipient seam, not an invitation API.
After genuine programmes and real accounts are separately authorised/verified, an
explicitly authorised database operator may provision only the reviewed athlete/version
rows (optional expiry) in a bounded operation. No direct service/athlete table write
privilege is supplied. Eligibility cannot publish or approve a programme. Do not transfer
ownership, invent a coach link, bulk-grant users, copy tokens or create accounts as a
workaround. A row authorises a future explicit free acquisition; it creates no assignment.

Review the exact private retained artifact/physical graph and metadata, immutable version,
owner and intended recipient first. The athlete then uses normal signup/setup/discovery/
detail/Get programme and receives the existing no-replacement assignment transaction.
Existing active programmes are preserved. No service impersonation or direct assignment
DML substitutes for that action. Current Hybrid10K/father sources remain missing.

## Recovery and device follow-through

On failure, inspect ledger/catalogs before retrying. No automatic migration rerun, ledger
repair, table drop, rollback of published history or data deletion. Preserve committed
setup, eligibility and acquired assignments. Roll back only an explicitly reviewed client
release if necessary; tighter server checks do not grant rollback/data-repair authority.
A deployment smoke that creates real training data needs separate authority.

After schema/real-content/recipient approval and a separately approved candidate build:
validate normal account confirmation, draft interruption/resume, catalogue/detail/free
acquisition, same-version retry, active-programme refusal, exact schedule/restart and
logout/account switch on real devices. Verify no foreign/private metadata, clear failures
and source/build provenance. Exercise relevant benchmarks only for the actual programme.
Record founder usability acceptance separately; local tests do not close M4.2.
