# M10 membership privilege hardening

**Recorded:** 2026-09-20

**Status:** Local additive ACL hardening complete. **Paused for founder
approval of hosted apply.** Field Manual still has the broader grants from
`20260919120000`–`120400`. This document does **not** claim hosted ACLs are
fixed.

```text
M10_MEMBERSHIP_PRIVILEGE_HARDENING_LOCAL=true
M10_MEMBERSHIP_PRIVILEGE_HARDENING_HOSTED=false
HOSTED_ACL_FIXED=false
M10_SPRINT_3_STARTED=false
HOSTED_MUTATIONS=0
HOSTED_RELATIONSHIP_ROWS=0
PHONE_BUILD_REQUIRED=false
REPO_ENV_CHANGED=false
PUSHED=false
```

Binding:
[`../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md`](../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md)
§10 and §17.6.

---

## Original deployed limitation

After schema-only apply of `20260919120000`–`120400` on Cohort Field Manual
(`otnhhdxstdnwccehacku`, ledger 95 / max `20260919120400`):

- Consent tables and `publisher_athlete_roster` had `authenticated=arwdDxtm`
  (full table ACL) from **default privileges**, even though `120300` granted
  only SELECT and enabled RLS deny-writes.
- Several `cohort_publisher_athlete_*` functions retained default **PUBLIC**
  and **anon** EXECUTE (`=X/postgres` plus `anon=X`).
- Internal helpers `expire_pending` and `assignment_is_own` were executable by
  `authenticated`.
- Trigger functions had PUBLIC/anon EXECUTE and no `search_path`.

Zero invitation/membership/event rows existed. Functional exposure was blocked
by RPC `auth.uid()` checks and RLS `WITH CHECK (FALSE)` / `USING (FALSE)`.
Grants were still narrowed so PostgREST/default-privilege leakage cannot become
a second write path.

## Direct-table decision

Production Dart does not query `publisher_athlete_*` tables. Isolation services
are in-memory; capabilities use `cohort_athlete_runtime_capabilities`. All
hosted reads/writes are typed RPCs. Hardening therefore **revokes authenticated
SELECT** on the three tables and the roster view. `service_role` retains SELECT
(and DML except UPDATE on append-only events).

## New migration

`supabase/migrations/20260920120000_publisher_athlete_membership_privilege_hardening.sql`  
SHA-256: `642b295889c0ea91a185a439f8fec46b6cc7b657ea41055e3c9e61503224870c`

Does not edit `20260919120000`–`120400`. Creates no relationship rows.

## SECURITY DEFINER

Client RPCs and helpers remain owner `postgres`, `search_path=public, pg_temp`,
identity from `auth.uid()`. Unauthorised publishers receive `unauthorised`
before athlete profile lookup. Trigger functions now set the same search_path.
No dynamic SQL. No function-body behaviour change except grants + trigger
`search_path`.

## Local test evidence

- Static membership + Phase 1 chain tests: pass
- Consent/isolation + enrolment-is-not-membership: pass
- M9 content-graph / assignment pin: pass
- Changed-file `dart analyze`: no issues
- `git diff --check`: clean
- Local DB reset/reapply + Gate AY ACL: `ALL LOCAL DB GATE CHECKS PASSED`
- Phase 2 safety gate: `PHASE2_CONSOLIDATION_SAFETY_GATE=PASS`
- Full `flutter test`: recorded in the verification closeout below

## Capability anon EXECUTE — Option B

Production never **requires** `cohort_athlete_runtime_capabilities()` before
authentication. The sole production caller is
`AthleteAppShell._loadHostedCapabilities()` (`lib/features/app_shell/athlete_app_shell.dart`),
which runs after `AuthGate` has already chosen Login vs athlete shell.
`AuthGate` / `CohortPlatformApp` do not await the RPC. Cold start with no
session presents `LoginScreen`. Failures (permission-denied `42501`, missing
function `PGRST202`/`42883`, expired JWT, network, or
`authentication_required`) map to `AthleteRuntimeCapabilities.unavailable`.
Build 7 ignores unknown keys and does not call the RPC from the sign-in
screen.

`20260913120000` and later already `REVOKE ALL FROM PUBLIC, anon`. Hardening
restates the same grant. Hosted empty-state “anon_caps” probes used the
Management API / postgres role, not PostgREST `anon`. Revoking anon EXECUTE is
therefore not a behaviour change for PostgREST; it must not be described as
leaving a previous PostgREST-anon grant in place.

M10 management RPCs remain: no PUBLIC EXECUTE, no anon EXECUTE, authenticated
EXECUTE only on intentional client RPCs.

## Staging SIGTERM classification

`test/staging/s17_jd_nontest_runtime_proof_test.dart` test `2-7 creator +
execute loopback HTTP proof` isolated **3× pass** on this branch (~1:21–1:44)
and **pass** on a clean worktree of `origin/main` `84d20b7` (~1:43). No Flutter
processes were running beforehand. Hardening commits do not touch the
launcher. `s17_jd_nontest_launch.sh` **intentionally SIGTERMs** the `flutter
run` process group after the result file appears. Full-suite exit 2 with
`Terminated: 15` is a waiter/`killpg` race when job control is not isolated
under concurrent `flutter test`, not a product or M10 ACL failure.

**Classification: 3 — confirmed environmental/harness flake**, with a
deterministic containment defect (shared process group `killpg`). Fixed in a
separate commit: do not `killpg` the waiter’s group; honour `ok:true` if the
waiter dies during intentional cleanup. Regression:
`test/staging/s17_jd_nontest_containment_test.dart`.

After founder approval only: apply **this one file** to Field Manual, then
read-only ACL + zero-row proof. Do not create invitations. Do not start Sprint 3.

## Rollback / forward repair

Forward: re-apply this file (REVOKE/GRANT is idempotent). Rollback: restore
previous grants from `120100`/`120200`/`120300`/`120400` without rewriting the
ledger. Do not drop M10 tables.

## Hosted state at this checkpoint

Ledger still max `20260919120400`. Relationship rows 0. Manifests, assignments,
phone, and repo `.env` were not mutated by this task.
