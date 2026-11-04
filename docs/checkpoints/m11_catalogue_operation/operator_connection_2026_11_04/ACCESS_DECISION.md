# One exact founder action: temporary operator login authority

**Pending; no credential request or hosted action has occurred.**

Lee: reply in this Codex chat with the following specific authorisation (no secrets):

> Authorise one provider-managed temporary read-write Supabase CLI login for Cohort
> Field Manual otnhhdxstdnwccehacku, using the established cli_login_postgres /
> existing postgres operator route, solely for fresh preflight, the reviewed three
> exercise records, independent verification/retention and expiry checks. Limit task
> use to one operation window of at most 30 minutes after issuance, ending earlier
> at provider expiry. No new role membership, grants, password reset, schema/ledger
> deployment, programme publication, account, eligibility, assignment or athlete write.

This is needed because the current task expressly excludes credential issuance without
specific authority. It is an access decision, not renewed approval of movements or
of the already authorised three-record catalogue operation.

## Where and what access this enables

After that authorisation, the agent may use the existing authenticated Supabase
operational connection flow for this project. The retained, successfully used route
requests `POST /v1/projects/otnhhdxstdnwccehacku/cli/login-role` with
`{"read_only":false}`. This is the supported provider-managed temporary-login route,
not generic Management SQL. No account creation or new catalogue endpoint is proposed.
The current supported flow must be verified before calling it; changed requirements
or role/membership deltas stop for decision. The prior migration approval is not reused.

The expected temporary principal is `cli_login_postgres`, assuming only the existing
`postgres` operator role. **That role has broad database privileges**: this tool's
three-record allowlist constrains operator actions, not server-side role authority.
No narrower credential is promised. No membership/grant/role-attribute broadening is
included. Actual principal/role, server identity, TLS and finite provider expiry must
be captured and compared; any unexpected contract stops before catalogue writes.

Credentials stay in the task's approved local secure mechanism, excluded from command
arguments, output, Git, Studio and chat. Bind only a task-owned normal libpq service,
with sslmode=verify-full, to the existing operator tool. Use the installed psql via a
task-local PATH. Do not alter preserved .temp, shared credentials or global settings.
The failed shared-telemetry launcher probe is not permission to retry with a bypass;
use only a supported operational flow with separately authorised task-owned state.
If the current launcher cannot operate within that boundary, stop and report it.

The task-use authorisation expires after at most 30 minutes or provider expiry,
whichever comes first. Capture the actual native login expiry; do not assert that the
provider TTL is configurable or server-enforced at 30 minutes. No refresh/reissue past
that window. Close task sessions and remove only task-owned credential material;
observe provider expiry and zero task backends separately. Do not drop/revoke a shared
role, reset a password or claim local deletion invalidates remote authentication.

## Preparation complete before this request

- The exact unchanged offline request and source/write-set SHA-256s are verified;
  the three approved semantics and protected EX-026/037/090 remain fixed.
- The implemented prepare/apply/verify-retain and previous DB rehearsal are retained.
  A usable psql binary is present; no dependency install or UI work is needed.
- No final ID, fresh manifest or seed is invented from the old catalogue snapshot.
  After connection, capture state_sql() via that authenticated route and retain exact
  raw bytes, real operator/audit reference and timezone-aware task-use expiry.
- Review full inventory/dedup/conflicts and compatibility, then the generated exact
  manifest/seed hashes before apply under the standing bounded operation authority.
  Unknown required fields, permission/lock needs or deployment-ledger requirements stop.
- Use the documented five-second lock and sixty-second statement limits: EXCLUSIVE on
  exercises_v2 and SHARE on the five named consumer guards. Verify existing operator
  entitlement; no UPDATE/DELETE grant merely to obtain locks.
- Recovery is same pinned IDs/manifest, exact replay, independent readback and external
  operator audit. Unknown outcomes never permit another allocation; partial/conflicting
  state refuses. No compensating delete or silent update. Establish the genuine receipt
  trust pin only after actual authenticated evidence and audit are available.

[Existing operation and command contract](../HANDOFF.md) remains controlling. No
migration dry-run/apply is needed for this data-only route. A required ledger action
would be an out-of-scope dependency, not permission to run migrations.
