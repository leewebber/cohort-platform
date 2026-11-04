# Reviewed catalogue operation — stopped at inactive target

2026-11-04, Asia/Makassar. Base and freshly checked published main:
`f1ad6522e88ebd68d352f1aefd344e2124d1bb84`.
**TARGET_INACTIVE; NO_CREDENTIAL_ISSUED; NO_CATALOGUE_APPLY; M1.1/GATE_A_OPEN.**

## Actual authority and fresh result

Lee explicitly authorised one temporary read-write Supabase CLI login for Field
Manual, existing cli_login_postgres / postgres route, solely for the reviewed
three-record operation. Task use is limited to 30 minutes from issuance or earlier
provider expiry, with no replacement login. That authority is recorded; another
credential approval is not requested. Bounded UI acceptance and the discretionary
UI-polish freeze remain in force. D8/publication stay separate.

The current official [create-login contract](https://supabase.com/docs/reference/api/v1-create-login-role)
confirms the documented temporary-login endpoint and response role/password/TTL.
The [delete-login contract](https://supabase.com/docs/reference/api/v1-delete-login-roles)
provides a supported CLI-role cleanup endpoint. Neither endpoint was invoked.
No denied launcher was rerun or redirected; existing Keychain authentication was
read through the repository's established normal operational route, in process only.

One authenticated `GET /v1/projects/otnhhdxstdnwccehacku` returned HTTP 200 at
**03:10:13 UTC / 11:10:13 WITA**. The exact target is **Cohort Field Manual**, eu-west-1,
but its actual status is **INACTIVE**, rather than the required ACTIVE_HEALTHY.
[Sanitised target receipt](PROJECT_STATUS.json) retains the observed public fields,
capture time and original response SHA-256. No API request ID was supplied; none
is invented. Database version metadata is 17.6.1.155; this does not establish a
live SQL connection, current schema, catalogue or compatibility.

The health assertion stopped the process immediately. No pooler/role/schema query,
deduplication or database preflight ran. No credential was issued, no catalogue or
associated record was written, and no resumption was attempted. Returning the project
to an active hosted state is outside the current operation authority and is the
unexpected drift that triggered the requested stop.

## Exact mutations, retained evidence and credential closeout

[Verification and closeout](VERIFICATION_AND_CREDENTIAL_CLOSEOUT.json) records:

- Executed catalogue write set and associated writes: empty. New genuine records
  created or retained: **0**. Existing exercise meanings/consumers were untouched.
- Complete strength graphs newly admitted: **0**. The unchanged committed result
  remains **0/20**, with three required setups/28 unresolved occurrences. Without
  fresh genuine rows there is no new admission evidence; the unchanged graph
  generator and local PostgreSQL rehearsal were not repeated.
- Temporary login issuance/replacement calls: **0**. No issuance time, native
  provider expiry or task-use deadline exists. The authorisation has not been
  consumed and no 30-minute use window began. No expiry or revocation is claimed.
- Task-owned DB connections opened/remaining: **0**. Temporary credential files
  created/remaining: **0**. The metadata process exited, releasing its in-memory
  existing operational token; no shared credential was removed or changed.
- No schema/migration/ledger/permission/password/account/eligibility/assignment/
  programme-publication/athlete mutation. No device, browser or desktop control.

The unchanged offline request was validated against its source/write-set pins before
the target GET. Current JSON/link/diff and Git equality/ancestry checks cover these
non-secret checkpoint changes. Previous operator/Studio/safety proofs are explicitly
reused from f1ad652; they are not fresh hosted or device proof. Other retained
checkouts, dirty files, indices, refs/FETCH_HEAD, .env/.temp and the bounded backup
inventory are compared using the existing preservation procedure. The clean detached
M1.1 checkout is reused for normal non-force main-only publication; the older dirty
Developer main is preserved. Final publication/preservation receipts stay separately
under /private/tmp/m11_catalogue_apply_*_20261104.json.

## One exact founder action

Reply in this Codex chat: **Authorise one supported resume of the existing Cohort
Field Manual project otnhhdxstdnwccehacku, then continue fresh preflight and the
already authorised, still-unused single temporary login/catalogue operation.**

This permits the agent to use the existing supported project-resume route
`POST /v1/projects/otnhhdxstdnwccehacku/restore`, documented in the
[previous legitimate resume receipt](../../hyrox_resumed_readiness/HANDOFF.md).
It changes project availability; it does not grant database permissions or approve
schema, backup restoration, a replacement project, billing changes or programme
publication. Verify the current supported contract before any resume. No secret
needs to be supplied in chat. This is a hosted-state decision, not another movement
approval or a request to obtain an unspecified owner's capability.

After resumption, require fresh target/health, schema, exact write-set, dedup/conflict,
compatibility and recovery checks before the one login's permitted operation; issue
no replacement. Retain genuine results and credential closeout, then attempt all
20 complete local strength graphs. D8, authorised programme publication/access,
compatible held deployment and the installed normal real-programme journey remain
separate. M1.1 and Gate A are not complete.
