# Structured Running B3 slice 3 — targets and actuals contract

**Recorded:** 2026-09-30

**Status:** Implemented locally for founder visual and integration review

## Scope

This slice is an opt-in extension of the B3 slice 1 verified launch boundary
and the B3 slice 2 time-based controller. It applies only when a Plan Package
v2 running slot has a hash-attested exact step-to-block mapping and the launch
returns the immutable occurrence-owned B2 target snapshot. Every other session
continues through the existing timer and capture path.

The slice supports positive time-based atomic steps and one-level repeats. It
does not add percentage bands, distance execution, manual laps, programme
content, programme publication, device export, Garmin integration, or a new
prescription authority.

## Frozen target authority

- Typed launch data retains the complete target state, exact rational faster
  and slower pace bounds, display-rounding rule, policy identity and version,
  method identity and version, basis-point inputs, benchmark identity and
  units, eligibility metadata when present, and the internal intent-only
  reason.
- The aggregate, target, workout, attachment, step, mapped block, package
  hash, occurrence, assignment, athlete, programme version, session slot, and
  freeze timestamp must agree. Duplicate target identities, overlapping step
  scopes, invalid units, or a calculated target on a non-work step fail closed.
- Targets are looked up only by exact authored step ID. Titles, labels,
  positions, and list order never establish identity.
- Resume revalidates the complete serialized target and repetition authority;
  it cannot replace the frozen B2 snapshot.

## Athlete presentation

- The timer shows the authored step role and authored block guidance.
- A calculated target is shown only while its explicitly scoped authored work
  step is active, under `Advisory pace target`, using the frozen display
  rounding rule.
- An intent-only work target shows `Pace target unavailable` and exactly:
  `No eligible recent 5 km benchmark was available when this session started.
  Follow the authored guidance. Cohort has not estimated a pace.` Internal
  intent-only reasons are not exposed as different athlete messages.
- Recovery, rest, warm-up, cool-down, open, and unattached steps show no
  numeric target. A calculated target scoped to any non-work step is rejected.

## Repetition actuals and completion

Each authored work repetition has one durable row bound to workout ID, mapped
block ID, authored step ID, repeat ordinal, and authored work duration. The
athlete review choices are:

- `Completed + actual pace`;
- `Completed — pace unavailable`; or
- `Skipped`.

Duplicate, missing, stale, or mismatched rows fail closed. Pending work rows
prevent block completion. A skipped work repetition makes the session
`partially_completed`. Timer expiry only opens the review path; it never
completes a block or session.

Review Session and History render the frozen target separately from the
recorded actual/state. Actual corrections may update actual evidence only and
must preserve target, benchmark, policy, workout, mapping, block, package hash,
and repetition identity.

## Hosted History authority

Migration `20260929120000_b3_structured_running_targets_and_actuals.sql`
derives completion authority from the immutable occurrence snapshot and the
published hash-attested slot mapping. At terminal completion it replaces any
client copy with that server-derived authority, checks every actual identity
and unit, enforces partial completion for skipped work, and prevents later
target mutation. Its helper functions have no direct `anon`, `authenticated`,
or `service_role` execution grant.

The migration is implemented and proved only in a disposable local database.
It is not applied to Cohort Field Manual or any hosted environment.

## Compatibility and fail-closed boundary

V1, Bali, Apollo, unattached v2, non-running sessions, and verified sessions
without slice 3 authority retain their prior execution, capture, completion,
and History behavior. Legacy result rows do not acquire structured-running
authority. Unsupported shapes or stale state stop structured execution rather
than falling back under an ambiguous identity.

## Local controlled fixture

The controlled in-memory v2 fixture proves calculated and intent-only display,
recovery isolation, exact one-level-repeat identities, durable restore,
completed/pace-unavailable/skipped capture, completion status, Review Session,
History, actual-only correction, malformed-state rejection, and legacy capture
compatibility. It is test-only and is neither programme content nor a
publishable programme.

Hosted migration application, hosted programme publication/adoption, and phone
testing each require separate founder authority.
