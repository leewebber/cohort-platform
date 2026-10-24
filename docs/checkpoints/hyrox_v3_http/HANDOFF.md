# Local v3 HTTP composition and trusted-event adapter

2026-10-24. **LOCAL HTTP → AUTH → APPROVED EVENT → CAPABILITY/SQL PATH PROVED. NOT DEPLOYED.**
Base published main `f8afc4d15552d76325cb94819cc43802871b85d6`;
implementation **`f7d9824f6c74b0f800847221dd8e1c16e625a0e5`**. The following documentation commit is the durable continuation checkpoint.
[Event/auth contract](CONTRACT.md), [deployment/configuration/recovery](DEPLOYMENT.md),
[verification](VERIFICATION.json), [exact migration inventory](MIGRATIONS.json).
The existing [authoritative contract](../hyrox_authoritative_start/CONTRACT.md) remains binding.

## Delivered

- The existing Cloud Run executable/runtime composes two explicit Founder-only handlers
  for exercise event receipt and approved private v3 publication. Existing Supabase Auth
  verification/email allowlist, service-only source resolution and strict publisher are
  reused; the legacy v1/v2 draft route remains unchanged. V3 is disabled without complete
  explicit configuration. No privileged path is exposed to athlete/anon callers.
- HTTP requests contain only an event ID. The concrete authenticated HTTP adapter retrieves
  the approved full record from an operator-configured trusted producer boundary. No
  caller-supplied source, definition, approval flag, owner, hash or role establishes trust.
  There is no default upstream, fabricated real producer or automatic webhook subscription.
- Exact published definition text/provenance is retained through the existing dedicated SQL
  capability. One additive function atomically delegates publication and known retirement
  to the established immutable functions. Retirement-first delivery cannot expose a briefly
  active version; late publication cannot remove retirement. Duplication is idempotent;
  conflicting event/version/retirement content refuses and failed transactions roll back.
  Retirement of already retained history still works after catalogue identity withdrawal.
- Approved programme source/identity/fingerprint comes from the trusted record. Existing v3
  compilation, exact retained dependency/source resolution, strict SQL private publication
  and physical-seal checks are reused. Both pre-publication and returned fingerprints must
  agree with the approved canonical artifact. Receipt/technical admission/approval provenance
  stay distinct; no request grants new content/global approval, assignment or start.
- All previous 128 migration hashes, compiler goldens, calculations, canonical-start/consent
  functions, application runner and observational/B2 sources remain unchanged. Existing
  frozen started/completed snapshots remain byte-identical through the tested event paths.

## Local proof and limits

57 server tests (including existing 41 transport tests), 41 compiler/golden tests and all six
required safety groups pass. Fresh/repeat disposable full migration chains exercise a
compiled native server over real loopback HTTP, GoTrue-issued Founder/non-Founder sessions,
fixture authenticated upstream, separately fixture-enabled PostgREST producer capability,
existing v3 resolver/publisher and PostgreSQL. Each replay uses one test-only baseline
plus the exact 129 repository migrations; neither is hosted-ledger evidence. The fixture producer is a test stand-in,
not a real configured upstream. Cross-role/forged events, rejected/pending approval, missing
configuration/definitions/capability, concurrent replay/conflict, retirement-first/late
publication, atomic retention rollback and final publication-artifact rollback are covered.
Existing canonical start/security/rollback/completion/history SQL gates run again using
versions retained through HTTP. Exact wrapper metadata postchecks run before and after
fixture provisioning. **79 assertions per pass**; see exact hashes in VERIFICATION.json.

Repository analysis remains **364 identical inherited findings**, zero errors, zero added/
removed diagnostic identities; all 11 changed/new Dart files and the server package have
zero diagnostics. The previous 991 app regressions and app web/macOS builds are attributed
unchanged evidence, not new runs. No browser/app opening or device work occurred.

The original dirty checkout and all 20 older inventories/indices/HEADs/.temp are preserved;
no managed worktree creation, cleanup-setting change or index regeneration occurred.
Field Manual remains inactive by task context. No hosted contact, resumption, inspection,
migration, config/secret change, producer provisioning, deployment, real publication/
assignment/athlete write or device distribution occurred in this milestone.

## Exact continuation dependencies

1. Integrate a real trusted producer/approval-event store with the documented retrieval
   contract, authenticating this receiver and supplying immutable approved records and full
   known-retirement bundles. Its origin, identity, verification implementation, approval
   evidence, durable retry/delivery and exact approved artifacts remain external dependencies.
2. Separately approve/provision the dedicated gateway capability principal/credential and
   pinned secret/configuration versions. The existing ordinary service key is insufficient;
   no production signing key, token issuer or usable membership is supplied.
3. Separately authorise project resumption/writer hold and fresh read-only readiness first.
   Actual ledger/pending suffix/security remain unknown; neither the old six-file suffix nor
   a derived seven-file suffix is approved. Review exact missing hashes including the new
   atomic wrapper, then separately authorise schema and runtime deployment.
4. Transfer/consolidate supporting founder content into exact approved immutable artifacts;
   no complete 48 sessions, Test Week or authoritative race mappings are invented. Real
   publication/assignment, client rollout, founder acceptance, installed-device/four-phone
   and existing browser checks remain separately pending. No production readiness or broader
   Stage 2/Sprint C closure is claimed.
