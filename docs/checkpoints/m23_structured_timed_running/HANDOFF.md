# M2.3 — complete authored timed running sessions

2026-10-27 (Asia/Makassar). **BOUNDED_TIMED_EXECUTION_IMPLEMENTED_LOCAL_VERIFIED.**
Overall **M2.3 PARTIAL**: approved personal target rules/admission and authenticated
real-device acceptance remain open. Gate A remains open.

Base `dade09f5e40a87768bb23b62b805022d4fb4461c`; implementation `618c53f`.
The earlier `341fbad`, `632ff83`, `2710185` and `dade09f` remain linear ancestors
after the founder-reported published base `1cca598ae1eb879405171114f5dced83cb04bb5a`.
No rewrite, replacement branch, new clone/worktree or cleanup.

Binding: [release plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M1.1 assessment](../m11_hybrid10k_assessment/HANDOFF.md),
[M1.3 restart](../m13_steady_state_restart/HANDOFF.md),
[reliability](../../architecture/Daily_Journey_Execution_Reliability_v1.md),
[local persistence](../../architecture/Local_Persistence_v1.md).
[Verification and file hashes](VERIFICATION.json).

## Athlete behaviour

An exact authored timed workout can open in Programme Athlete as one structured
run: warm-up, main work, repeated work/recovery and cooldown, in authored order.
Each phase shows its exact label (or role), instructions, target, position and next
phase. Foreground countdown expiry advances to the next authored phase; there is
no skip control, inferred phase, added recovery or automatic prescription change.
The entire body determines the total duration, including every authored recovery.
To omit the last recovery, the source must explicitly describe that sequence;
software does not infer an omission from coaching intent.

- Fresh timer starts paused. Start / resume, Pause and guarded Exit are explicit.
- Background/lock/exit pauses the new full-body run. Cold restart restores the
  correct active incomplete block, exact step/repeat and last saved remaining time
  **paused**. Time closed does not advance it. Athlete must resume explicitly.
- A finished timer stays finished at zero. It never completes the block/session,
  advances the programme, creates actuals or submits History. Record the real run
  through existing manual endurance capture and completion review.
- Timer ticks write only the existing local UI companion, not hosted actuals.
  Failed saves pause the timer and offer Retry; exit waits for a successful save.
- Invalid/stale step, repeat, duration, source digest or envelope fails closed with
  existing recovery. Confirmed removal clears only the local UI envelope. Entered
  results remain. Changed/removed workout bodies cannot bypass the prescription
  check by discarding that envelope.
- Scoped athlete/session/assignment/version/occurrence checks, ordered local writes,
  account-change protection, completion reconciliation and existing result authorities
  remain in use. Old completed-session truth takes precedence over local timer state.

SharedPreferences durability remains bounded by the last successful local write.
A process kill before an in-flight write finishes can lose the unsaved tail. This
is local continuation, not cross-device sync or an offline completion queue.

## Shortest canonical path and implementation

Private Plan Package v1/v2 session reference → separately reviewed protocol graph
→ existing private graph publication/storage in `session_blocks.timer_config`
→ `SessionBlock.fromRow` → `SessionExecutionLoader` / `SessionExecutionPlan`
→ Programme Athlete start/resume → existing `SessionExecutionLauncher` / resolver
→ `ActiveSessionScreen` → existing structured-running controller/screen
→ local restore envelope + existing performance draft/completion/correction/History.

The package schemas, hashes, assignment and occurrence contracts are unchanged.
No deferred producer is required. This is an explicit reviewed-JSON graph input;
no new Studio authoring UI or automatic import of coaching prose was added.

- Optional `timer_config.running_workout` carries the existing neutral
  `RunningWorkout` v1 body. Added optional atomic `label`; absent-label encodings
  and existing projection vectors remain compatible.
- The block keeps the existing `steady_state` storage/capture container and an exact
  `durationSeconds` equal to the complete repeated body's time sum. UI calls it a
  structured run. Conflicting scalar settings, ranges, unsupported endings, invalid
  IDs/targets/repeats and more than 512 expanded phases fail closed. Repeat groups
  retain the existing maximum 32 repetitions and no nesting.
- The projector preserves this body. A small derived adapter owns an immutable copy
  and hashes its canonical body, physical block identity and selected total.
  Existing controller/screen/cursor are reused; there is no second athlete runtime.
- UI cursor **v4** adds per-block `authored_timed_runs`; existing v1/v2/v3 envelopes
  remain readable, including M1.3 steady-state checkpoints. New full-body state
  restores paused and never uses the legacy B3 wall-clock catch-up policy.
- The existing B3 verified v2 advisory path and its persistence/result semantics
  remain compatible. New whole bodies explicitly reject mixing with the legacy
  B2 executable-step mapping, whose SQL projection describes scalar timers.
  No empty advisory policy or frozen benchmark result is manufactured.
- Complete bodies are retained in optional `timedRunningWorkoutV1` block snapshots,
  including serialization and corrections. No new actual-result schema is added:
  whole-run endurance actuals remain manually entered. Per-phase measured splits,
  GPS and live HR capture are not implemented.

## Targets, Garmin and genuine programmes

Supported fixed authored pace/range, BPM/range, power/range, cadence/range and RPE
values display without calculation. Pace preserves millisecond precision. An HR
zone reference displays its exact reference plus the explicit absence of resolved
BPM limits; this does **not** configure Zone 2 or supply live HR guidance.

Hybrid 10K remains the general ten-week PB programme for a fit, competent runner,
four runs/two strength sessions weekly. Easy uses configured Zone 2; quality paces
will use a 5K benchmark. Entry standard, exact sessions/durations/progression,
zone configuration and approved pace formulas remain missing. Withdrawn Week 1–2
proposals remain withdrawn. Lee's possible personal adjustment stays separate.
Father's genuine programme still needs founder authoring/admission.

Ordered roles, stable phase/repeat identities, exact time endings, targets and
provenance are now available for a later mapping. Garmin provider formats/access,
resolved HR-zone semantics, full-body personalised target snapshots, connection,
delivery/receipt/watch execution, activity return, athlete/occurrence linking and
duplicate/manual-completion reconciliation remain unimplemented or unverified.
Distance-ended/manual-lap steps and benchmark ingestion remain gaps. No Garmin
capability, export compatibility or approved benchmark formula is claimed.

## Verification and release boundary

- **23 new focused checks pass**, using clearly labelled software fixtures under
  `test/session/fixtures/`; not approved Hybrid 10K content and never published.
  Includes v1/v2 reviewed source, exact order/repetition boundaries, HR-reference
  and exact pace display, fresh serialized restart dependencies, pause/background,
  completion/correction round-trip, failures, stale state and account isolation.
- **1,124 affected tests pass**, including existing steady-state restart, B3,
  programme launch, performance/completion/correction/History, auth, private source
  and Studio regressions. All **six mandatory safety groups pass**.
- Fresh full analysis before/after: **362 identical inherited findings**, zero
  errors, zero changed-file findings. Full analysis remains non-green (exit 1).
  No suppression or analysis/dependency configuration changes.
- Diff checks pass. Preservation inventory before/after is byte-identical for 23
  existing retained checkouts, 28 absent registered worktrees, indices and `.temp`.

**No migration or hosted deployment is required by this local implementation.**
Existing SQL stores complete timer JSON and retains/compares it in the publication
scope seal; result snapshots are existing JSON storage. This is inspection and local
port/widget proof, not a new SQL replay, hosted publication or device acceptance.
New-body publication must wait for an accepted compatible client: older clients
can ignore the body and show only the scalar total. No client-capability gate was
added. Do not publish this source to an unverified client population.

No hosted schema/data/account/assignment/programme changes, build/install,
distribution, real programme approval or browser/desktop control occurred. M1.2's
[separate migration proposal](../m12_acquisition/DEPLOYMENT.md) remains unapplied.
Normal GitHub main lookup failed DNS; remote freshness is unknown and stale cached
`origin/main` is not evidence of remote main. Only ordinary main push is authorised;
no alternate route or network escalation.

**Next single milestone point: M2.3 personalised target admission** — obtain Lee's
approved Zone 2 configuration contract and 5K pace rules with one exact representative
workout, then bind/review its immutable athlete target snapshot. Do not guess those
inputs or adopt the old scalar mapping for a full phased run. Genuine content,
M2.5 Garmin delivery **and activity return**, M3 accepted adaptation and M4
distribution/authenticated device acceptance remain outstanding Gate A requirements.
