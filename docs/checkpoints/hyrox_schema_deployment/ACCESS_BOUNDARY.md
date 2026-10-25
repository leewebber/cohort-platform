# Operational CLI access decision

Target: Field Manual `otnhhdxstdnwccehacku`. Reviewed migration approval remains exactly
[the eight-file manifest](../hyrox_resumed_readiness/MIGRATIONS.json) at
`fe0454edd0d1ac533337d288b89f6e7018ae6d70`; no filename/order/hash changes.

The current process has no database password. No existing target-scoped password was
found in the standard process/PostgreSQL store or the known repository environment
metadata. No secret value was printed/copied, and no credential was created or changed.
The disposable copied directory linked successfully through the supported metadata flow;
all preserved repository `.temp` resources remain untouched.

Installed CLI connection source requests the provider's standard temporary operational
login when no database password is supplied:

- Operation: `v1CreateLoginRole` (SDK description: create a CLI login role with temporary password).
- Target: `POST /v1/projects/otnhhdxstdnwccehacku/cli/login-role`.
- Body: `{"read_only":false}` for the ordinary migration connection.
- Effect: obtain/refresh a provider-managed temporary read-write CLI login/password. This
  is separate from `cohort_exercise_version_publisher`; no producer provisioning is proposed.
- Scope if separately authorised: only the normal exact dry-run, eight-file apply and empty
  final dry-run for this approved deployment, with credentials kept in process and out of
  output/Git. Ordinary CLI commands may refresh the temporary login more than once.
- Exact provider lifetime is not asserted from the SDK contract; this task has not called
  this endpoint. It has not run the dry-run or applied any migration.

The reviewed [deployment procedure](../hyrox_resumed_readiness/DEPLOYMENT_PLAN.md) requires:
“If obtaining access requires a new password, credential, role/capability grant or
provisioning, stop for separate authority.” This boundary has not been bypassed through
manual Management API migration execution, ledger edits or a substitute runner.

Fresh prechecks confirm ACTIVE_HEALTHY, ledger 122 with identical version/name/statement
fingerprints, all 25 protected/source aggregates equal to the reviewed baseline, 173
matching existing function bodies/ACLs, corrected policy equality and clear observed
writer/drain checks. The documented three historical differences are unchanged. No
schema migration, permission/configuration change, producer, publication or athlete write
has occurred. After an access decision, narrow target/ledger/hash/drain checks and the
exact eight-file dry-run must still pass immediately before apply.
