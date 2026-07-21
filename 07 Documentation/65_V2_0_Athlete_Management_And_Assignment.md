# 65 — V2.0 Athlete Management and Assignment

**Status:** Implemented  
**Depends on:** V2.0 auth slice (doc 64), Programme Engine, ProgrammeAssignmentService

---

## User problem

Authentication created independent users, but coaches could not link athletes or assign programmes through product UI. Assignment existed only via Home DEBUG actions and hardcoded dev identities.

---

## Phase 0 findings

| Area | Finding |
|------|---------|
| Profiles | Dual-role flags on `profiles` (`is_coach`, `is_athlete`) |
| Coach–athlete model | **Did not exist** — only `programme_assignments.athlete_id` |
| Coach Studio Athletes | Placeholder (`SOON`) with no route |
| Assignment service | `ProgrammeAssignmentServiceImpl` production-ready |
| Home/Today | Uses `CurrentUserSession.athleteId` |
| Catalogue | `ProgrammeCatalogService.listCatalogue(lifecycleStatus: published)` |

---

## Invitation workflow

1. Coach opens Coach Studio → Athletes → **Invite athlete**
2. System generates 8-character code (no UUIDs, ambiguous chars excluded)
3. Coach copies and shares manually
4. Athlete opens Home → **Join your coach** → enters code
5. `accept_coach_athlete_invite()` validates and creates relationship transactionally
6. Invite marked accepted (single-use); expires after 7 days

---

## Relationship model

### `coach_athlete_relationships`
- `coach_id`, `athlete_id` → `profiles.id`
- `status`: `active` | `ended`
- One active coach per athlete (partial unique index)

### `coach_athlete_invites`
- `code` (8 chars, unique)
- `status`: `pending` | `accepted` | `revoked`
- Expiry from `expires_at` (not stored as status)

---

## RLS and security

- Coaches: CRUD own invites; read own relationships; read linked athlete profiles
- Athletes: accept via SECURITY DEFINER RPC only; read own relationship + coach display name
- Coaches: insert/read/update `programme_assignments` for linked athletes via `cohort_coach_has_active_athlete()`
- No invite enumeration; generic error messages on invalid codes

Migration: `supabase/migrations/20260721150000_add_coach_athlete_relationships.sql`

---

## Services

| Service | Responsibility |
|---------|----------------|
| `CoachAthleteService` | Invites, roster, accept, relationship verify, assignment orchestration |
| `ProgrammeAssignmentServiceImpl` | **Reused** — no duplicate assignment logic |
| `ProgrammeCatalogServiceImpl` | Published programme picker |

Repositories: `SupabaseCoachAthleteRelationshipRepository`, `SupabaseCoachAthleteInviteRepository`

---

## Coach UI

- **AthleteRosterScreen** — linked athletes, pending invites, invite/revoke
- **AthleteDetailScreen** — assignment summary, assign programme sheet
- Coach Studio Athletes section enabled (`isAvailableInV01`)

---

## Athlete join flow

- **JoinCoachCard** on Home (athlete-enabled users)
- **JoinCoachScreen** — code entry, validation, success confirmation
- Refreshes Today session after link

---

## Programme assignment flow

1. Coach opens athlete detail → Assign programme
2. Select published programme/version from catalogue
3. Pick start date
4. Confirm (replace warning if active assignment exists)
5. `ProgrammeAssignmentServiceImpl.assignProgramme()` with `replaceExistingActive` when needed

---

## Authenticated identity

All paths use `CurrentUserSession` — no `lee`, `dev-coach`, or manual user IDs in UI.

Home DEBUG assignment section wrapped in `kDebugMode` only.

---

## Tests

- `test/coach_athlete/coach_athlete_service_test.dart` — invite lifecycle, roster, errors
- `test/coach_athlete/coach_athlete_migration_test.dart` — schema contract
- `test/support/in_memory_coach_athlete_stores.dart` — in-memory repositories

---

## Known limitations

- Manual code sharing only (no email/deep links/QR)
- One active coach per athlete
- No coach progress dashboard or compliance UI
- Legacy `lee` data not migrated
- Coach cannot end relationship from UI yet

---

## Next broken point

**Athlete executes assigned training end-to-end without manual intervention** — verify Today resolution after assignment in production Supabase, then **adaptation apply bridge** so completed sessions influence future prescriptions.
