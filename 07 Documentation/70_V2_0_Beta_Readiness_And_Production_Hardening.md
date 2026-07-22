# 70 — V2.0 Beta Readiness and Production Hardening

Production-hardening sprint for daily Lee use, 5–10 invited athletes, and a small coach beta cohort. No new product features.

## Phase 0 beta-readiness findings

| Area | Finding | Action |
|------|---------|--------|
| App startup | Missing `.env` crashed at `Supabase.initialize` | Graceful configuration screen |
| Auth | Raw `error.toString()` on profile load failures | User-facing error mapping |
| Home/Today | Good retry card; loader maps schedule errors | Kept; aligned copy |
| Session save | No duplicate-tap guard; raw errors shown | Guard + mapped messages |
| Progression | Non-atomic after performance save (known) | Surface partial failure clearly |
| Sign out | Cleared auth session only | Clear user-scoped caches |
| Account switch | In-memory session/debug cache could leak | Clear on user id change |
| Coach authoring | `dev-coach` fallback in catalogue services | Documented limitation; not expanded in this sprint |
| Tests | 20 baseline failures from UUID fixture drift | Fixed fixtures + assertions |
| Docs | README was Flutter boilerplate | Replaced with setup guide |

## Resolved test-baseline breakdown

Root cause: `InMemoryProgrammeVersionStore.saveTemplateTree` remaps non-UUID slot/day/week ids. Tests still expected legacy ids like `slot-1`.

| Failure bucket | Classification | Resolution |
|----------------|----------------|------------|
| `home_today_session_loader_test` (4) | Outdated fixture/assertion | UUID fixture constants + outcome ids |
| `programme_progression_service_test` (11) | Outdated fixture/assertion | UUID fixtures; slot id expectations |
| `programme_assignment_service_test` (2) | Outdated fixture/assertion | Slot UUID expectations + dev reset outcome id |
| `home_today_session_section_refresh_test` (compile) | Outdated test API | Added required `athleteId`; loading copy |
| `widget_test.dart` | Invalid legacy test | Replaced with AuthGate smoke test |
| `programme_schedule_resolver_test` (11) | Outdated fixture/assertion | Slot UUID constants |
| Other drift from fixture change | Outdated fixture/assertion | Updated `versionId` → `programmeVersionId` param |

**Result:** full suite **878 passed, 0 failed** (was 847 passed, 20 failed).

## Production configuration

- `.env` remains gitignored; `.env.example` documents required keys
- `SupabaseService.tryInitialize()` validates URL/key before init
- Missing config shows `ConfigurationErrorScreen` instead of crashing
- No secrets committed; anon key only in client
- Release paths: Home DEBUG actions remain `kDebugMode`-gated

## Migration order (hosted Supabase)

Apply in filename order:

1. `20260713140000_add_training_session_completion_context.sql`
2. `20260714100000_add_training_session_intervals.sql`
3. `20260714120000_add_training_session_circuits.sql`
4. `20260715120000_add_programme_engine_v1.sql`
5. `20260715130000_add_programme_engine_dev_policies.sql`
6. `20260715140000_fix_programme_dev_rls_recursion.sql`
7. `20260715150000_add_athlete_state_athlete_unique.sql`
8. `20260715160000_allow_dev_programme_outcome_reset.sql`
9. `20260716150000_allow_dev_coach_programme_authoring.sql`
10. `20260717110000_fix_dev_coach_lineage_insert_policy.sql`
11. `20260717120000_fix_dev_coach_programme_version_authoring_policy.sql`
12. `20260718130000_add_training_content_metadata.sql`
13. `20260719140000_add_session_blocks.sql`
14. `20260719160000_add_training_session_records.sql`
15. `20260719170000_add_block_performance_capture_mode.sql`
16. `20260721100000_add_session_lineages_and_revisions.sql`
17. `20260721110000_add_session_revision_usage_indexes.sql`
18. `20260721120000_add_exercise_usage_indexes.sql`
19. `20260721130000_add_programme_version_impact_indexes.sql`
20. `20260721140000_add_profiles_and_auth_rls.sql`
21. `20260721150000_add_coach_athlete_relationships.sql`
22. `20260721160000_add_programme_adaptation_events.sql`
23. `20260722120000_add_dual_role_self_assignment_policies.sql`

### Hosted verification checklist

- [ ] All migrations applied without error
- [ ] Auth email provider configured
- [ ] `.env` populated on test devices
- [ ] Coach beta accounts have `is_coach=true`
- [ ] Athlete invites create pending codes
- [ ] RLS smoke: athlete cannot read another athlete's assignments

## Error mapping

`UserFacingErrorMessages` centralizes copy for:

- Permission denied
- Network failures
- Invalid/expired invites
- Programme assignment failures
- Today's training load failures
- Session save failures
- Missing Supabase configuration

Applied to auth profile refresh, session finish review, and configuration screen.

## Save integrity

- Duplicate "Save and finish" taps ignored while saving
- Performance save failure shows mapped message; no navigation to complete screen
- Progression failure after successful save shows recoverable warning (no false complete navigation)
- Idempotency remains in performance store + progression service (unchanged M8 architecture)

## Refresh and account-switch behaviour

- `UserSessionCache.clearAll()` on sign out
- `CurrentUserSession.bind()` clears caches when user id changes
- Home Today refresh/retry unchanged (already present)
- Coach dashboard refresh after assignment via existing navigation pop + reload

## Beta support surface

Home → **Beta support**

- App version + platform
- Copy diagnostic summary
- Report a problem (clipboard template)

Diagnostics exclude tokens, secrets, health notes, and private athlete payloads.

## Manual beta checklist

### Lee (dual-role coach/athlete)

- [ ] Sign up / sign in
- [ ] Profile with coach + athlete roles
- [ ] Self-assign programme (Personal Training Setup)
- [ ] Today loads executable session
- [ ] Complete session; Home refreshes
- [ ] Coach Home shows self in roster operations
- [ ] Invite athlete; athlete appears after accept
- [ ] Assign programme to athlete
- [ ] Sign out; sign in as different user — no stale Today data
- [ ] Airplane mode on Today → error + Retry

### Athlete-only client

- [ ] Accept invite
- [ ] Today shows assigned training or empty state
- [ ] Complete session
- [ ] Training history shows record
- [ ] Invalid invite shows friendly error

### Coach-only beta tester

- [ ] Coach Home dashboard filters
- [ ] Athlete detail compliance + assign/replace
- [ ] Programme catalogue opens (authenticated coach id)
- [ ] Sign out clears dashboard state on re-login

## Known limitations

- End-to-end save → progression → adaptation is not one database transaction
- Coach catalogue/editor services still default `dev-coach` when auth coach id not injected (Coach Studio paths)
- Dev RLS policies coexist with auth policies — review before public beta
- No offline queue for session save retries
- Beta support copies to clipboard only (no email/ticket backend)

## Beta go/no-go recommendation

**GO for private beta (Lee + ≤10 athletes + small coach cohort)** with the above limitations documented.

Blockers removed: test baseline green, configuration failures visible, session save UX hardened, account cache clearing, beta diagnostics available.

**NO-GO for public launch** until dev-coach fallbacks and dev RLS policies are removed or gated.

## Exact next step after this sprint

Run a structured 1-week private beta using the manual checklist, collect clipboard reports from Beta support, then prioritize coach-id authoring hardening and transactional progression follow-up based on real failure logs.
