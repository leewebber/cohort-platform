# Local frozen workout and association harness

Software fixtures only. No network, Garmin account, delivery client, hosted SQL,
phone/watch execution, programme mutation or automatic completion.

From the repository root:

```sh
flutter test --no-pub tool/garmin_local/local_harness_test.dart --dart-define=M25_OUTPUT=/private/tmp/cohort_m25_representation.json
python3 tool/garmin_local/verify_representation.py /private/tmp/cohort_m25_representation.json
flutter test --no-pub test/running_workout/fit_workout_representation_test.dart test/running_workout/local_activity_association_test.dart
```

`FrozenRunningFitExport.fromAcceptedPlan` takes an already canonical started fixed
v1/v2 plan, its original execution context/owner/session and an independently retained
snapshot digest. It checks available scope/source/review/rule bindings and freezes
its own copy. It does not authenticate caller-supplied JSON; a future production
caller must obtain the original authoritative server state. It cannot commit targets
before Garmin delivery; that reviewed server lifecycle remains future work.

The converter emits raw documented FIT field values and source/repeat mappings in
JSON. It does **not** emit a FIT binary, `file_id`, assigned manufacturer/product
identity, Garmin API JSON or a remote identifier. The local outward 0.001 m/s
rounding is explicit and retains the original prescribed range; it is not a live
Garmin API rounding contract. One whole-second time body, one-level repeats,
warm-up/work/recovery/rest/cooldown, no target/pace range/BPM range are supported.
Unsupported references, scalar targets, RPE/power/cadence, distance/lap/open,
adapted/v3/multiple bodies and unrepresentable limits refuse without target removal.

The independent Python checker imports no converter code. It inspects generated
raw durations, repeat markers, target units and bounds with Fraction arithmetic and
known fixture vectors, then rejects eight corrupted variants. It is **not a Garmin
SDK/parser**. No FIT SDK was locally installed; ordinary official GitHub SDK
acquisition failed DNS on 2026-10-28. No alternate route was used. Binary encoding,
independent SDK parsing and vendor/device acceptance remain open.

The synthetic association harness distinguishes documented FIT `training_file`
references from proposed workout/schedule IDs whose API contracts are unavailable.
A documented-reference candidate still requires explicit fixture confirmation;
proposed IDs, names, times and distances never establish an automatic association.
Same-key conflicting returns are quarantined because provider update ordering is
unknown. Stable activity dedup identity and authenticated ownership are fixture
assumptions, not verified Garmin guarantees. The delivery fixture derives its digest
from the complete export so scope cannot be paired with a different supplied digest.
Local association never authorises programme completion, including after confirmation.
Manual completion/import concurrency, corrections, durable jobs, reconnect/revocation
and canonical RPC integration are later work, not claims of this harness.

Public sources (accessed 2026-10-28):

- [Garmin FIT Workout fields](https://developer.garmin.com/fit/articles/file-types/workout.html)
- [Official FIT profile](https://raw.githubusercontent.com/garmin/fit-javascript-sdk/refs/heads/main/src/profile.js), observed 21.214.0
- [Controlling audit](../../docs/checkpoints/m25_garmin_round_trip/HANDOFF.md)
