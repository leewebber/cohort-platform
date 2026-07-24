# Athlete Programme Switching V1

Athletes can self-serve switch to another published programme from the athlete **Programme** screen without coach approval.

## Flow

1. Home → muted **Programme** link (below Today).
2. Programme screen → muted **Start New Programme** at bottom.
3. Catalogue lists published, non-archived, non-blocking programmes.
4. Tap a row → confirmation dialog → **Start Programme** calls `ProgrammeAssignmentService.cancelOrReplaceActiveAssignment` (or `assignProgramme` if none active).
5. Today refreshes via `HomeTodaySessionRefreshController`.

## Services

- `AthleteProgrammeSwitchCatalogService` — read-only catalogue filter.
- `AthleteProgrammeSwitchCoordinator` — assignment orchestration only.
- `AthleteProgrammeSwitchServices` — production wiring.

## Assignment lifecycle

Previous active assignment → `ProgrammeAssignmentStatus.reassigned` with `supersededByAssignmentId` pointing at the new assignment. Slot outcomes and prior assignment rows are retained.

## Database / RLS

No migration. Reuses existing assignment and catalogue RLS for the signed-in athlete.

## Tests

`test/programme/athlete_programme_switch_test.dart`
