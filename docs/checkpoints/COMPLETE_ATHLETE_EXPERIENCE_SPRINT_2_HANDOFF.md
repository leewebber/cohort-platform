# Complete Athlete Experience Sprint 2 — handoff

**Recorded:** 2026-09-23
**Status:** Local implementation complete. **Awaiting founder approval.**
**Branch:** `feat/enrolment-continuity-v1` (local only)
**Base / start SHA:** `origin/main` `76d792dde237cb035364f76e8e977d2bba2295b6`

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
HOSTED_REPAIR_AUTHORISED=false
HOSTED_APPLY=false
PUSHED=false
```

Binding:
[`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md),
[`../architecture/Enrolment_Start_Integrity_and_Programme_Continuity_Implementation_v1.md`](../architecture/Enrolment_Start_Integrity_and_Programme_Continuity_Implementation_v1.md).

## Range

```text
76d792d docs(programmes): approve enrolment continuity sprint   # origin/main base
bdcb2a9 docs(programmes): define enrolment continuity implementation contract
e04b089 feat(programmes): validate enrolment timezone and local start
4a90822 feat(programmes): project pinned programme continuity
6ade3ff test(programmes): prove enrolment and pin continuity
76cd677 feat(preview): expose enrolment continuity states
74a8f12 test(programmes): enrol remaining SQL fixtures with IANA zones
bb184a8 test(programmes): close enrolment continuity gate fixtures
```

End SHA is the `docs(programmes): record sprint two handoff` commit on this
branch. Sprint 1 and the approved Sprint 2 documentation commits were not
amended.

## Migration

`supabase/migrations/20260923120000_enrolment_iana_timezone_and_local_start.sql`

SHA-256: `32e81d17a4b204ce182529e3142f1ad0f7163a33c274c83745ce0aa00bbbc9df`

Function-only. Same RPC signature `(UUID, TEXT, BOOLEAN)` to avoid
PostgREST overload. No historical migration edited.

## RPC before / after

**Before** (`20260817170000`): stored unvalidated `p_timezone`;
`started_at = CURRENT_DATE`; success JSON omitted date/timezone.

**After:** caller remains `auth.uid()`. Eligibility and
no-active-assignment boundaries unchanged. Exact programme-version pin
unchanged. `p_replace_active` still exists for historical SQL gates only
and is unused by the athlete product. Timezone must match
`pg_timezone_names` and `Region/Name` (reject missing, abbreviation,
offset, `UTC`, `Etc/`). Validation failure creates no assignment,
occurrence, or audit row. `started_at = (now() AT TIME ZONE v_tz)::date`.
Result projects `enrolment_id`, `programme_version_id`, `started_at`,
`timezone`, and status. Repeated confirmation remains
`already_enrolled`. Grants: `authenticated` + `service_role` only;
PUBLIC/anon revoked.

## Timezone capture

No in-repo IANA getter existed. Pinned `flutter_timezone: 4.1.1`
(`FlutterTimezone.getLocalTimezone()`). Device IANA is a suggestion only.
Client and server reject `BST`, `GMT`, `WITA`, `KST`, `UTC`, `UTC+8`,
offsets, and `Etc/`. Persist examples: `Asia/Makassar`, `Europe/London`.
Web uses the browser IANA identifier. No extra permissions.

## Client state

`EnrolmentTimezoneCapture`: detecting / suggestedValid / athleteSelected /
selectionRequired / unavailable. Confirm disabled until a valid IANA name
and a computable local intended date exist. Intended date is labelled
provisional until the server result. Success uses persisted `started_at`
and `timezone`. An active assignment timezone never follows later device
changes.

## Continuity

`AthleteProgrammeContinuity` statuses: `currentDefault`, `currentPinned`,
`currentPinnedWithDifferentAvailable`, `pinnedUnavailable`, `completed`,
`none`. Timezone overlay: `repairRequired` (detect only; no hosted
mutation). Copy is centralised in
`AthleteProgrammeContinuityCopy` for overview, Home, Calendar, and
review.

## Preview

```text
flutter run -d chrome --web-port 4193 --web-hostname 127.0.0.1 \
  -t lib/main_enrolment_continuity_preview.dart
```

URL: `http://127.0.0.1:4193/` — PREVIEW ONLY, no Supabase, no `.env`.
States: Makassar suggestion, London suggestion, athlete change, selection
required, invalid abbreviation, review with intended date, validation
rejected, server-confirmed success, current default, pinned non-default,
different version available, pinned unavailable, timezone repair
required, 320px, large text.

## Repair stop

Safe hosted timezone repair would require assignment mutation and
occurrence regeneration. **Not implemented.** Invalid existing rows fail
closed with repair-required copy. No second RPC. No hosted inventory.

## Verification

| Check | Result |
|-------|--------|
| Local DB reset + replay + gates including AY/AZ | `ALL LOCAL DB GATE CHECKS PASSED` |
| Phase 2 consolidation safety gate | `PHASE2_CONSOLIDATION_SAFETY_GATE=PASS` |
| `flutter test` | `+3215 ~6` all passed |
| Sprint 2 changed-file analyze (new domain/preview) | 0 issues |
| Full `flutter analyze` | 707 existing-repository issues; not introduced as a new baseline |
| `git diff --check` | clean at handoff |

First full-suite run after implementation failed two tests
(Calendar fail-closed copy; migration-chain last filename) and Gate Q/AZ
SQL fixtures. Isolated fixes: Gate Q enrols use `Europe/London`; Gate AZ
creates `auth.users`; destination test accepts unavailable copy; chain
test expects `20260923120000_…`. Reruns passed.

## Limitations

- Hosted apply not run.
- Existing hosted assignment timezones were not inventoried or repaired.
- Replacement / `replaceActive: true` remains unavailable in product UI.
- Active-programme timezone editing and travel rescheduling are out of
  scope.
- Programme-complete Home / Progress / History remain Sprint 3.

## Explicit non-actions

No push, Field Manual, hosted apply, hosted repair, replacement
transaction, phone install, or Sprint 3.
