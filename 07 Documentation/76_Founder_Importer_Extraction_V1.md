# Founder Importer Extraction V1

See `tool/importer/README.md` for CLI usage.

## Architecture changes

| Layer | Before | After |
|-------|--------|-------|
| CLI entry | `tool/import_programme.dart` (Flutter + `dart run` crash) | `tool/importer/bin/import_programme.dart` (pure Dart) |
| Importer implementation | `lib/features/founder_programme_import/*` | `tool/importer/lib/**` (`founder_importer` package) |
| App shim | Full Dart sources | `export 'package:founder_importer/...'` re-exports |
| Supabase | `supabase_flutter` + `Supabase.instance` | `package:supabase` + `SupabaseClientHolder.bind(client)` |
| Env | `flutter_dotenv` | `package:dotenv` |
| Flutter binding | `WidgetsFlutterBinding.ensureInitialized()` | Removed |

Flutter app runtime is unchanged: `SupabaseService` and Coach Studio still use `supabase_flutter`.

## Dependency graph

**Before (CLI):** `flutter` → `supabase_flutter` → plugins (`shared_preferences`, `app_links`, …) → `dart:ffi`.

**After (CLI):** `supabase`, `dotenv`, `yaml`, `founder_importer` only.

## Packages removed from CLI path

`flutter`, `supabase_flutter`, `flutter_dotenv`, and federated plugin transitive deps.

## Packages added

`supabase`, `dotenv` in `tool/importer/pubspec.yaml`; app adds `founder_importer` path dependency.

## Tests

`flutter test test/founder_programme_import/` — 44 passed.

## CLI

```bash
cd tool/importer
dart run bin/import_programme.dart --dry-run ../programmes/spartan_physique_block1_week1.yaml
```

Dry-run succeeds with exit code 0 (no VM FFI crash).
