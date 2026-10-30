# Bounded lookup sources and read boundary

Official documentation checked 2026-10-30:

- [Get project](https://supabase.com/docs/reference/api/v1-get-project):
  `GET /v1/projects/{ref}`, `projects:read` / `project_admin_read`.
- [Read-only query](https://supabase.com/docs/reference/api/v1-read-only-query):
  `POST /v1/projects/{ref}/database/query/read-only`, `database:read` /
  `database_read`, executing as `supabase_read_only_user`. Schema-qualified entity
  references are required. The endpoint is documented as beta/experimental.
- Existing repository Keychain/read API precedent:
  `tool/content_graph/verify_hosted_published_artifacts.sh`. That broader verifier
  was read, **not run**; only its established existing-credential retrieval was
  reused. The operation used the dedicated read-only endpoint above.
- Existing catalogue column contract:
  `docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md` §3.

The configured Field Manual checkout's `.temp/project-ref` and `.env` URL host
both identified `otnhhdxstdnwccehacku`; the Developer checkout had a placeholder
URL and was not used as the configured live target. Neither file was changed.

Exactly one authenticated project-status GET returned HTTP 200 / ACTIVE_HEALTHY.
Exactly one reviewed catalogue SELECT returned HTTP 201 / six rows. The raw query
result is retained byte-for-byte; the safe project-status projection and original
response digest are retained separately. No credentials are printed or stored in
the artifacts. The observed project status is not an assertion about every hosted
service, migration, device or recipient.

The executed query is limited to `public.exercises_v2`, five explicit ID leads
and two narrow variant-discovery predicates, capped at twenty rows. The cap was
not reached. `lower` and `concat_ws` are ordinary SQL built-ins used only for
candidate discovery; the “no functions/RPCs” wording in its review means no
application/user-defined RPC or data-changing function. No athlete table,
unrelated programme, ledger, role, grants, credentials or deployment data was queried.

The initial installed CLI help command failed on a sandbox-blocked telemetry-file
write. The established Keychain credential was then read with approved normal
host access, in process memory only. No CLI configuration/telemetry setting,
credential issuance, login role, project restoration or hosted write was used.
