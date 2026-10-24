# Provisioning, transport and content inventory

2026-10-24. Fresh observations are in [INSPECTION.json](INSPECTION.json). PostgreSQL is
inaccessible. **Unknown is not absent.** Catalog/capability/approved-artifact counts and
fingerprints cannot be supplied while the project is INACTIVE. No secret value, founder
allowlist entry, athlete record or credential was retained or output.

## Present and verified, with scope of verification

| Item | Verified evidence | Practical limit |
| --- | --- | --- |
| Intended Supabase project | Exact ID/name/region; reported PG17; status INACTIVE | No current SQL/catalog/ledger or health proof |
| Legacy trusted import host | Verified Google project `cohort-platform-production` / `809647670049`; Cloud Run `cohort-trusted-plan-import`, `europe-west1`, Ready, 100% traffic on `cohort-trusted-plan-import-df97fb2f4797` | Configuration metadata, no valid Founder request or end-to-end write |
| Runtime identity | `cohort-trusted-plan-import@cohort-platform-production.iam.gserviceaccount.com` exists; is configured on service | Not a PostgreSQL producer identity or verified retention capability |
| Immutable image reference | `sha256:712ca882fb0bc8f09856679c5a9238b5e9cf00e73c01e4bcdd7cf2d73d8532b9`; source-commit label `df97fb2f47974ce309f7b94d31fa1b0f725c1795` | Label is metadata, not independent binary provenance attestation |
| Existing configuration | Supabase URL equals Field Manual; anon configuration present; service-role and Founder allowlist reference their named Secret Manager version `1` | No secret content read; credentials/allowlist semantics or current validity not tested |
| Pinned secret versions | `cohort-trusted-plan-import-service-role:1`, `cohort-trusted-plan-import-founder-allowlist:1`, both ENABLED; runtime SA has direct per-secret secretAccessor grants | No project-level direct roles found for that SA; this is not a complete transitive/organisation IAM audit |
| Auth metadata | email enabled, signup enabled, JWT expiry 3600, redirect allowlist present | No auth configuration changed or redirect/allowlist content disclosed |
| Reviewed v3 source | Retention port, strict SQL rules, authenticated Founder facade, review/consent/canonical-start and frozen runner implementation | Local proof; no hosted admission/provisioning inference |

## Verified absence, specified work and unverified state

| Item | Classification | Required next action |
| --- | --- | --- |
| Supabase Edge Functions / Edge secret names | Fresh API lists both empty | Nothing requires using Edge Functions; external Cloud Run already exists. Do not invent missing Supabase secrets as a requirement |
| v3 HTTP facade route in reviewed executable source | Absent, existing facade implementation available | Implement an explicitly reviewed authenticated handler/composition using `TrustedV3FounderPublication` and `SupabaseV3PublicationAuthority`; retain existing import path/refusals and safe logging. No new route was enabled by the athlete milestone |
| Verified ExerciseDefinition publication-event adapter | No real implementation in reviewed source; `ExerciseVersionPublicationAuthority` is a required port, fixtures only implement synthetic authority | Bind to a named trusted approval/event source and review authentication, provenance, retries, retirement and audit handling before provisioning |
| PostgreSQL NOLOGIN capability role and usable memberships | Current hosted presence unknown | Read actual attributes, memberships both ways and effective SET/INHERIT paths after resume. DDL expects no usable producer before separate provisioning |
| Canonical published definition versions/events/kind approvals | Current hosted presence unknown; migrations deliberately install none | Inspect identity/version/fingerprint/kind/retirement metadata. Supply approved exact full definitions and publication events only under separate authority; catalogue rows and hashes alone do not create authority |
| Approved v3 programme artifacts, physical graph seals, consents, snapshots | Current hosted presence unknown | Read aggregate fingerprints/counts and retained-definition metadata after resume; no real athlete data or publication to test readiness |
| Existing publication transport's v3 capability | Source at deployed label and reviewed main lacks v3 route composition | Treat known legacy service as existing infrastructure, not missing infrastructure or accepting v3 transport. No anonymous/valid-Founder smoke writes |
| Intended producer credential, effective PostgreSQL authority and secret configuration | Not verified; not inferable from existing legacy service-role secret | Exact operational identity/security decision and later provisioning approval required. Never use ordinary service JWT to retain definitions |

## Fully specified constraints; explicit founder/security decisions still needed

The accepted architecture remains binding. Capability name is
`cohort_exercise_version_publisher`: NOLOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB,
NOCREATEROLE, NOBYPASSRLS. PG17's creator ADMIN-only link must have SET/INHERIT false.
Only the dedicated capability may retain/retire exact published versions; normal service
can resolve definitions/publish strict private programmes, not register definitions.
No client supplies authoritative targets or publication approval. No broad default grants
or catalogue backfill is part of schema deployment.

Security/operational decisions required before a usable producer exists:

1. Name the backend operational principal that may exercise the dedicated capability, its
   approver/operator and source of verified publication events. Do not assume the existing
   Cloud Run SA or service JWT is that principal. Specify the minimal reviewed SET/membership
   graph, connection authentication/network boundary and access to only required secrets.
2. Specify issuance, storage, pinned version references, audit, rotation/revocation and
   retirement-event handling. Do not create/download credentials or change IAM in preflight.
   Any login/membership changes require separately reviewed SQL/operations and postchecks.
3. Name the exact source artifact versions/publication events and explicit exercise-to-kind
   approvals. Evidence must establish already approved publication, not merely JSON fields
   shaped like provenance. Decide retention operation authority for those exact artifacts.
4. Approve bounded HTTP composition/deployment and caller policy separately. The existing
   first-deployment script deliberately refuses an already existing service; do not rerun
   it as an update mechanism. A later runtime release needs its own reviewed revision/traffic
   plan, immutable image digest, exact target URL and pinned secret versions. The existing
   importer route `/v1/founder/plan-packages/import` must not silently become a v3 publisher.

## Can schema deploy while v3 stays unavailable?

**Yes by the reviewed design, conditionally; hosted safety is not yet certified.** The six
files seed only the approved calculation dependency rows, not definitions, programmes,
assignments, benchmarks, consents or snapshots. They retain strict admission, create an
unassigned capability, and do not compose an HTTP publication route or usable producer.
With no resolved approved sources/artifacts, accepting v3 publication/new starts remains
unavailable; legacy v1/v2 follows the protected path. Missing source/provenance is a refusal,
never a synthetic replacement or fallback to a lower package schema.

This requires active preflight to prove the current ledger/object state, effective role
and service authority, source/artifact absence or exact existing compatibility, no legacy
v3 pins or frozen records needing special handling, and valid legacy postchecks. Unknown
hosted data or a drifted capability cannot be waved away as empty. If compatible frozen
v3 data already exists, preserve and assess it; do not force an 'empty install' narrative.
Schema-only approval cannot include usable membership/provisioning or real data writes.

## Source/content and later product dependencies

[Approved Base rules](../hyrox_base_personalisation/DECISIONS.md) include the programme
purpose/schedule, run/row/squat dose calculations and shared benchmark set. Those facts
are approved. Supporting programme content from the founder conversation is **not yet
transferred/consolidated**; it must not all be labelled undecided or regenerated here.
Transfer and reconcile the supplied supporting prescriptions, exact exercise variants,
sets/reps/RIR/rest/tempo/cues, coaching/capture fields and immutable source bodies before
identifying genuinely unresolved details. Bind exact canonical published definitions and
validate every actual block/timer shape against the existing supported runner profile.
No complete 48-session source package is claimed or manufactured.

Test Week remains a separate unauthored/unapproved programme dependency. Exact race-division
standards and authoritative wall-ball/race mappings remain unverified source work; no
defaults or name-based mappings are invented. Neither blocks a purely empty schema install
by itself; both block any publication that depends on them. Content approval, retention,
programme publication and real assignment are separately authorised actions.

Matching client deployment, Founder usability acceptance, authenticated installed-device
and four-phone validation/distribution remain separate. Terminal builds/local E2E do not
prove hosted availability. Garmin export is outside scope; structured snapshots remain
intact without an integration claim. No broader Stage 2/Sprint C or production-readiness
closure follows from this inspection.
