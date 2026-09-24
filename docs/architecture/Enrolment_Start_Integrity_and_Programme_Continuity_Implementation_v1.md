# Enrolment Start Integrity and Programme Continuity — implementation contract

**Status:** Local implementation contract for authorised Sprint 2.
**Parent:**
[`Complete_Athlete_Experience_Sprint_2_v1.md`](./Complete_Athlete_Experience_Sprint_2_v1.md)
**Base:** `origin/main` `76d792dde237cb035364f76e8e977d2bba2295b6`

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=APPROVED_NOT_STARTED
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
HOSTED_REPAIR_AUTHORISED=false
HOSTED_APPLY=false
```

This contract is local implementation authority only. It does not licence
push, hosted apply, hosted repair, or a replacement transaction.

---

## Boundary

**In:** validated IANA capture and athlete change; server-derived
athlete-local `started_at`; result projection of persisted date/timezone;
pin-versus-default status; superseded-but-executable and unavailable-pin
copy; unified fail-closed unavailable-pin; repair-required detection
without hosted mutation.

**Out:** replacement/`replaceActive: true`, repin, automatic upgrade,
hosted apply/repair, occurrence regeneration, travel rescheduling,
completion, Progress/History, settings redesign, Sprint 3.

## Timezone

- Persist validated IANA only (`Asia/Makassar`, `Europe/London`).
- Device IANA is a suggested default via `flutter_timezone` (not in repo
  before this sprint; no existing IANA getter). Abbreviation/offset is
  never a fallback.
- Server validates `pg_timezone_names` **and** IANA path shape (must
  contain `/`, reject `Etc/`, abbreviations, offsets).
- `started_at = (now() AT TIME ZONE validated_iana)::date`.
- Same RPC signature `(UUID, TEXT, BOOLEAN)` to avoid PostgREST overload.

## Continuity

Sealed status: `currentDefault` | `currentPinned` |
`currentPinnedWithDifferentAvailable` | `pinnedUnavailable` |
`completed` | `none`. Timezone health is a separate `valid` /
`repairRequired` overlay. Pin metadata only from the pinned version.

## Repair

Detect invalid assignment timezone. No hosted mutation, no occurrence
rewrite, no second RPC. If a later founder task authorises repair, it
must prove timezone-only vs occurrence regeneration.

## Migration

Next collision-free version after `20260920120000`:
`20260923120000_enrolment_iana_timezone_and_local_start.sql`.
