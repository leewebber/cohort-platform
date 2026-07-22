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

Apply migrations in timestamp order from `supabase/migrations/`. See `07 Documentation/70_V2_0_Beta_Readiness_And_Production_Hardening.md` for the full ordered list and hosted deployment checklist.

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
