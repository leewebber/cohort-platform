# Running / Pace Foundation B2 — first-pass implementation contract

**Status:** Pure-domain foundation implemented. Percentage policy awaits
founder review.
**Recorded:** 2026-09-27
**Branch:** `feat/running-pace-foundation-b2`
**Base:** `origin/main` `eed04352e00f3d2605507ce8bf9711d2de8b4030`
**Parent:**
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)
**B1:**
[`Running_Workout_B1_Implementation_v1.md`](./Running_Workout_B1_Implementation_v1.md)

```text
RUNNING_PACE_FOUNDATION=B2_PURE_DOMAIN_FOUNDATION_IMPLEMENTED
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
| Structured run intent | `RunningWorkout` v1 in `lib/domain/running_workout/` | calculated values remain outside authored targets until freeze composition is approved |
| Executable prescription | `performance_protocols` + `session_blocks` | no runtime wiring |
| Occurrence | fixed-schedule occurrence / Daily Journey identity | future freeze owner; unchanged now |
| Benchmark evidence | no B2 canonical store exists | pure input facts only in this pass; no persistence or capture UI |
| Actuals | `training_block_results.result_data` and immutable snapshots | never read as prescription and never rewritten |
| Display calculations | `EnduranceMetricsCalculator` and `IntervalResultMath` | actual/display helpers are not B2 methods |
| Device evidence | not implemented | no provider types, export, import, or Garmin work |

The code slice is pure Dart and in-memory. It now:

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

It contains no selected/default policy. Callers must explicitly supply every
eligibility, freshness, percentage, and rounding value. It must not contain
zone names, athlete or programme lookup, persistence, occurrence freeze,
override, UI, SQL, or hosted integration.

## Decisions still open

| Decision | Bound direction | Founder decision still required |
|---|---|---|
| Benchmark eligibility | exact 5 km completed tests only; source kinds and manual eligibility are explicit policy fields; arbitrary activities fail | which source kinds the first production policy admits; what makes external evidence trusted; treatment of treadmill results, pauses, and course conditions |
| Percentages and ranges | transparent percentage of benchmark **speed** | exact bands, target keys, which authored steps may reference each band, and whether any point target is permitted |
| Freshness | stale, future-dated, or missing evidence fails closed; the supplied window is inclusive in athlete-local civil days; 90 days is the existing candidate | bind 90 days or another programme-owned window in the first production policy |
| Units and rounding | evidence is exact 5000 m plus elapsed ms; calculation remains exact rational ms/km; display rounding is explicit policy | select the first production display increment/direction and later mile-presentation version |
| Freeze | earliest execution commitment: successful device export or first in-app start; today only first start exists | persistence owner, atomic/idempotent transaction, retry identity, and preparation-versus-start boundary |
| Override | only when immutable programme policy permits; preserve original, override, source/reason, and time | actor, bounds, mandatory reason set, pre/post-freeze timing, and whether an override itself is immutable |

No production calculator may be composed until the applicable rows above
are approved and encoded in an immutable programme policy.

## Founder-review proposal — not executable authority

Propose method id `cohort_5k_speed_percentage`, version `1`, with an exact
5 km TT or trusted 5 km performance, a 90 athlete-local-day inclusive
freshness window, and these deliberately neutral target keys:

| Target key | Benchmark-speed range |
|---|---:|
| `b5k_65_75` | 65–75% |
| `b5k_75_85` | 75–85% |
| `b5k_85_92` | 85–92% |
| `b5k_92_100` | 92–100% |
| `b5k_100` | 100% point target, benchmark-replay contexts only |

The neutral keys avoid claiming that a 5 km performance defines easy,
threshold, interval, or any other physiological zone. The bands are
continuous and intentionally overlap at their boundaries so programme
authors can select a transparent intensity envelope without a hidden
table. A 20:00 5 km would yield, before presentation rounding:
`5:20–6:09/km`, `4:42–5:20/km`, `4:21–4:42/km`, and
`4:00–4:21/km` respectively.

This is a review proposal only. It must receive founder coaching review
before the values or keys appear in executable policy, programme content,
or athlete UI. Approval must also choose explicit rounding. No authored
word such as “easy” or “threshold” is automatically mapped to a band.

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
- B1 model, timers, programme sources, Bali pin/graph/occurrences/evidence,
  database, hosted systems, and production composition remain unchanged.

## Deferred next slice

After founder policy approval, encode the approved values as an immutable
programme-policy artifact and add deterministic serialization/replay tests.
Persistence and an atomic occurrence freeze remain a later, separately
reviewed slice.
