# Athlete Programme Switching V1

Athletes can self-serve choose another catalogue programme from the athlete **Programme** screen.

> **Sprint 1.3 update:** Production athlete catalogue enrolment uses
> `enrol_athlete_in_catalogue_programme_version` (exact-version pin,
> non-commercial test / closed-beta access). See
> `docs/architecture/Athlete_Catalogue_Enrolment_v1.md`.
> The coordinator below remains for unit/integration tests of assignment replace rules.

## Flow

1. Home → muted **Programme** link (below Today).
2. Programme screen → muted **View programmes** at bottom.
3. Catalogue lists approved, published, `cohort_global`, non-archived programmes.
4. Tap a row → confirmation → **Enrol** via catalogue enrolment RPC (replace active when needed).
5. Today refreshes via `HomeTodaySessionRefreshController`.

## Services

- `AthleteProgrammeSwitchCatalogService` — read-only catalogue filter (approved global).
- `AthleteCatalogueEnrolmentService` — Sprint 1.3 enrolment RPC orchestration.
- `AthleteProgrammeSwitchCoordinator` — legacy assignment orchestration (tests).

## Assignment lifecycle

Previous active assignment → `ProgrammeAssignmentStatus.reassigned` with `supersededByAssignmentId` pointing at the new assignment. Slot outcomes and prior assignment rows are retained.

## Database / RLS

Sprint 1.3 migration `20260801120000_athlete_catalogue_enrolment.sql` — enrolment RPC; athlete identity from `auth.uid()`.

## Tests

`test/programme/athlete_programme_switch_test.dart`  
`test/programme/athlete_catalogue_enrolment_test.dart`

