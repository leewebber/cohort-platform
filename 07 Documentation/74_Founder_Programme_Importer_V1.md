# Founder Programme Importer V1

Internal developer workflow for loading Lee-authored programmes from strict YAML into Coach Studio as **draft** programmes.

## Workflow

1. Design programme in human-readable form.
2. Translate to Cohort YAML (schema version 1).
3. Run the pure-Dart CLI from `tool/importer`:
   `cd tool/importer && dart run bin/import_programme.dart path/to/programme.yaml`
4. Optional dry-run (no writes):
   `dart run bin/import_programme.dart --dry-run path/to/programme.yaml`
5. Review, validate, and publish in Coach Studio (existing UI).

## YAML schema (V1)

Top-level keys:

- `schema_version` — must be `1`
- `programme` — metadata + stable `import_key`
- `weeks` — nested weeks → days → sessions → blocks → exercises

Exercise resolution order:

1. `exercise_slug` (exact match against published `exercises_v2.slug`)
2. `exercise_name` (exact canonical name fallback — no fuzzy matching)

See `tool/examples/founder_example_programme.yaml`.

## Idempotency

- `programme.import_key` is stored on `programme_lineages.import_key` (unique).
- First import creates lineage + draft version 1.
- Re-import with the same key replaces the draft tree and session protocols.
- If version 1 is **published**, import fails — use a new `import_key`.

## Safety

- Draft lifecycle only (never auto-publish or assign).
- Full validation before any write.
- Uses existing repositories: `ProgrammeVersionStore`, `ProtocolBuilderService`.
- Coach authentication required (`SUPABASE_IMPORT_EMAIL` / `SUPABASE_IMPORT_PASSWORD` in `.env`).

## Database

Migration: `20260724120000_add_programme_lineage_import_key.sql`

Apply with `supabase db push` before first import.
