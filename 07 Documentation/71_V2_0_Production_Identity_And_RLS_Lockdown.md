# V2.0 Production Identity and RLS Lockdown (Sprint 8)

Sprint 8 removes production `dev-coach` fallbacks and permissive development RLS policies. Coach Studio, catalogue, authoring, publishing, assignment, and athlete access now derive identity from the authenticated Supabase user.

---

## Phase 0 findings

| Location | Identity source (before) | Production risk | Remediation | Release reachable |
|----------|-------------------------|-----------------|-------------|-------------------|
| `ProgrammeCatalogueServices` / `ProgrammeEditorServices` | `ProgrammeDevIdentity.coachId` default | Silent `dev-coach` authoring | `AuthenticatedIdentity.requireCoachId()` | Yes |
| `DevCoachIdentity` | Session or `dev-coach` fallback | Anonymous-style coach access | `AuthenticatedCoachIdentity` (no fallback) | Yes |
| `new_programme_screen.dart` | Hardcoded `ownerId` | UI-supplied ownership | `AuthenticatedIdentity.requireCoachId()` | Yes |
| Training library / programme builder services | `DevCoachIdentity()` default | Silent dev coach | `AuthenticatedCoachIdentity()` | Yes |
| `cohort_programme_dev_coach_id()` (RLS) | `COALESCE(auth.uid(), 'dev-coach')` | Anon writes as dev-coach | Auth-only helper | Yes (hosted) |
| `cohort_programme_dev_athlete_ids()` (RLS) | `ARRAY['lee']` anon fallback | Anon athlete access | Auth-only helper | Yes (hosted) |
| `dev_programme_*` policies (130000–171200) | `TO anon, authenticated` + dev helpers | Additive permissive access | Dropped in lockdown migration | Yes (hosted) |
| `dev_programme_assignments_*` (130000) | Broad athlete insert | Any dev athlete assignment | Dropped; dual-role + coach policies | Yes (hosted) |
| `programme_adaptation_events_dev_*` | Anon + lee fallback | Cross-user adaptation read | Production athlete/coach policies | Yes (hosted) |
| `dev_performance_records_*` | Dev athlete allowlist | Cross-athlete performance read | Auth athlete + linked coach policies | Yes (hosted) |
| `ProgrammeDebugActions` / founder installer | Dev identity fallbacks | Debug paths in release wiring | `kDebugMode` + session-first | Debug only |
| `CurrentUserSession` | Auth profile | Correct source of truth | Retained; extended UX mapping | Yes |

---

## Production identity contract

**Authenticated user:** always `auth.uid()` via `CurrentUserSession`.

**Coach identity:** `CurrentUserSession.coachId` when `profile.isCoach`; required for Coach Studio factories.

**Athlete identity:** `CurrentUserSession.athleteId` when `profile.isAthlete`.

**Dual-role:** same UUID for coach and athlete; self-assignment governed by `programme_assignments_dual_role_self_insert`.

**Missing role:** `AuthenticatedIdentityException` with user-facing message — never a debug substitute.

Implementation:

- `lib/core/services/authenticated_identity.dart`
- `lib/core/services/current_coach_identity.dart` (`AuthenticatedCoachIdentity`)
- `lib/features/coach_studio/coach_studio_access.dart`

---

## Removed fallbacks

- Deleted `lib/core/constants/programme_dev_identity.dart` from production
- Moved test constants to `test/support/programme_dev_identity.dart`
- Debug-only constants in `lib/features/programme/debug/programme_debug_identity.dart`
- Removed `DevCoachIdentity` anon/session fallback from production wiring
- Removed default `coachId = ProgrammeDevIdentity.coachId` from catalogue/editor service factories

---

## Service wiring changes

| Factory | Change |
|---------|--------|
| `ProgrammeCatalogueServices.createController()` | Calls `AuthenticatedIdentity.requireCoachId()` |
| `ProgrammeEditorServices.createController()` | Same |
| `ProgrammeSessionAuthoringServices` | Default `AuthenticatedCoachIdentity()` |
| `SessionLibraryAuthoringServices` | Default `AuthenticatedCoachIdentity()` |
| `CohortProtocolCustomisationServices` | Default `AuthenticatedCoachIdentity()` |
| `CoachStudioAccess.open()` | Catches identity failures → SnackBar |

Tests may inject explicit coach IDs via `createControllerForCoachId` / `FixedCoachIdentity`.

---

## RLS policy audit

Migration: `supabase/migrations/20260722130000_production_identity_rls_lockdown.sql`

Applies **after** `20260722120000_add_dual_role_self_assignment_policies.sql`.

### Policies removed (representative)

All `dev_programme_*` policies on lineages, versions, template tree, assignments, slot outcomes; `programme_adaptation_events_dev_*`; `dev_performance_*` policies. Full list in migration `DROP POLICY IF EXISTS` section.

### Policies retained

- `profiles_*` (211400)
- `profiles_select_linked_users` (211500)
- `coach_athlete_relationships_*`, `coach_athlete_invites_*` (211500)
- `programme_assignments_dual_role_self_insert` (221200)

### Policies created

Production authenticated policies:

- Coach authoring: `programme_lineages_*_coach`, `programme_versions_*_coach`, template tree `programme_version_*_coach`
- Global catalogue read: `programme_*_select_catalogue`
- Athlete assignment/outcome: `programme_assignments_athlete_*`, `programme_slot_outcomes_athlete_*`
- Coach assignment/outcome: `programme_assignments_coach_*`, `programme_slot_outcomes_coach_*`
- Adaptation: `programme_adaptation_events_athlete_*`, `programme_adaptation_events_coach_select`
- Performance: `performance_records_athlete_*`, `performance_records_coach_select`, block/exercise/set results

### Identity helpers updated

- `cohort_programme_dev_coach_id()` → auth coach UUID or NULL
- `cohort_programme_dev_athlete_ids()` → auth athlete UUID array or empty
- Coach SECURITY DEFINER helpers use `auth.uid()` ownership (no `created_by IS NULL` write paths)

---

## SECURITY DEFINER review

| Function | search_path | Auth check | Notes |
|----------|-------------|------------|-------|
| `cohort_auth_is_coach/athlete` | Yes | `auth.uid()` + profiles | New in lockdown |
| `cohort_coach_has_active_athlete` | Yes | `auth.uid()` coach | Unchanged; retained |
| `cohort_auth_is_dual_role_coach_athlete` | Yes | profiles | Unchanged; retained |
| `cohort_accept_coach_athlete_invite` | Yes | invite + athlete | Unchanged; retained |
| Coach lineage/version helpers | Yes | coach role + owner | Updated to auth.uid() |

No caller-controlled identity escalation paths added.

---

## Access matrix

| Actor | Author own programme | Publish own | Self-assign | Train as athlete | Edit other coach programme |
|-------|---------------------|-------------|-------------|------------------|---------------------------|
| Dual-role owner | Allowed | Allowed | Allowed (dual-role policy) | Allowed | Denied |
| Coach-only | Allowed | Allowed | Denied | Denied (no athlete role) | Denied |
| Athlete-only | Denied | Denied | Denied | Allowed | Denied |
| Linked coach | N/A | N/A | N/A (assign linked athlete) | N/A | Denied |
| Unrelated coach | Denied | Denied | Denied | Denied | Denied |
| Unauthenticated | Denied | Denied | Denied | Denied | Denied |

---

## Migration application steps

1. Apply all prior migrations through `20260722120000`.
2. Apply `20260722130000_production_identity_rls_lockdown.sql` to hosted beta.
3. Verify with checklist in migration footer (coach insert lineage, anon denied, dual-role self-assign, linked coach assign).
4. **Legacy note:** rows with `created_by = 'dev-coach'` are not rewritten; they remain inaccessible until ownership is migrated to authenticated UUIDs.

### Rollback considerations

Re-applying dev policies would re-open anon access — not recommended. Safer rollback is forward-fix ownership data, not policy revert.

---

## Hosted verification checklist

1. Sign in as coach → create programme → edit draft → publish → appears in catalogue
2. Sign in as dual-role → self-assign published programme → train on Home
3. Sign in as coach-only → assign linked athlete; self-assign denied
4. Sign in as athlete-only → Coach Studio shows access message; no authoring
5. Anon key without session → programme writes return permission denied
6. Unrelated coach → cannot read private athlete assignment data

---

## Release / debug separation

- Home debug actions remain behind existing `kDebugMode` UI gates
- `ProgrammeDebugIdentity` used only from debug paths with `assertDebugMode()`
- Founder acceptance installer uses authenticated coach when signed in; debug fallback only in debug tooling
- Release builds cannot silently default service factories to `dev-coach`

---

## Tests

| Test | Purpose |
|------|---------|
| `test/core/authenticated_identity_test.dart` | Role resolution, no fallback, account switch |
| `test/core/production_identity_source_scan_test.dart` | Forbids dev-coach in production lib paths |
| `test/supabase/production_rls_lockdown_migration_test.dart` | Migration contract |
| `test/core/user_facing_error_messages_test.dart` | Authorization UX |
| Full suite | 894 passed |

Commands:

```bash
flutter test
flutter analyze
```

---

## Known limitations

- Legacy `dev-coach`-owned programme rows require manual ownership migration on hosted DB
- Global draft write policies removed; founder install requires authenticated coach or service-role seeding
- Coach performance write remains athlete-scoped; coaches have read via linked relationship only
- Organisation-scoped programmes remain denied (unchanged)

---

## Private-beta go/no-go recommendation

**GO** for limited private beta after:

1. Lockdown migration applied to hosted Supabase
2. Lee + beta users sign in with coach/athlete profiles
3. Legacy dev-coach programme ownership migrated or re-created under auth UUIDs
4. Device smoke test: Coach Studio create → publish → assign → train

**NO-GO** for wider launch while legacy `dev-coach` rows remain business-critical without migration.

---

## Related documentation

- `70_V2_0_Beta_Readiness_And_Production_Hardening.md` (Sprint 7)
- `64_V2_0_Authentication_And_Profiles.md`
