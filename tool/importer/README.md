# Founder Importer (pure Dart)

Standalone CLI for Founder Programme YAML import. No Flutter SDK required.

## Setup

From the app repo root, ensure `.env` contains `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and (for apply) `SUPABASE_IMPORT_EMAIL` / `SUPABASE_IMPORT_PASSWORD`.

```bash
cd tool/importer
dart pub get
```

## Usage

```bash
dart run bin/import_programme.dart --dry-run ../programmes/spartan_physique_block1_week1.yaml
dart run bin/import_programme.dart ../programmes/spartan_physique_block1_week1.yaml
```

The Flutter app continues to use `supabase_flutter` via `SupabaseService`. This package uses `package:supabase` and `SupabaseClientHolder.bind()`.
