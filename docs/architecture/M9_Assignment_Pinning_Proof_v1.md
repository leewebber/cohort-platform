# Assignment pinning proof (M9)

Production already pins `programme_assignments.programme_version_id` at enrolment (`enrol_athlete_in_catalogue_programme_version`) and snapshots `materialised_package_content_hash` at Start Programme. Slot resolver loads that exact version and fails closed on hash mismatch. Catalogue replacement archives the old version; assignments keep the old id.

Local M9 graph restates the invariant:

1. Enrolment selects the unique published catalogue-default version **once**.
2. Assignment stores that version id.
3. Publishing/retiring another version does not rewrite the assignment.
4. Execution/used-by/calendar projections read the pinned version, never “latest”.

Lee’s live Apollo assignment is **not** included in fixtures and must not be repinned.
