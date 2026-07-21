# 64 — V2.0 Product Readiness: First Slice (Authentication & Profiles)

**Status:** Implemented  
**Phase:** V2.0 product delivery — first vertical slice

---

## V2 product goal

Lee can run all of his own training through Cohort and coach 5–10 private athletes entirely through the app.

Core loop:

```
Coach creates/selects training
  → assigns to athlete
  → athlete sees scheduled training
  → executes and records session
  → progress stored
  → adaptation evaluates
  → future training adapts
  → coach reviews result
```

---

## Audit findings (summary)

### What already works

- Supabase boot via `.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- Athlete training loop for dev athlete `lee`: Home → Today → Session Overview → Active Session → M8 performance save → history
- Programme assignment service (debug-triggered)
- Coach Studio programme authoring (dev-coach)
- Adaptation constraint evaluation UI (no apply path)
- 791 tests passing (20 pre-existing failures)

### Partially implemented

- Physical device run (requires local `.env`, iOS signing)
- Coach assignment (service exists, no product UI)
- Adaptation (evaluate only, no persistence/apply)
- Dev RLS policies (anon + hardcoded identities)

### Missing (before this slice)

- Sign-up / login / logout / session restore
- Profile model and role selection
- Auth-gated app entry
- `auth.uid()`-based data access

### Mocked / local-only

- Hardcoded `lee` / `dev-coach` identities
- Dev RLS allowlists
- In-memory test stores throughout `test/support/`

### Journey blockers (ordered)

| Step | Blocker |
|------|---------|
| Phone launch | `.env` gitignored, no setup docs, iOS signing |
| Account creation | No auth UI or Supabase Auth calls |
| Profile load | No profiles table |
| Coach–athlete link | No relationship model |
| Coach assigns training | Debug-only assignment |
| Athlete sees training | Works once assigned for correct athlete id |
| Execute & log | Works (M8 path) |
| Adaptation | Never applied to prescriptions |
| Coach review | No athlete roster UI |

---

## Selected first slice

**Supabase Authentication + Profile Provisioning + Auth-gated App Entry**

### Why this slice

It is the **earliest broken prerequisite** in the real journey. Without authenticated identity:

- A second user cannot sign up
- Data access remains tied to hardcoded `lee` / `dev-coach`
- No foundation for coach–athlete linking or assignment UI

Skipping auth to implement assignment or adaptation would not work on a physical phone for multiple users.

---

## Architecture reused

| Layer | Components |
|-------|------------|
| Supabase Auth | `supabase_flutter` session + `AuthService` |
| Profiles | `profiles` table + `SupabaseProfileRepository` |
| Orchestration | `AuthController`, `ProfileProvisioningService` |
| Session binding | `CurrentUserSession` (athleteId = auth uid, coachId when role includes coach) |
| RLS bridge | Updated `cohort_programme_dev_athlete_ids()` / `cohort_programme_dev_coach_id()` |
| UI | `AuthGate`, `LoginScreen`, `SignUpScreen`, `ProfileSetupScreen` |

No duplication of programme, performance, or adaptation business logic.

---

## Implementation

### Database

Migration: `supabase/migrations/20260721140000_add_profiles_and_auth_rls.sql`

- `profiles` table (id = auth.users.id, display_name, is_coach, is_athlete)
- RLS: users read/write own profile only
- RLS helpers return `auth.uid()` when authenticated; legacy anon fallback preserved

### Flutter

- `lib/features/auth/` — models, repositories, services, controller, screens, widgets
- `lib/app/app.dart` — `AuthGate` as app home
- `HomeScreen` — uses `CurrentUserSession.athleteId`, logout via display name
- `DevCoachIdentity` — resolves coach id from session with dev fallback
- `ProgrammeDebugActions.devAthleteId` — uses authenticated athlete id when available

### User journey now enabled

1. App launches → auth gate checks session
2. New user signs up → selects coach/athlete roles → profile created
3. Returning user signs in → profile loaded → `CurrentUserSession` bound
4. Home loads with authenticated athlete id
5. Coach Studio authoring uses authenticated coach id
6. User can sign out

---

## Tests

| File | Coverage |
|------|----------|
| `test/auth/auth_controller_test.dart` | Profile provisioning, session bind, errors, sign out |
| `test/auth/auth_gate_widget_test.dart` | Login vs home routing |
| `test/auth/profiles_auth_migration_test.dart` | Migration contract |

---

## Remaining next broken point

**Coach–athlete relationship + programme assignment UI**

After auth, the next gap is:

1. Link coach to private athletes (invitation or roster)
2. Coach assigns programme to linked athlete from product UI (not Home debug)
3. Athlete with new auth uid needs assignment targeted to their uid (not legacy `lee`)

---

## Known limitations

- Legacy `lee` / `dev-coach` data not auto-migrated to auth uids
- Email confirmation behaviour depends on hosted Supabase project settings
- No deep link / URL scheme for password reset on mobile yet
- Coach Studio Athletes section still placeholder
- Adaptation apply path still not implemented
- Full production RLS (drop dev policies) deferred

---

## Mobile considerations

- Auth screens use `SafeArea`, scroll views, full-width tappable buttons
- Keyboard-friendly form fields with appropriate `textInputAction`
- Loading states on sign-in/sign-up/profile setup
- Session restore on cold start via Supabase Auth persistence
