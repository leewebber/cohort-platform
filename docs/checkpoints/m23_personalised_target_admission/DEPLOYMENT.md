# Proposed confirmed Zone 2 deployment — not authorised/applied

Exact file: [20261027120000_confirmed_running_zone_targets.sql](../../../supabase/migrations/20261027120000_confirmed_running_zone_targets.sql)

SHA-256: `26038e82bae21130982ccaed65be14ee49ad4581256f99476ccb5ba071b0de6a`.

This task authorises local implementation/proof only. A later scoped approval must
name the actual hosted project/environment and this exact one-file migration,
with a fresh read-only preflight, explicit writer/compatible-client hold, normal
exact migration application and read-only postchecks. No current hosted contact,
readiness/ledger freshness or eligible deployment credentials are assumed here.

## Scope and consequences

- Two empty owner-scoped tables, owner-only read policies and closed client writes:
  current confirmed Zone 2 input; immutable per-occurrence accepted snapshot.
- Narrow authenticated confirm/review/start APIs, private helper delegation preserving
  existing fixed/generic start function OIDs, and a performance-record guard.
- New starts explicitly authored with `athlete_confirmed_zone_2` need current input
  confirmation and exact per-workout acceptance. A started session returns its
  original snapshot even after input change/withdrawal. Generic start cannot bypass.
- No seed, content/version publication, account, recipient grant, assignment,
  benchmark calculation, exercise catalogue, actual-result backfill or existing
  athlete-data rewrite. Existing sessions missing a required freeze fail closed;
  no retroactive prescription is manufactured.
- Existing unmarked v1/v2 and B2 target starts delegate unchanged. New marked
  content needs an accepted client; older clients cannot provide the new review.

## Required preflight, exact apply and postcheck

1. Verify target/project identity, current ledger, exact file bytes and ordinary
   deployment credentials under the existing scoped operations process. Do not
   assume cached `origin/main` or historical hosted receipts are current truth.
2. Check existing v1/v2 fixed-occurrence and generic start functions, schedule/
   outcomes/session/result schemas, `cohort_auth_is_athlete`, B2 immutable-target
   trigger function, `extensions.digest`, role/default-grant state, function
   owners/definitions/OIDs/ACLs and protected data-count/digests. Conditional publisher
   revocation does not require or create that role; no HYROX producer is a prerequisite.
3. Hold writers/new-source activation as appropriate and prepare an **exact** apply
   containing only this approved file. Stop if prerequisites differ or another
   pending migration is included. The pending M1.2 acquisition migration and
   `20261026120000_durable_publication_approval_events.sql` are separate decisions;
   do not use an unreviewed all-pending push to deploy this change.
4. Apply once in the approved order. Verify the exact ledger addition; two empty
   new tables; function bodies/OIDs/security/search paths/effective grants; owner
   RLS; immutable snapshot and record triggers; unchanged old data/permissions.
   Confirm no pending unrelated schema is applied. No real athlete test/write is
   included in these read-only postchecks.
5. Separately approve compatible client distribution, exact real content publication,
   recipient eligibility and authenticated real-device target/restart/completion
   tests. M1.2 normal acquisition enablement still needs its own scoped apply.

Do not roll back by deleting snapshots after real starts. Preserve any accepted
prescriptions and actuals; a rollback/forward-fix plan must be reviewed against the
then-current data. Local fresh/repeat proof and exact evidence are in
[the handoff](HANDOFF.md) and [verification](VERIFICATION.json).
