# M2.3 — athlete-confirmed final 10K execution

2026-11-01 (Asia/Makassar). **BOUNDED_LOCAL_EXECUTION_VERIFIED; GATE A OPEN.**
Base and freshly verified published main: `f4396d20ce41ac824aaaff0aa267b89fa3bb4cef`.
[Controlling M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[original timed runner](../m23_structured_timed_running/HANDOFF.md),
[restart policy](../m13_steady_state_restart/HANDOFF.md),
[terminal retry](../m24_terminal_completion_retry/HANDOFF.md),
[Hybrid 10K coverage](../m11_hybrid10k_reconciliation/COVERAGE.md),
[verification receipt](VERIFICATION.json).

## Athlete behaviour and source authority

The existing Programme Athlete launch/controller/local cursor/performance path now
accepts **one atomic 10,000 m work step**, surrounded by the existing whole-second
timed phases. Distance repetitions, multiple distance steps, other distances and
manual-lap endings remain refused. No new workout runtime, sensor, GPS, treadmill
connection or Garmin transport was added. Repository inspection found no trusted
live distance input into this runner; connected-data privacy contracts also exclude
live GPS. No sensor capability or measurement is inferred from a stopwatch.

The representative fixture retains the source's 15-minute warm-up, three 20-second
strides/100-second recoveries, two-minute settle, exact 10,000,000 millimetre work
target and ten-minute cooldown: **33 fixed minutes plus unknown distance-step time**.
Only fixture identity/title/notes are labelled for software review. It is not an
admitted programme, D8 approval or publishable training content. Genuine source and
its older coverage receipts are unchanged. No catalogue lookup or strength-graph
rebuild was repeated against the unchanged evidence.

Preparation advances in authored order. At the distance boundary the phone pauses,
with active time zero; late preparation ticks cannot count toward the test. The
athlete explicitly starts/resumes the distance step. Its screen shows prescribed
**10,000 m**, phone **active time**, pause/resume, guarded exit and **Confirm distance
step finished**. Time alone cannot advance that step. The confirmation dialog says
Cohort has not measured distance and asks the athlete to confirm completion using an
external measured route/watch/treadmill. Cancellation keeps the step paused.
Confirmation advances once to cooldown, paused until explicitly resumed.

The saved confirmation and elapsed phone time are UI progress only. They do not
write actual distance, duration, benchmark evidence, block/session results,
programme completion or progression. Cooldown expiry also does none of these.
Existing explicit result capture, review and canonical completion RPC retain their
authority. A runner confirmation does not replace them; an honest external result
may be entered through that existing path without treating the phone as a sensor.

## Actual results, interruptions and recovery

- Distance-step actuals use existing manual endurance fields, explicitly labelled
  **test segment only**, excluding preparation/cooldown. No prescription or timer
  value is copied into actuals. Record real distance, elapsed duration and optional
  notes; no automatic personalised-target or benchmark ingestion occurs.
- A newly completed test block requires a finite supported-unit actual distance
  of at least 10,000 m and positive entered elapsed time. Empty, shorter, invalid-unit
  and nonfinite results fail completion validation. Keep unfinished work incomplete
  or skipped and use the existing recovery/disposition authority. An abandoned or
  partial record is not a completed benchmark. This is a client input guard, not
  server certification of external measurement or a new benchmark contract.
- Review Session and completed History distinguish prescribed distance from
  manually recorded actuals. Actual corrections retain the complete immutable
  authored body/target snapshot. Existing corrections may correct an inaccurate
  distance downward; a completion label never certifies a 10K benchmark.
- Pause, background/lock and exit pause the active timer. Cold restore resumes
  paused at the last durable step and elapsed active time, with explicit resume.
  **Closed-app time does not count in the phone runner.** A manually entered
  external elapsed result can include that interval and differ from phone time.
- Runner cursor v3 adds distance active milliseconds and confirmation to the
  existing per-block authored-run companion. Cursor v1/v2 remain readable; old
  timed/B3 behaviour and snapshot hashes are retained. Boundary, exact digest,
  step/repeat, block and workout validation reject stale/impossible state.
- Existing owner/session/assignment/version/occurrence checks and ordered local
  writes remain. Account changes stop checkpoints; an in-flight signed-out write
  cannot resurrect the envelope. A failed pause/confirmation save holds the timer
  paused, shows Retry and prevents exit until save succeeds. Restart uses the last
  successful write; an unsaved confirmation cannot be claimed as durable.
- SharedPreferences durability still ends at the last successful checkpoint.
  An abrupt OS kill can lose an unsaved tail. No offline completion queue or
  cross-device timer synchronisation is introduced. Canonical terminal completion,
  replay, correction and History code was not replaced.

## Verification and limits

The pre-edit general admission probe reproduced the exact final-test refusal
`unsupported_timed_running_body` under both package schemas. It passed its five
expected-refusal/source tests. The historical receipt remained byte-identical.
The active probe expectations now recognise bounded 10K support; their complete
source/strength audits were not regenerated. The new fixture independently proves
v1/v2 reviewed graph admission through the same existing validator.

- **62 focused tests pass**, including 23 new distance cases and existing timed/B3
  compatibility. Distance tests cover explicit/cancelled confirmation, no elapsed
  auto-finish, preparation overshoot, duplicate confirmation, cooldown, manual
  actuals, completed/partial/abandoned distinctions, fresh JSON restart, lifecycle,
  source/digest/step/ordinal/future/duplicate corruption, source pinning after local
  envelope removal, account isolation, in-flight logout writes, save failure before
  and after confirmation, guarded exit, retry, corrections and History projection.
- Broader session/performance/programme/History invocation: **774 pass, two expected
  disposable-authenticated-DB skips, one inherited AuthGate failure** at
  `athlete_runtime_capability_bootstrap_test.dart:124` (AthleteAppShell absent).
  The same defect is recorded in the immutable M2.4 checkpoint; no repair or
  suppression was added. Three incorrect directory arguments in that invocation
  also failed loading; the corrected separate compatibility run below passes.
- **208 additional compatibility tests pass** across persistence, running-workout,
  programme fixtures and Plan Packages. Focused counts overlap the broader run;
  do not add them together. Existing completion response-loss/replay tests pass.
- All **six architecture safety groups pass**. Full analysis on immutable base and
  final sources has **362 identical inherited diagnostic identities**, zero errors
  and zero changed-file findings. Full analysis remains non-green (exit 1).
  Initial incomplete nested-dependency analysis and corrected intermediate test/
  lint failures are not green evidence. No analysis/dependency configuration changed.
- An initial concurrent compatibility launch raced Flutter's generated iOS package
  cleanup. Sequential `--no-pub` compatibility passed; no permission was bypassed.
  Full default suite, local SQL replay, hosted checks and installed-device tests
  were not run. No SQL changed; no database-gate success is claimed.

**No migration is required.** Existing timer_config/result prescription JSON and
local UI companion carry the unchanged source body and separate progress/actuals.
Existing held M1.2/Zone 2/quality/terminal-retry migrations remain undeployed.
Older clients may ignore the structured body and run only the 33-minute scalar
subtotal. Publication must wait for compatible-client/device acceptance; there is
no new client-capability publication gate. A Git push is not a hosted deployment.

## Preservation, release gaps and next point

The supplied Developer main remains dirty at `a331f52`; every earlier checkout,
HEAD, branch, index, outstanding file, `.temp` and backup bundle is preserved.
One isolated temporary clone was necessary to preserve all existing HEADs. No
worktree/lifecycle/cleanup operation was used. Before/after hash inventory is
recorded in VERIFICATION.json; only this new clone is changed. Main-only publication
requires fresh ordinary remote ancestry verification and no force/alternate route.

M1.1 still needs legitimate creation/retention capability for the three already
approved setups, followed by complete strength-graph admission. Do not repeat
unchanged lookups or ask for further movement approval. D8 remains independently
pending. Genuine programme admission/publication/access, held migrations, father's
programme, authenticated installed-device acceptance, Garmin access/contracts and
actual delivery/activity return, governed adaptation, distribution and feedback
remain Gate A gaps. This build does not establish D8 or publication readiness.

**Next recommended single build: M4.5 — bounded diagnosis of the inherited
AuthGate bootstrap test failure**, before authenticated M4.2 acceptance. This is a
recommendation, not automatic authority for a new slice. M1.1 catalogue operations
and M2.5 access remain externally blocked; retain their prepared evidence unchanged.
