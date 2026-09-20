# M10 Athlete/Coach Management and Isolation — closeout

**Recorded:** 2026-09-20

**Status:** M10 **infrastructure closed**. Deeper coach-platform product work
is **frozen**. The next authorised product sequence is the Athlete Product
Completion Plan.

```text
M10_CLOSED=true
M10_SPRINT_3_STARTED=false
COACH_PLATFORM_FROZEN=true
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_REGION=eu-west-1
HOSTED_HEALTH=ACTIVE_HEALTHY
HOSTED_PG=17.6
HOSTED_LEDGER_COUNT=96
HOSTED_LEDGER_MAX=20260920120000
HOSTED_RELATIONSHIP_ROWS=0
HOSTED_CONSENT_SMOKE=false
PHONE_BUILD=7
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
NEXT_AUTHORITY=ATHLETE_PRODUCT_COMPLETION_PLAN
```

Binding:
[`../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md`](../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md),
[`ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md`](./ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md).

This file does **not** authorise Sprint 3, hosted consent smoke, invitation
creation, roster backfill, manifest mutation, or a phone release.

---

## Why M10 is closed

M10 delivered the **isolation boundary** required before a later coaching
platform: publisher-scoped, consent-based membership that cannot be inferred
from programme enrolment. Field Manual now has the schema, RPCs, RLS, schema
version 3 capabilities, and least-privilege ACLs. **Zero** invitation,
membership, or event rows exist. Lee’s Apollo assignment remains a programme
pin only.

Deeper coaching development is frozen because:

1. The launch product is **athlete-first**, not a coach marketplace.
2. M10 athlete production UI was never in scope.
3. Consent relationships have not been created and must not be inferred.
4. Remaining coach work (invitations UX, assignment from roster, monitoring,
   authoring UI, messaging, teams, billing, white label) belongs to
   **Phase C** after athlete launch and Build Your Own.

`CoachAthleteService` remains the **legacy** profile-coach path for existing
founder Join-coach screens and historical tests. It is not M10 authority.

---

## Sprint 1 — domain slice (local)

Recorded in [`M10_SPRINT_1_HANDOFF.md`](./M10_SPRINT_1_HANDOFF.md).

Publisher-scoped membership isolation in memory: inspect roster, activate
membership, ready / empty / unauthorised / invalid / stale / pin-immutable.
No hosted schema. No athlete production UI. Preview:
`lib/main_m10_isolation_preview.dart` (not linked from `lib/main.dart`).

## Sprint 2 — persistent consent (local, then hosted schema)

Recorded in [`M10_SPRINT_2_HANDOFF.md`](./M10_SPRINT_2_HANDOFF.md).

Consent state machine (UTC):

```text
invitation: pending → accepted | declined | cancelled | expired
membership: (none) → active → revoked
events: append-only; no UPDATE
```

Only the target athlete accepts or declines. The inviting publisher may
cancel `pending`. Transitions are idempotent. A later invite after revoke is
a new invitation and a new membership id. RPCs never enrol, move pins,
publish manifests, or write results.

## Hosted migrations

| Version | File | SHA-256 |
|---------|------|---------|
| `20260919120000` | `publisher_athlete_membership_core.sql` | `2390502a7395c960099ddc9ab8aba2551552ed310991c58cf096563e400d22ee` |
| `20260919120100` | `publisher_athlete_membership_rpcs.sql` | `8371e27f5538d00f8991a8cf3a826b5e8b60b326c21a783f299bf93fdae40309` |
| `20260919120200` | `publisher_athlete_roster_projection.sql` | `b8f8d37e5915f00e4508eaddcde2a8622c9d2796c61d0f82a1e33def186e4697` |
| `20260919120300` | `publisher_athlete_membership_rls.sql` | `46dc29a36120ca8c2e0020799267fb374caf7bd8d7dceb686c17efba583c41d9` |
| `20260919120400` | `publisher_athlete_membership_capabilities.sql` | `1478e9b0a7b34133d24569ddff0a1cfd2cdd3374adb0bc3e665da73a136bda12` |
| `20260920120000` | `publisher_athlete_membership_privilege_hardening.sql` | `642b295889c0ea91a185a439f8fec46b6cc7b657ea41055e3c9e61503224870c` |

`120000`–`120400` were applied schema-only (ledger 90 → 95). Hardening was
applied 2026-09-20 (ledger 95 → 96). No relationship rows were created.

## Consent / RLS / ACL

- RLS: SELECT own athlete or publisher principal; `WITH CHECK (FALSE)` /
  `USING (FALSE)` on writes.
- Client path: typed `cohort_publisher_athlete_*` RPCs only.
- PUBLIC / anon: no table ACL, no EXECUTE on M10 management RPCs.
- Authenticated: EXECUTE on client RPCs; **no** table SELECT/INSERT/UPDATE/DELETE.
- Helpers / triggers: no client EXECUTE; `search_path=public, pg_temp`.
- Events: append-only; service_role has no UPDATE.

### service_role roster-view ACL (accepted limitation)

`publisher_athlete_roster` `relacl` still shows
`service_role=arwdDxtm` (broader default view bits) after hardening’s
`GRANT SELECT`. This is **not** a closeout blocker:

- `service_role` is a trusted administrative role, not PostgREST `anon` /
  `authenticated`
- PUBLIC / anon / authenticated have **no** view access
- `security_invoker=true`
- production Dart does not query the view
- no further migration is required for M10 closeout

## Capabilities

`cohort_athlete_runtime_capabilities` **schema_version 3** on Field Manual
(postgres/owner probe). Keys include
`publisher_athlete_membership_read|invite|manage` reflecting **actor
authority**. Build 7 ignores unknown keys. Anon EXECUTE remains revoked.
Production bootstrap does not require the RPC before login.

## Hosted confirmation (read-only, 2026-09-20)

| Check | Result |
|-------|--------|
| Target | Cohort Field Manual / `otnhhdxstdnwccehacku` / `eu-west-1` |
| Health | `ACTIVE_HEALTHY` |
| PostgreSQL | 17.6 |
| Ledger | **96** / max **`20260920120000`** |
| Invitations / memberships / events | **0 / 0 / 0** |
| Publisher roster | **empty** |
| Legacy `coach_athlete_relationships` / invites | **0 / 0** |
| Publishers / principals | **1 / 1** |
| Manifests | **2** (Apollo v2, Spartan v3; timestamps unchanged) |
| Reconstruction jobs | **0** |
| Lee Apollo assignment | active, pin `2ba018bd-…`, `updated_at` `2026-09-14T15:39:03.588648+00:00` |
| Assignment in roster | **false** |
| Capability schema | **3** |
| Caps / invite anon EXECUTE | **false** |
| Authenticated table SELECT on M10 objects | **false** |

No hosted write was performed for this closeout confirmation. No consent
smoke test.

## Enrolment is not membership

Programme enrolment, catalogue eligibility, coach role, and publisher
ownership do **not** create M10 membership. Gate AY and
`test/athlete_coach_isolation/publisher_athlete_consent_service_test.dart`
remain the local proof.

## Future coach-platform work (frozen until Phase C)

- Invitation / accept / decline / revoke athlete UI
- Hosted consent smoke and first real relationship
- Roster-driven assignment (still must not infer membership from pins)
- Monitoring, messaging, teams, publisher billing
- Migration of Join-coach screens off `CoachAthleteService`
- White label / B2B

Do not start these as the next sprint.

## Recovery / operations

- Forward-only ACL repair: re-apply `20260920120000` (idempotent REVOKE/GRANT).
- Do not rewrite `supabase_migrations.schema_migrations`.
- Do not drop M10 tables.
- Do not backfill membership from assignments.
- Local proof: `./supabase/tests/run_local_db_gate.sh` (Gate AY).
- Phone: founder **build 7** (`1.0.0+7`). M10 did not require a rebuild.

## Founder build compatibility

Build 7 continues to ignore unknown capability keys. Hardening does not
change athlete execution. Missing or denied capability RPC fails closed to
`AthleteRuntimeCapabilities.unavailable`.
