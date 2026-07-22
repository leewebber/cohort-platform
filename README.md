# Cohort Platform

Flutter client for the Cohort training platform.

## Prerequisites

- Flutter SDK (see `pubspec.yaml` for SDK constraints)
- A hosted Supabase project with migrations applied

## Local setup

1. Clone the repository.
2. Copy environment template:
   ```bash
   cp .env.example .env
   ```
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env` from your Supabase project settings.
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Run the app:
   ```bash
   flutter run
   ```

If `.env` is missing or incomplete, the app shows a configuration screen instead of crashing silently.

## Supabase migrations

Apply migrations in timestamp order from `supabase/migrations/`. See `07 Documentation/70_V2_0_Beta_Readiness_And_Production_Hardening.md` for the full ordered list and `07 Documentation/71_V2_0_Production_Identity_And_RLS_Lockdown.md` for Sprint 8 identity/RLS lockdown.

**Sprint 8 requirement:** apply `20260722130000_production_identity_rls_lockdown.sql` before private beta. Coach Studio requires a signed-in user with coach role; the app no longer falls back to `dev-coach`.

## Tests

```bash
flutter test
flutter analyze
```

## Documentation

Product and engineering docs live in `07 Documentation/`. Start with:

- `64_V2_0_Authentication_And_Profiles.md`
- `69_V2_0_Coach_Daily_Operations.md`
- `70_V2_0_Beta_Readiness_And_Production_Hardening.md`
- `71_V2_0_Production_Identity_And_RLS_Lockdown.md`
