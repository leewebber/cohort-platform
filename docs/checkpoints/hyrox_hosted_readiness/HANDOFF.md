# Field Manual hosted readiness — blocked on inactive database

2026-10-24. Source main **55c38bbee7015bc16b25dd6d4fef4eb01900195f**.
Fresh founder-authorised inspection was read-only; no project resume, migration,
permission/configuration change, producer provisioning, publication, athlete write or
client/device operation occurred. [Sanitised observations](INSPECTION.json),
[exact conditional manifest](MIGRATIONS.json), [deployment/recovery plan](DEPLOYMENT_PLAN.md),
[provisioning and content](PROVISIONING.md), [preservation/analysis](PRESERVATION_AND_ANALYSIS.md).

## Confirmed target and operational blocker

Management API confirmed **Cohort Field Manual**, project **otnhhdxstdnwccehacku**,
**eu-west-1**, database host `db.otnhhdxstdnwccehacku.supabase.co`, reported PostgreSQL
17.6.1.155, status **INACTIVE**, at 2026-10-24T02:58:24Z. Health returned HTTP 400
`No active services available`; the harmless read-only database identity SELECT returned
HTTP 400 `Database is possibly not accessible at the moment`; migration metadata returned
HTTP 544. No database SELECT succeeded. The current ledger, catalogs, ownership, RLS,
effective grants/default privileges, protected invariants and actual producer/artifact
state **could not be verified**. The old ledger 122 is historical, not refreshed evidence.
Project resumption is a hosted mutation and was outside this authority. A final identity/status
read at **2026-10-24T03:12:35Z** still reports the same target **INACTIVE**.

All **128** repository migration filenames/order/SHA-256 values match the published
inventory and exact source Git blobs. There is no local migration drift. **The exact
hosted pending set is unknown**; deployment preparation stops before approval/apply.
The six files ending in `20261023130000` are a conditional suffix only if a fresh active
inspection proves the complete earlier 122-file prefix. Five security prerequisites are
listed separately and must not be silently bundled if found pending. See the manifest;
no six-file-pending or ledger-128 claim follows from source verification.

## Other fresh findings

- Supabase Edge Functions and Edge secret-name inventories are empty. Auth metadata is
  readable: email auth enabled, signup enabled, JWT lifetime 3600 seconds, redirect allowlist
  present. No allowlist content or key value was read into evidence. PostgreSQL config
  endpoint returned an empty object; attempted REST config routes returned 404. These
  responses do not establish effective database defaults or missing external services.
- The named existing Cloud Run host is present in verified Google project
  `cohort-platform-production` / `809647670049`, `europe-west1`. It reports Ready with 100%
  traffic on `cohort-trusted-plan-import-df97fb2f4797`, source label `df97fb2f47974ce309f7b94d31fa1b0f725c1795`.
  Its immutable image fingerprint, runtime identity and two enabled pinned secret-version
  references are recorded without secret payloads. Configured Supabase URL matches Field
  Manual. This is configuration metadata, not a successful end-to-end request or provenance
  attestation of the image. Source at that label and at the reviewed main composes the
  existing import endpoint; neither mounts the v3 publication facade as an HTTP route.
- No PostgreSQL producer, canonical definition version or approved programme artifact is
  classified absent merely because the database cannot be read. Actual state is unknown.
  The verified publication-event implementation and HTTP composition remain absent from
  the reviewed source. Existing legacy service credentials are not exercise-retention authority.

## Separately scoped next actions

1. Authorise an operator to resume **only this Supabase project**, with an explicit writer
   hold and health observation. Then repeat read-only ledger/catalog/security/invariant
   inspection. Resumption alone may reconnect existing clients and the live legacy service;
   it must not be treated as a harmless read. No verified current writer hold exists.
2. After all drift is explained, approve the exact **schema-only** missing-file/hash set
   against a fresh ledger and pause/drain receipt. This does not approve usable producer
   membership, secrets, publication, assignment or client rollout. Source design supports
   unprovisioned schema deployment with v3 unavailable; hosted safety is not yet certified.
3. Separately decide the trusted producer identity/approval-record/security boundary, then
   authorise its provisioning and a reviewed v3 transport implementation/configuration.
4. Transfer/consolidate supporting founder content, approve exact retained definitions/events
   and supported source bodies, then separately authorise publication and assignment.
5. Separately authorise matching client deployment, founder usability and authenticated
   installed-device validation/distribution. Computer/browser control remains revoked.

All 20 older checkout inventories still match the previous post-push evidence, including
original dirty main and .temp. The four restored indexes remain their previously regenerated
bytes; none was recreated again. Cleanup was the desktop's automatic keep-15 retention after
managed creation. The 365→364 analysis change is exactly one removed initializing-formal
info diagnostic, with no added identity. Existing local integration/build/safety evidence
was hash-verified and reused; no broad regressions were rerun for documentation preflight.
No hosted availability, production readiness, founder usability acceptance or broader
Stage 2/Sprint C closure is claimed.
