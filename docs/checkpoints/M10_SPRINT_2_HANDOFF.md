# M10 Sprint 2 handoff — persistent consent membership

**Recorded:** 2026-09-19

**Status:** Local Sprint 2 complete. **Paused for founder architectural, privacy, and migration approval.**

**Branch:** `feat/m10-publisher-athlete-membership-v1`

**Base:** `origin/main` `6233fea6280dd6d560c507dfb38d657c3f1afd43`

```text
M10_SPRINT_2_LOCAL=true
M10_SPRINT_2_HOSTED=false
M10_SPRINT_3_STARTED=false
HOSTED_MUTATIONS=0
PHONE_BUILD_REQUIRED=false
FIELD_MANUAL_CONTACTED=false
MANIFESTS_MUTATED=false
REPO_ENV_CHANGED=false
PUSHED=false
```

**Do not:** push, apply these migrations to Field Manual, create hosted
memberships, infer membership from assignments, publish manifests, rebuild
the phone, or start Sprint 3.

See also
[`M10_MEMBERSHIP_PRIVILEGE_HARDENING.md`](./M10_MEMBERSHIP_PRIVILEGE_HARDENING.md)
for the later ACL-narrowing migration (local; hosted apply paused).

Binding:
[`../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md`](../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md)
§17.

---

## Preflight (audit)

- Athlete identity: `auth.users.id` = `profiles.id` = `programme_assignments.athlete_id`
- Publisher identity: `content_publishers` + `content_publisher_principals.principal_id`
- Legacy: `coach_athlete_relationships` / `coach_athlete_invites` (profile coach, one active coach)
- Capabilities: `cohort_athlete_runtime_capabilities` (schema version 3)
- No M10 table duplicates programmes, pins, or manifests

## Schema

`20260919120000`–`20260919120400`:

- `publisher_athlete_invitations`
- `publisher_athlete_memberships`
- `publisher_athlete_membership_events` (append-only)
- typed `cohort_publisher_athlete_*` RPCs
- `publisher_athlete_roster` (security invoker)
- RLS deny-writes; SELECT own athlete or publisher principal
- capability keys `publisher_athlete_membership_read|invite|manage`
- **Privilege hardening** `20260920120000` (local): revoke PUBLIC/anon EXECUTE
  and authenticated table ALL; RPC-only client access. Hosted apply **not**
  done.

Migration-time row writes: **zero**. No assignment backfill.

Local disposable gate **AY** proves consent, idempotency, cross-publisher deny,
and coach-role-alone deny. Gate script re-applies `20260919120400` after the
historical M9 RLS replay so capabilities remain schema version 3.

## CoachAthleteService

**Legacy retained.** Founder Join-coach / roster screens still use the
profile-coach path. New M10 services do not call it. Deprecate by migrating
those screens in a later sprint.

## Preview

```bash
flutter run -d chrome --web-port 4190 -t lib/main_m10_isolation_preview.dart
```

http://localhost:4190 — internal fixtures only. Not linked from `lib/main.dart`.

## Local verification (this task)

| Check | Result |
|-------|--------|
| Focused M10 domain + static migration | pass |
| Local DB fresh-reset + upgrade/reapply + Gate AY | `ALL LOCAL DB GATE CHECKS PASSED` |
| Apollo binder (twice) | pass |
| Publication artifacts (Apollo + Spartan) | pass |
| Plan Package / enrolment / discipline | pass |
| Phase 2 safety gate | `PHASE2_CONSOLIDATION_SAFETY_GATE=PASS` |
| Full `flutter test` | `3056` passed, `6` skipped |
| Changed-file `dart analyze` | no issues |
| `git diff --check` | clean |
| Full `flutter analyze` | **710** issues (335 error / 114 warning / 261 info). Errors are pre-existing nested-package URI failures (`server/trusted_plan_package_import`, missing `package:shelf`). Changed Dart files added **0**. |

## Hosted / phone

Neither authorised.
