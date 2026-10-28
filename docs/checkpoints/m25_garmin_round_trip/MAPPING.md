# Cohort representation → Garmin contract mapping

This is an implementation proposal grounded in current source, not an implemented
adapter or certified Garmin Training API payload. Official references G1–G12 and
access date **2026-10-28** are in [SOURCES](SOURCES.md). Resolve all portal-only
fields before any network integration. Preserve the canonical source bytes/hashes.

## Source and capabilities

The actual model is `lib/domain/running_workout/running_workout_model.dart`:
`RunningWorkout(schemaVersion, workoutId, steps, title, intent, notes, provenance)`;
atomic `stepId/role/duration/target/label/notes`; one-level `RunningRepeatGroup`
with `groupId/count/steps`. Protocol/version/assignment/occurrence and physical
block identity come from the execution plan/admission envelope, not fields magically
present on RunningWorkout. Validator count is 1..32, unique IDs, no nested repeats.

`session_blocks.timer_config.running_workout` → `TimerConfiguration` → Programme
Athlete → `AuthoredTimedRunningExecution.fromBlock` resolves accepted target markers
through `running_target_admission.dart`. Existing `runningTargetAdmissionV1` binds
owner, assignment, version/package, protocol, occurrence, physical body/steps,
input/rule/review and canonical session. Quality seconds/km become ms/km ×1000;
confirmed Zone 2 becomes an explicit BPM range. Source body remains unchanged.

| Capability | Present state | M2.5 implication |
|---|---|---|
| Phone workout execution | Ordered timed phases, positive whole seconds, ≤512 expanded phases, repeat count ≤32; pauses on interruption; manual actuals/completion. | A phone clock finishing is not sensor recording, activity import or completion authority. |
| Garmin workout delivery | Missing transport, account connection, delivery receipt and pre-export freeze. | Must explicitly deliver the accepted immutable revision; never send labels with unresolved targets. |
| Garmin activity recording | Garmin hardware/Connect capability, not Cohort code; founder device unknown. | Needs a compatible watch to start/stop/save/sync the activity. Workout download alone cannot create a completed activity. |

Legacy B2 scalar-step mappings are a separate path. Do not merge them with the
full-body adapter or treat B3 phone proof as watch proof. Start the first build on
one original fixed v1/v2 full timed running body; no v3, adaptation, multisport,
multiple-body concatenation or automatic benchmark ingestion.

## Conversion matrix

G7 FIT fields below are **FIT** fields. They must not be copied as guessed Training
API JSON. The live adapter uses portal-specified equivalents and stores exact sent
bytes separately from the accepted prescription.

| Cohort authority | Public contract / proposed mapping | Boundary |
|---|---|---|
| Authored atomic ordering and roles | G7 step indexes and intensities: warm_up→warmup, work→active, recovery→recovery, rest→rest, cooldown→cooldown. Labels/notes retained. | No added/deleted phase, last recovery or implied cooldown; role `open` deferred from first subset. Name is display, never an ownership/matching key. |
| Positive duration milliseconds | G8 FIT `durationTime`: seconds, scale 1000 (raw milliseconds). | First subset requires ms divisible by 1000 as the phone runner does. Typed SDK seconds = ms/1000; don't double-scale. Portal JSON units unknown. |
| One repeat group | G7 repeat marker after children; duration points back to first child's index, target count is number of repetitions. | Preserve a local `(group, iteration, step)` map. Compare expanded order/total to source; no inferred final-rest omission. Prefer compact encoding if documented/live device supports it. |
| `none` | Open target, keeping duration. | No fabricated pace/HR from easy/threshold prose. |
| Accepted pace / pace range (ms/km) | G8 custom speed bounds in m/s, scale 1000. | See conversion rule below. Primary pace only; single-value tolerance/JSON exact-target support is portal-dependent, so initial subset uses explicit ranges. |
| Accepted numerical HR range | G7 custom range with zone selector 0; absolute BPM uses +100 FIT encoding. Example 130..145 BPM encodes 230..245. | This is FIT encoding, not a +100 rule for Training JSON. Never translate confirmed Zone 2 into Garmin's user zone number, max-HR percent or a guessed zone. |
| `heartRateZoneRef`, `qualityPaceRef` | Resolve only through exact accepted immutable Cohort admission. | Missing/stale/withdrawn input before commitment refuses. Unknown references never inferred from names. |
| RPE / authored fallback | G10 notes RPE target unsupported in its partner flow. | No numeric pace/HR conversion. First alpha delivery refuses RPE target rather than silently dropping it. A later reviewed notes-only mode must be explicitly labelled without watch target alerts. |
| Distance (mm), manualLap | Neutral model represents these; current full-body phone runner rejects them. | Defer first adapter; don't convert distance/lap into guessed timed steps. FIT representability alone does not add phone execution. |
| Power, cadence, combined targets, ramps, nesting, other sports | Wider model/FIT features are not this alpha's proved watch contract. | Defer, refuse specifically. No cadence spm→rpm assumption, sensor assumption or silent target removal. More than supported device/API step count refuses, never truncates. |

## Units and deterministic rounding proposal

The existing approved quality calculation stays unchanged: server rounds positive
pace windows to whole seconds/km, exact halves upward, from unrounded intermediates
([approved decisions](../m23_quality_target_admission/DECISIONS.md)). Do not recalculate
from a newer benchmark, displayed min:ss or Garmin user zones during export.

For canonical pace p in **ms/km**, speed is **1,000,000/p m/s**. Range lower pace
is faster, upper pace slower: speedLow=1,000,000/paceHigh and
speedHigh=1,000,000/paceLow. This inversion is essential. Proposed FIT-only
quantisation at 0.001 m/s: round speedLow down and speedHigh up, retain original
rational values plus encoded values and adapter version. Each speed edge expands
by <0.001 m/s. Show the exported target preview/quantisation; refuse collapse,
overflow/nonpositive/invalid endpoints. This transport-rounding policy is proposed,
not an approved change to Cohort prescription or a Garmin JSON rule. Confirm or
revise it against the actual Training contract before live release.

Synthetic calculation example only: 300000..330000 ms/km →
3.030303… ..3.333333… m/s → proposed FIT 3.030..3.334 m/s (raw 3030..3334).
Display pace may differ after conversion; preserve sent and prescribed values so
neither replaces the other. Miles display is not authority (international mile is
1609.344 m); derive display from canonical values only. Distance import uses actual
reported metres → canonical mm once; duration preserves actual timer and elapsed
separately. Never infer distance or average pace from prescribed time/pace.

The retained quality **software fixture**, not Hybrid10K content, is 300 s warm-up,
3×(120 s work + 60 s recovery), 300 s cooldown: 1140 s, eight expanded phases.
A compact FIT representation has five step messages including the repeat marker.
Use it to check order/count/total and pace/HR vectors independently; do not claim
one fabricated mixed-target workout is approved training. Test Garmin/device limits
when known, even though Cohort permits 512 phone phases.

## Identifier and actual-data mapping

Delivery identity must bind: athlete + connection generation + assignment + exact
version/package/protocol + occurrence/slot + physical block/body digest + accepted
input/source/rule/review/snapshot digest + adapter version + delivery revision.
Keep external workout ID, schedule ID, outbound operation ID and returned activity
ID as separate typed references. JSON integer IDs are opaque strings at storage
boundaries where necessary to avoid precision loss. A title/date/payload hash does
not prove a workout/activity ID equivalence.

G8 `trainingFile` corresponds to workout/course file identity; G9 says embedded
workout messages are optional. Verify preserved identifiers from API send through
this exact watch and return; don't promise Garmin echoes Cohort occurrence UUIDs.
Where correlation is absent, use explicit owner-reviewed association, never a
nearest-time automatic completion. Keep individual actual laps/sensor summaries
separate from planned repeat steps; missing/skipped/extra steps are variances, not
rewritten prescriptions. No invented laps, HR, pace or benchmark qualification.

The privacy contract prohibits routes/location consumption and persistence. Prefer
an allowed-metric JSON feed with no coordinate fields. If Garmin cannot exclude
location, do not durably queue/log its raw body or raw FIT; a later dedicated ingress
review must establish filtering/isolation compatible with the binding policy before
use. Ordinary stored raw-FIT inbox design is therefore **not approved**. Store only
allowlisted metrics, external identities/provenance and a safe content digest;
exclude coordinates, location names/bounds and device serials unless explicitly
needed/approved. No inferred athlete timezone from GPS.
