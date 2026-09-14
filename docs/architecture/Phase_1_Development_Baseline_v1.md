# Phase 1 development baseline

Do not commit secrets, device IDs, signing identities, or production JSON
contents. Do not rewrite repository `.env` for release builds.

## Toolchain (closeout machine, informational)

Flutter 3.44.x stable / Dart 3.12.x. Confirm locally with `flutter --version`.

## Clean worktree workflow

1. `flutter pub get`
2. No committed code generation step is required for the athlete app.
3. Local database (Docker): `./supabase/tests/run_local_db_gate.sh`  
   This starts an isolated stack, applies the full migration chain from a
   schema-only baseline, and repeats reset. It never contacts hosted
   projects.
4. Analyze: `flutter analyze` (repository still has a large warning
   baseline; changed-file analyze must be clean).
5. Focused tests: pick the capability files in
   [Phase_1_Test_Suite_Inventory_v1.md](./Phase_1_Test_Suite_Inventory_v1.md).
6. Full suite: `flutter test`
7. Safety gate: `./tool/testing/run_phase2_consolidation_safety_gate.sh`
8. Preview: `flutter run -t lib/main_<preview>.dart` with loopback config
   from [tool/release/README.md](../../tool/release/README.md).
9. Production iOS **preparation** (do not embed paths):

```bash
./tool/release/build_app.sh \
  --env production \
  --target ios \
  --config /absolute/path/outside-git/client.defines.json
```

Override display version at build time with `--build-name` / `--build-number`
when cutting a founder install. Install over an existing bundle ID only with
explicit founder authority. This closeout does not install a phone build.

Seed/fixtures for previews stay in `lib/preview/` and `lib/main_*_preview.dart`.
They are not production data.
