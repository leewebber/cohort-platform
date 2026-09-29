# Structured Running B3 slice 2 — local implementation handoff

**Recorded:** 2026-09-29

**Status:** Implemented and locally verified; not published or adopted

**Branch:** `codex/b3-structured-running-slice-2`

**Base:** `686ddcdf8c147f388f729f9261ebab2e92a29c27`

**Implementation commits:** `c35234f16a3ad80401b95afdbb9e3d1a91c0559f`,
`02c2d144c819af5d9fc93be6d180ef968357ecda`

**Independent-review fixes:**
`5b5b9981a0bb625b905d8a84128c466672acb1b4`,
`1c5cf3d6f2b212b5ff22bb4dfbae9f4bc554d60b`

```text
STRUCTURED_RUNNING_B3_SLICE_1=INTEGRATED
B3_HOSTED_MIGRATION_APPLIED=true
STRUCTURED_RUNNING_B3_SLICE_2=IMPLEMENTED_LOCAL
B3_STRUCTURED_RUNNER=IMPLEMENTED_LOCAL_TIME_ONLY
B3_ATHLETE_UI=LOCAL_TIME_ONLY
B3_PROGRAMME_ADOPTION=false
B3_DISTANCE_EXECUTION=false
B3_MANUAL_LAP_EXECUTION=false
B3_SLICE_3_STARTED=false
```

## Delivered contract

- The production programme launch path opts in only when B3 slice 1 returns a
  verified v2 running execution mapping, its canonical mapping hash, the exact
  executable session block, and the occurrence-owned frozen B2 snapshot.
- Runtime construction re-projects the pinned B1 workout and validates the
  exact workout ID, authored step IDs, block ID, mapping hash, supported step
  shapes, and positive time units. It never derives identity from titles or
  positions. Any mismatch fails closed before the structured timer mounts.
- The first controller supports positive time-based atomic steps and one-level
  repeats, including work and recovery phases and the final recovery. Nested
  repeats, distance steps, and manual-lap execution remain unsupported.
- The durable cursor preserves the workout and mapping identities, executable
  block ID, authored step ID, repeat ordinal, work/recovery phase, exact
  remaining milliseconds, pause state, manual-evidence state, and finished
  state. Restore validates that complete identity and state envelope against
  the pinned workout before accepting it.
- Pause, app backgrounding, screen exit, and cold restore checkpoint through
  the existing production session-draft persistence path. Resume retains the
  same immutable frozen B2 snapshot supplied by the verified launch result.
- Countdown exhaustion pauses the timer in a finished state. It does not mark
  a block or session complete and does not bypass the existing manual evidence
  and result-capture path.

## Compatibility boundary

- v1, Bali, Apollo, unattached v2, non-running sessions, and any session that
  does not carry the exact verified mapping continue to use the existing block
  timer and capture path.
- Existing version-1 production UI cursors remain decodable. Version 2 adds an
  optional structured-running cursor without changing the legacy cursor data.
- A malformed cursor, a cursor without verified launch authority, or any
  restored workout, block, step, repeat, phase, duration, or hash disagreement
  is rejected rather than silently falling back into structured execution.

## Restore evidence

Focused tests cover all of these exact states:

- pause and cold restore part-way through work;
- app background and screen exit during work;
- cold restore part-way through recovery;
- app background and screen exit during recovery;
- manual-evidence state round-trip during recovery;
- cold restore during the final recovery; and
- finished countdown with no block/session completion callback.

Additional launch and restore tests prove the verified exact-block opt-in,
frozen-snapshot preservation, unattached-v2 fallback, legacy cursor decoding,
and fail-closed mapping and authored-step disagreement.

## Verification

- Structured controller, launch, restore, fixed-schedule, and future-swap
  focused set: 88 passed.
- Production execution, block timer, format restore, Bali, Apollo, launch, and
  structured-controller compatibility set: 76 passed.
- Changed-file Flutter analysis: no issues.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Full authoritative `flutter test` at the original slice-2 handoff
  (`bff292b`): 3,427 passed, 6 expected environment-gated skips.
- `git diff --check`: passed before each implementation commit.

## Independent review follow-up

The 2026-09-29 independent production-path review found and fixed three
execution defects before integration:

- a running cold-restore cursor retained `is_paused=false` but did not restart
  its ticker;
- background/exit used whole timer callbacks instead of monotonic elapsed time,
  which could retain stale sub-second time or miss multiple transitions after
  a delayed callback; and
- malformed or cross-block structured cursor payloads could be treated as an
  absent cursor, while timer exit could pop before a failed durable save and
  could be invoked concurrently.

The fixes restart a non-paused restored ticker, consume monotonic elapsed time
atomically across work/recovery transitions, validate the structured cursor's
schema and enclosing active block, and make timer exit single-flight and
durable-save-gated.

Post-review verification:

- production launch, restore, navigation, timer, and cursor matrix: 61 passed;
- v1 block timer, production restart, Bali, Apollo, fixed/future scheduling,
  programme launch, and structured-running compatibility matrix: 134 passed;
- changed-file Flutter analysis: no issues;
- Phase 2 consolidation safety gate: 6/6 groups passed; and
- `git diff --check`: passed.

## Remaining authority and product gaps

No hosted programme currently adopts a B3 running mapping, so the opt-in route
remains dormant until separately approved programme publication and adoption.
There has been no phone build or founder device review. Athlete pace targets,
new percentage bands, distance execution, manual-lap execution, Garmin/device
export, programme content changes, and B3 slice 3 are not included.

Founder review should confirm the fail-closed restore contract, the manual
evidence boundary, and the time-only phone flow before any adoption or further
slice is authorised.
