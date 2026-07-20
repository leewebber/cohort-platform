# Founder Acceptance Programme (Developer Tooling)

## Purpose

The Founder Acceptance Programme provides a **single canonical source of truth** for repeatable founder acceptance and regression testing of the modern block-native protocol flow (M8.1+).

It replaces the manual Session Builder workflow that previously required recreating **M8 Modern Capture Test** before every acceptance run.

```
Shared content definition (lib)
        ↓
Automated tests (test/)
        ↓
Developer install tooling (Home debug)
        ↓
Founder acceptance testing
        ↓
Future milestone regression
```

## Contents

| Asset | Stable ID |
|-------|-----------|
| Programme lineage | `FOUNDER-ACCEPTANCE-PROGRAMME` |
| Programme slug (documentation) | `founder-acceptance-programme` |
| Programme version | v1 (draft, dev-only) |
| Session protocol | `m8-modern-capture-test` |
| Session title | M8 Modern Capture Test |

### Session blocks

| # | Block | Performance capture |
|---|--------|---------------------|
| 1 | Warm-up | Completion |
| 2 | Strength (Back Squat, Bench Press) | Strength |
| 3 | Threshold Run | Endurance |
| 4 | AMRAP (12 min) | AMRAP |
| 5 | Cool-down | Completion |

## Shared builder

Canonical definitions live in:

- `lib/features/founder_acceptance/founder_acceptance_content.dart`

Automated tests consume the same builder via:

- `test/support/m8_modern_capture_test_fixtures.dart` (thin wrapper)

Developer install tooling uses the same `FounderAcceptanceContent` and `FounderAcceptanceInstaller`.

### Self-contained exercise labels

Founder strength block links persist `displayLabelOverride` on each linked exercise:

| Exercise ID | Athlete-facing label |
|-------------|----------------------|
| `SQ-001` | Back Squat |
| `BP-001` | Bench Press |

These labels are defined once in `FounderAcceptanceContent.exerciseDisplayNames` and copied onto block links at install time. The installed programme does **not** depend on unrelated seed data or catalogue records to show usable names during athlete execution, snapshot capture, or training history.

Re-running **Install Founder Acceptance Programme** refreshes founder-owned content idempotently without duplicating exercises or overwriting unrelated user-authored exercises.

## Developer workflow

From **Home → DEBUG** section:

1. **Install Founder Acceptance Programme**  
   Creates or updates programme + session + blocks. Idempotent.

2. **Assign Founder Acceptance Programme**  
   Assigns v1 to dev athlete `lee` (same pattern as Cohort Foundation Test).

3. **Sync Resolved Session** (optional)  
   Projects resolved session into `athlete_state` if needed.

4. Run founder acceptance scenario (Home → Begin → Active Session → Review → Complete → History).

5. **Reset Founder Acceptance Programme**  
   Returns cursor to week 1 / day_1 / slot 1 and clears outcomes.

6. **Resolve Founder Acceptance Programme**  
   Inspect resolution without creating assignments.

## Acceptance process

1. Install (once per environment, or after content changes)
2. Assign
3. Reset (before each clean run — clears programme cursor/outcomes **and** founder session runtime state)
4. Execute M8 Modern Capture Test end-to-end
5. Record observations
6. Re-run targeted automated tests (`test/founder_acceptance/`, `test/m8/`)

## Safety

- Developer tooling only — Home debug cards marked `DEBUG`
- Only touches the Founder Acceptance Programme and `m8-modern-capture-test` session
- **Reset Founder Acceptance Programme** also deletes scoped `training_session_records`, `training_sessions`, and in-memory session execution state for athlete `lee` + protocol `m8-modern-capture-test` (or matching founder assignment id)
- Does not modify unrelated programmes, protocols, or user-authored content
- Uses fixed UUIDs (`FounderAcceptanceDevFixtures`) for idempotent install

## Future milestones

When adding new acceptance scenarios:

1. Extend `FounderAcceptanceContent` (single source)
2. Update automated tests that import it
3. Re-run **Install Founder Acceptance Programme** in dev environments
4. Document new blocks or capture modes in this file

Do not duplicate block definitions in test-only fixtures.

## Related files

| File | Role |
|------|------|
| `lib/features/founder_acceptance/founder_acceptance_content.dart` | Canonical content |
| `lib/features/founder_acceptance/founder_acceptance_installer.dart` | Install/update |
| `lib/features/founder_acceptance/founder_acceptance_runtime_reset_service.dart` | Developer-only founder session runtime cleanup |
| `lib/features/programme/debug/programme_debug_actions.dart` | Assign/reset/resolve |
| `lib/features/home/home_screen.dart` | Debug UI |
| `test/founder_acceptance/founder_acceptance_installer_test.dart` | Installer tests |
| `test/founder_acceptance/founder_acceptance_exercise_labels_test.dart` | Installed label resolution + athlete UI |
| `test/founder_acceptance/founder_acceptance_reset_cleanup_test.dart` | Reset clears performance/session runtime state |

## Prerequisites

- Supabase migration `20260719170000_add_block_performance_capture_mode.sql` applied
- Dev athlete `lee` and coach `dev-coach` RLS policies active

Exercise catalogue records for `SQ-001` / `BP-001` are optional — founder content carries its own display labels.
