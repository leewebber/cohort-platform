# Running / Pace Foundation B2 — first-pass implementation contract

**Status:** Pure-domain calculation, evidence, policy, frozen-snapshot, Plan
Package v2 authored-running publication foundation, manual benchmark evidence,
side-effect-free SQL selection/calculation, and atomic occurrence freeze
persistence implemented locally.
**Recorded:** 2026-09-27
**Branch:** `feat/running-pace-foundation-b2`
**Base:** `origin/main` `eed04352e00f3d2605507ce8bf9711d2de8b4030`
**Parent:**
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)
**B1:**
[`Running_Workout_B1_Implementation_v1.md`](./Running_Workout_B1_Implementation_v1.md)

```text
RUNNING_PACE_FOUNDATION=B2_OCCURRENCE_FREEZE_IMPLEMENTED_LOCAL
PLAN_PACKAGE_V2_AUTHORED_RUNNING=IMPLEMENTED_LOCAL_UNPUBLISHED
RUNNING_TARGET_OCCURRENCE_FREEZE=IMPLEMENTED_LOCAL
RUNNING_WORKOUT_B1=COMPLETE
PACE_CALCULATION_B2=AUTHORISED_FIRST_PASS
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
```

## Purpose and authority

B2 establishes a transparent, reproducible calculation boundary. It
does not author programme content or make a calculated value executable.
Five authorities remain separate:

1. authored workout intent;
2. the immutable programme-version calculation policy;
3. athlete benchmark evidence;
4. the calculated target snapshot frozen for one occurrence at execution
   commitment; and
5. the completed result.

A 5 km result is benchmark evidence. It is not threshold pace and does
not create physiological zone authority.

## Existing data and runtime boundaries

| Concern | Existing authority | B2 first-pass rule |
|---|---|---|
| Programme and policy ownership | immutable `programme_versions` pin plus protocol revision | no Plan Package, programme, protocol, or pin change |
| Structured run intent | `RunningWorkout` v1 in `lib/domain/running_workout/` | authored intent remains immutable; advisory calculations freeze separately at execution commitment |
| Executable prescription | `performance_protocols` + `session_blocks` | advisory snapshot does not rewrite executable prescription |
| Occurrence | fixed-schedule occurrence / Daily Journey identity | owns one immutable advisory aggregate when an attached v2 slot first starts |
| Benchmark evidence | dedicated athlete-scoped 5 km evidence and append-only revisions | authenticated explicit manual-test command remains authoritative; unproven Cohort ingestion is blocked |
| Actuals | `training_block_results.result_data` and immutable snapshots | never read as prescription and never rewritten |
| Display calculations | `EnduranceMetricsCalculator` and `IntervalResultMath` | actual/display helpers are not B2 methods |
| Device evidence | not implemented | no provider types, export, import, or Garmin work |

The calculation domain is pure Dart and in-memory. It now:

- represents an exact 5 km benchmark duration;
- retains stable athlete-scoped evidence identity, exact distance, elapsed
  duration, athlete-local test date, IANA timezone, completed-test declaration,
  and source provenance;
- represents explicit versioned policies with source eligibility, civil-day
  freshness, percentage range, and display rounding;
- admits manual evidence only when declared as a completed 5 km test;
- selects the newest qualifying benchmark deterministically, using stable
  identity to break same-date ties;
- returns typed failures when no benchmark qualifies;
- represents speed percentages as integer basis points;
- calculates an exact rational pace in milliseconds per kilometre;
- calculates a pace range while preserving the inverse speed/pace order;
- requires an explicit rounding choice at the caller boundary; and
- exposes stable validation failures.

The SQL foundation applies the same selection and calculation rules through
shared golden vectors. It contains no selected/default percentage policy. A
coach must explicitly author the method version, exact percentage range, and
stable step scope. The
calculated result is advisory. Neither foundation may contain zone names,
override behavior, UI, or hosted integration.

## Founder decision — explicit authored targets only

- No automatic workout-type-to-band mapping.
- No global or default percentage bands.
- Easy, recovery, open, and new-test sessions have no numeric pace by default.
- A coach-authored numeric target must name its policy/method versions, exact
  percentage range, and step scope.
- The target is advisory and cannot replace authored intent.
- Initial evidence is a completed Cohort 5 km test or an explicitly declared
  completed manual 5 km test. Elapsed time includes pauses.
- Freshness is 90 athlete-local civil days inclusive; day 90 is valid.
- Exact calculation is retained internally; display rounds to the nearest
  second per kilometre.
- Treadmill/outdoor context is retained and is not automatic equivalence.
- External import remains deferred.

## Decisions still open

| Decision | Bound direction | Founder decision still required |
|---|---|---|
| Treadmill/outdoor | evidence context is retained | whether a policy may explicitly permit cross-context use and what warning is required |
| Device export freeze | earliest execution commitment remains successful device export or first in-app start | provider/export transaction boundary remains deferred |
| Override | only when immutable programme policy permits; preserve original, override, source/reason, and time | actor, bounds, mandatory reason set, pre/post-freeze timing, and whether an override itself is immutable |

No cross-context or override behavior may be inferred from the implemented
first-start calculation boundary.

## Frozen target snapshot

The pure-domain snapshot is schema-versioned, immutable, and advisory. A
calculated snapshot retains:

- policy id/version and method id/version;
- exact authored minimum/maximum speed basis points;
- exact workout and step scope;
- selected benchmark identity, athlete, exact 5000 m, elapsed milliseconds,
  local test date, IANA timezone, provenance, declaration, and surface context;
- exact rational faster/slower pace bounds;
- display rounding increment/direction; and
- UTC freeze timestamp and source (`inAppStart` or future `deviceExport`).

No authored policy, or missing/stale/ineligible evidence, freezes an explicit
`intent_only` snapshot. It never fabricates numbers. Once a calculated or
intent-only snapshot exists, retry returns that snapshot unchanged even when
new evidence or a later policy is supplied.

## Plan Package v2 authored-running authority

Plan Package v1 canonical output and publication payloads remain unchanged.
Version 2 may add one optional `authored_running_v1` document to a session
slot. The document explicitly declares a stable workout identity, all stable
step identities, and one or more advisory attachments. Every attachment names
its stable step scope and supplies its policy/method versions, benchmark-source
eligibility, athlete-local freshness, exact speed-percentage range, and display
rounding. There are no workout-type mappings or default bands.

The private v2 publication payload carries the compiler's exact canonical JSON.
Its service-role-only RPC recomputes SHA-256 from those exact bytes, compares
the compiler-owned payload structures with the canonical document, validates
the authored-running shape independently in SQL, and persists it on the
immutable published session slot. A post-publication mismatch raises and rolls
back the transaction. The existing v1 RPC is not replaced and Apollo/Bali stay
on that unchanged path.

## Storage and transaction boundary

The current fixed-schedule start authority is
`cohort_create_or_resume_fixed_occurrence_at`. It locks the occurrence and
assignment, validates the immutable pin and authored graph, locks the outcome,
then creates and links one `training_sessions` row in the same transaction.
Retries return the existing linked session.

The additive occurrence-scoped authority is:

```text
programme_occurrence_running_target_snapshots
  occurrence_id UUID PRIMARY KEY REFERENCES programme_schedule_occurrences(id)
  athlete_id UUID NOT NULL
  assignment_id UUID NOT NULL
  snapshot JSONB NOT NULL
  frozen_at TIMESTAMPTZ NOT NULL
  freeze_source TEXT NOT NULL
    CHECK (freeze_source IN ('in_app_start', 'device_export'))
  training_session_id BIGINT NULL REFERENCES training_sessions(id)
```

The table is insert-once, immutable, and not client-readable or writable. Only
a published Plan Package v2 slot with a non-null, validated, hash-attested
`authored_running_v1` document participates. Plan Package v1 and v2 slots
without an advisory attachment retain the exact prior start response and write
no snapshot.

On first start, after all existing authority checks, the fixed-start RPC
creates and links the training session, calculates one aggregate for all
explicit advisory attachments, and inserts it before returning success. These
writes share one transaction, so a snapshot failure rolls back the session and
outcome link. The existing occurrence advisory lock serialises concurrent
starts. Retry reads and returns the stored aggregate without selecting newer
evidence. Missing or stale eligible manual evidence freezes `intent_only`.
A future device-export boundary remains deferred.

## Cohort benchmark ingestion boundary

Authenticated athletes may retain an explicitly declared manual completed
5 km test as distinct manual provenance. Cohort test ingestion is fail-closed:
the service-only command returns `cohort_test_completion_unproven` and creates
no evidence.

The blocker is structural, not a title or distance heuristic. The hashed
`authored_running_v1.step_ids` do not map to executable
`session_blocks.block_id`, and the server completion authority does not prove
that one declared running step completed with an exact 5,000 m elapsed result.
Cohort ingestion remains blocked until both are implemented:

1. one immutable authored benchmark step maps exactly to one executable block;
2. terminal completion server-validates that mapped block and its exact
   5,000 m elapsed-including-pauses result.

Neither a session title, athlete assertion, nor an arbitrary logged 5 km
distance may substitute for those authorities.

Stored selection admits only the manual provenance rows created by the
explicit manual command. Pure SQL golden functions mirror the Dart
source-eligibility, athlete/timezone scope, civil-day freshness, stable
tie-break, percentage inversion, exact rational reduction, and explicit
display-rounding rules. The fixed-occurrence start transaction composes those
functions only for explicit hash-attested v2 attachments.

## Acceptance for this first pass

- Formula is percentage of benchmark speed, not percentage of pace.
- Same integers always replay to the same exact rational result.
- Higher speed percentage always produces a lower/faster pace value.
- Range bounds are returned in canonical pace order.
- Invalid duration and percentage fail with stable codes.
- Rounding is explicit and tested; there is no hidden default.
- Day 90 is fresh and day 91 is stale when a policy supplies 90 days.
- Manual completed-test evidence can qualify; an arbitrary 5 km activity
  cannot.
- Multiple eligible benchmarks select newest date then stable identity.
- Snapshot retry never recalculates from a later benchmark.
- Intent-only is itself frozen at execution commitment.
- Example percentage bands are not encoded in production policy or content.
- B1 model, timers, programme sources, Bali pin/graph/occurrences/evidence,
  hosted systems, and athlete UI remain unchanged.

## Deferred next slice

Athlete UI, device export, overrides, Cohort-test ingestion, programme content,
and any Bali adoption remain later, separately authorised slices.
