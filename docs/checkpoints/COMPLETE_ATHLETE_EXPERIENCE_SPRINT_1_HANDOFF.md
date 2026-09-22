# Complete Athlete Experience Sprint 1 — handoff

**Recorded:** 2026-09-22
**Status:** Local implementation complete. Awaiting founder architectural
and visual approval. Not pushed. Not implemented on `origin/main` until
fast-forward.

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=AWAITING_FOUNDER_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
PHONE_UNTOUCHED=true
HOSTED_WRITES=false
PUSHED=false
REPO_ENV_UNTOUCHED=true
```

Binding:
[`../architecture/Athlete_Programme_Discovery_and_Decision_v1.md`](../architecture/Athlete_Programme_Discovery_and_Decision_v1.md),
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md).

**Base:** `origin/main` `3d2213940ae2d6f066fafc30dbd48f71fed2bf14`

---

## Commits (local, linear)

1. `dffa779` `docs(programmes): define athlete decision contract`
2. `7ec3e90` `feat(programmes): add athlete programme details`
3. `43a51ab` `feat(programmes): add authored programme comparison`
4. `8caafe5` `fix(programmes): enforce enrolment decision boundaries`
5. `7441e55` `test(programmes): prove discovery and enrolment integrity`
6. `9c8ea56` `feat(preview): expose programme decision states`
7. this handoff commit

---

## Production surfaces

Programmes tab → `AthleteProgrammeSelectionScreen` (discovery cards) →
`AthleteProgrammeDetailScreen` → optional
`AthleteProgrammeComparisonScreen` →
`AthleteProgrammeEnrolmentReviewScreen`.

Current-programme overview on `AthleteProgrammeScreen` is unchanged
except that Browse still opens discovery.

---

## Authorities reused

- Catalogue list: `AthleteProgrammeSwitchCatalogService` (published,
  cohort_global, approved, not archived)
- Enrolment: `enrol_athlete_in_catalogue_programme_version` only
- Pin: assignment `programmeVersionId`
- Home refresh after successful no-programme enrol

`replaceActive` is ignored. Active assignment blocks enrol without RPC
(except same-version already-enrolled).

---

## Behaviour

**Discovery.** Cards show title, goal, duration, frequency, level,
summary excerpt, and current/available status. Actions: View details,
Compare. No tap-to-enrol.

**Detail.** Authored facts only. Missing emphasis/formats/progression/
recovery are **Not provided**. No IDs, hashes, or lineage codes.

**Comparison.** Exactly two version IDs. Aligned rows. Stacked labelled
rows below 390px or large text. No winner. Open either in detail. Clear
or replace selection.

**Enrolment.** No-programme athletes review then confirm. Active
athletes see `Programme switching is not available here yet.` No
testing-access copy.

---

## Preview

Internal only. Not imported by `lib/main.dart`.

```bash
flutter run -d chrome --web-port 4192 \
  -t lib/main_programme_discovery_decision_preview.dart
```

URL: `http://127.0.0.1:4192/`

Dropdown states: discovery, Apollo/Spartan detail, comparison, missing
facts, enrol review/pending/success/rejected, active current, active
other, empty, unavailable, large-text 320px.

---

## Limitations

- IANA timezone still uses device `timeZoneName` (Sprint 2)
- Replacement is not implemented (not approved)
- Training emphasis/formats/progression/recovery have no authored
  catalogue fields
- Coach-only shell routing unchanged
- Progress/History blockers unchanged

---

## Explicit non-actions

No push, Field Manual, phone install, migration, Sprint 2/3,
replacement, matching, adaptation, payments, WOD Timer, Performance
Portfolio, wearables, Android, or blue brand.
