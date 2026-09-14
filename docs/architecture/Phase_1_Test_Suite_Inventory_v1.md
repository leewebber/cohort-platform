# Phase 1 test-suite inventory

The authoritative green suite is `flutter test` (tags `harness` and
`diagnosis` skipped). Architecture-affecting work also needs
`./tool/testing/run_phase2_consolidation_safety_gate.sh`.

This is a capability map, not a claim that every file is unique or that the
suite should be rewritten to shrink file count.

## High-value contracts

| Capability | Representative tests |
|------------|----------------------|
| Home today / calendar authority | `test/programme/fixed_programme_calendar_authority_test.dart` |
| 84-occurrence Calendar | same file; `athlete_calendar_agenda_test.dart` |
| Incomplete / Train today / swap | `overdue_session_recovery_test.dart`; future-swap SQL gates |
| Backfill chronology | `test/programme/backfill_persistence_test.dart` |
| Completion / cursor | `athlete_programme_completion_self_test_2_test.dart`; Gate L |
| Lifecycle parent vs record | `session_lifecycle_authority_test.dart`; Gates AV and AW |
| EMOM / circuit / interval / strength | `test/performance/emom_score_capture_test.dart` and siblings |
| Production vs preview | `test/core/production_preview_control_scan_test.dart` |
| Adaptation fail-closed | `test/architecture/`; safety gate adaptation group |
| Migration static | `test/supabase/*_migration_test.dart` |
| RLS / identity | `production_rls_lockdown_migration_test.dart` |
| Concurrency / idempotency | start RPC tests; Gate Q; completion idempotency in Gate L |
| Staging journeys | tagged `harness` / `diagnosis` — not default green |

## Known gaps closed in this closeout

- Terminal parent-session trigger + Gate AV
- Historical parent reconciliation + Gate AW
- Calendar vs cursor / evidence vs parent documentation tests
- Preview entry inventory assertions
- Timestamp-ordered migration chain test

## Remaining gaps (not rewritten here)

- Duplicate widget coverage across calendar files (keep; high value)
- Legacy M8 `TrainingSessionSetRepository` still filters parent status
- Product-UI Gate 2 still unverified
- No hosted mutation tests in CI (correct; local Docker gate only)
