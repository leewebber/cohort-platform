# Updated prerequisites — local implementation only

No hosted operation or configuration/secret change occurred in this task. Field Manual is
INACTIVE by task context; its current ledger, catalogs, effective permissions, source
artifacts and producer graph remain **unknown**. The previous read-only observations are
[dated evidence](../hyrox_hosted_readiness/INSPECTION.json), not refreshed state here.
The conditional six-file suffix is not deployment-approved. This milestone adds one exact
migration after the prior 128 reviewed files; [manifest](MIGRATIONS.json) has all 129 hashes.

New file: `20261024120000_atomic_exercise_publication_event.sql`, SHA-256
`486e3ad3ec7505330978407d7a2bd1a306a46e9c28eaaf7f92b73fe3c8468359`.
It depends on authoritative retention/retirement and adds only a producer-only atomic
wrapper. No existing migration/hash/body, table, default privilege, membership or content
is changed. Do not edit the published prerequisite migrations or blindly push this file.

1. Follow the blocked [target-specific restoration/read-only/deployment/recovery plan](../hyrox_hosted_readiness/DEPLOYMENT_PLAN.md).
   Project resumption and a demonstrated writer hold still need separate authority; then
   fresh read-only ledger/catalog/body/ACL/RLS/default/role/invariant proof. Reconcile the
   exact actual missing set, including all security and v3 prerequisites. Do not assume
   ledger 122, an empty initial schema, or a seven-file pending set from this source list.
2. Obtain exact schema-only file/hash authority after that gate. Apply only approved pending
   files in normal order from a disposable linked workdir; no seeds, role import, repair,
   include-all or producer provisioning. The batch is per-file transactional, not atomic.
   New [POSTCHECK.sql](POSTCHECK.sql) checks exact wrapper body/owner/search path and only
   the dedicated capability's effective EXECUTE. Retain preceding storage, authoritative,
   review-state and legacy/B2/security checks and held-window protected digests.
3. Schema may remain unprovisioned with v3 unavailable. All old schema-only role checks still
   require **no usable producer membership**, with only the reviewed PG17 creator ADMIN-only
   exception. The wrapper installs no usable producer. Do not weaken old checks to admit
   newly provisioned authority: provisioning needs its own stage-specific reviewed graph.
4. Separately approve a real upstream producer integration implementing [CONTRACT.md](CONTRACT.md):
   its verified approval/event store and audit provenance, exact full definitions/publication
   and retirement bundles, exact approved programme artifacts, receiver authorisation,
   immutable ID lookup, complete retirement metadata and reliable redelivery. None was
   discovered, implemented upstream, provisioned or attested by the fixture source.
5. Separately decide/provision the backend principal and narrowly scoped gateway capability
   authentication for `cohort_exercise_version_publisher`. Review role attributes/SET/INHERIT/
   ADMIN links, credential issuance/expiry/rotation/revocation and network boundary. No
   signing key belongs in this runtime. `EXERCISE_VERSION_PRODUCER_TOKEN` must be a separately
   approved server-only credential for that role; no ordinary service-token substitution.
6. Only under separate runtime/configuration authority, build the reviewed source into a
   Linux image, pin its digest/revision, configure the variables below using pinned secret
   versions and review traffic/rollback. The existing deployment script refuses an already
   present service; it is not an authorised update mechanism. Existing Cloud Run legacy
   transport metadata remains dated. No image push, deployment or traffic change occurred.
7. Then separately approve exact definition retention/content publication and real programme
   assignment, followed by matched client distribution and usability/device acceptance.
   Never use the test upstream or source fixture as real approved content.

## Exact runtime configuration

Existing required variables are unchanged: `SUPABASE_URL` (fixed production Field Manual
host; loopback only for local tests), `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
`FOUNDER_EMAIL_ALLOWLIST`; optional `BIND_ADDRESS`, `PORT`, `MAX_PLAN_PACKAGE_YAML_BYTES`.

| New variable | Meaning / fail-closed behavior |
| --- | --- |
| `TRUSTED_V3_PUBLICATION_ENABLED` | Exact `true` or `false`; defaults false. With false, Founder-authenticated v3 calls return unavailable before lookup/write; legacy transport works normally |
| `PUBLICATION_EVENT_SOURCE_URL` | Required only when enabled; explicit approved HTTPS event-record base ending `/`, no userinfo/query/fragment; loopback HTTP only for disposable tests. No default URL |
| `PUBLICATION_EVENT_SOURCE_TOKEN` | Required only when enabled; server-owned bearer credential for that approved source, supplied by a separately approved pinned secret reference |
| `EXERCISE_VERSION_PRODUCER_TOKEN` | Required only when enabled; separately approved dedicated database/gateway capability credential, never ordinary service credential. SQL verifies actual role; no inferred JWT claim authority |

Partial/invalid enabled configuration fails startup. All three trusted-source/capability
values are required as one coherent opt-in group, including programme publication. Merely
publishing source to Git does not configure or activate the service. Configuration and
source/provider identity, approval rules, credentials and Founder allowlist versions need
review; no values, real addresses or secret payloads are supplied in this checkpoint.

## Partial failure, recovery and remaining product gates

Preserve existing forward-restriction/recovery rules. During a schema failure keep the
writer hold, inspect transaction/ledger/object state and get authority for the exact
remaining suffix or reviewed forward repair. Never edit applied SQL or remove ledger/data.
Exercise retention plus known retirement is one transaction; programme publication still
uses its existing atomic claim/private-artifact transaction. Separate event deliveries
are **not** one global transaction. After any timeout, retry the exact ID through the same
verified source; earlier successful version retention can legitimately remain if a later
programme operation refuses. No compensating retirement, approval or deletion is inferred.

Runtime incident response can leave the opt-in disabled under separately approved config/
revision authority and preserve legacy import/owned supported resumes/history. If restricting
SQL starts/publication or disabling withdrawal, use an inspected exact-target incident plan
and block new v3 starts appropriately; no rollback/config mutation was executed here.

Supporting content remains not yet transferred/consolidated from the founder conversation;
approved Base run/row/squat rules remain approved. Do not label all supporting details
undecided or recreate them. Full 48-session sources, Test Week and authoritative race
mappings are not supplied/invented. Founder usability, installed-device/four-phone and
existing browser checks remain pending. Browser/computer control remains revoked.
No Garmin integration, production readiness or broader Stage 2/Sprint C closure follows.
