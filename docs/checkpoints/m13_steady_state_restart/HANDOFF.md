# M1.3 — steady-state countdown persistence and restart

2026-10-27 (Asia/Makassar). **BOUNDED_COUNTDOWN_FIX_IMPLEMENTED_LOCAL_VERIFIED.**
Overall M1.3 remains partial until the genuine alpha programmes and release candidate
pass authenticated device continuity checks. Local tests are not device acceptance.

Base `632ff8393b8bd07c5b2297517a9ba2728fc4c0c6`; implementation
`2710185c43c36892f032358ca2ce2f5c0b3ba4b9`. Prior `341fbad` and published-base
`1cca598ae1eb879405171114f5dced83cb04bb5a` remain exact linear ancestors.
Controlling [M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M1.1 assessment](../m11_hybrid10k_assessment/HANDOFF.md),
[runtime reliability contract](../../architecture/Daily_Journey_Execution_Reliability_v1.md),
[local persistence contract](../../architecture/Local_Persistence_v1.md).
[Verification and hashes](VERIFICATION.json).

## Athlete behaviour

| Situation | Result |
|---|---|
| Start a Programme Athlete steady-state countdown | Save exact block, prescribed duration, remaining whole seconds and running/paused/finished status in the existing local restore envelope. Foreground timer changes checkpoint locally; they do not write performance actuals. |
| Pause, lock/background or exit timer | Preserve the paused position. Normal timer exit waits for the local checkpoint; failed writes leave the timer open with Retry. |
| Cold restart / abrupt termination | Same authenticated session/assignment/occurrence and active block are validated through the existing launcher/resolver. Resume paused at the last successfully saved checkpoint; no wall-clock catch-up for time closed. Athlete explicitly resumes. |
| Timer reaches zero | Remain finished at zero. No automatic step skip, block completion, result duration/distance, programme advancement or History entry. Review/record actual work through existing capture/completion. |
| Earlier block has a saved timer; active block is untouched | Keep the active block. Do not auto-start its timer because a different block has evidence. Earlier timer positions remain available when that block is deliberately reopened. |
| Local save fails, including native preference refusal | Pause an unfinished countdown, show “Couldn't save timer. Retry before leaving.”, retain entered results and offer Retry. Do not claim a rejected platform write succeeded. |
| Invalid/future cursor, wrong block or changed duration | Fail closed with the existing restore recovery screen. Return Home, or explicitly confirm removal of the local restore envelope. Captured results are retained; no new workout is created. Retry reopens the same record with a safe position. |
| Logout/account switch during timer/save | Scoped keys and restore authority isolate accounts. New checkpoints stop after identity changes; a write already in flight cannot resurrect the signed-out athlete's envelope. Removing the workout routes safely disposes the timer. |
| Authoritative workout completion vs old local timer | Completion wins even when the old timer envelope is corrupt. Do not reopen or submit that workout again. |

Downtime policy reuses the existing Sprint 2 paused-restore rule. No elapsed time
is inferred from the clock. Progress is second-resolution and limited to the last
successful local write; an OS kill before a pending write finishes can lose the
unsaved tail. SharedPreferences remains the existing storage technology, with its
platform durability limits. No offline completion queue or cross-device timer sync
is added. A finished timer still requires honest athlete-entered actuals.

## Canonical path and bounded implementation

Unchanged entry: authenticated Programme Athlete occurrence → atomic
create-or-resume → `SessionExecutionLauncher` → `ProductionRestoreResolver` →
`ActiveSessionScreen` → block timer. Completion/correction/History retain their
existing server and result authorities.

- Added a strict `SteadyStateTimerCursor` in **UI cursor v3**, within the existing
  `ProductionRestoreEnvelope` and athlete/session local repository key. It is a
  companion to actuals, not a source of performance or prescription authority.
- Preserve per-block positions and validate block identity and exact selected
  duration against the current executable plan. Existing identity/package/version/
  occurrence checks remain required before the timer can restore.
- Serialize timer/envelope writes locally and update the memory envelope only after
  the local write succeeds. Timer ticks do not call the hosted performance store.
  Added account-change checks before/after pending local writes.
- Checkpoint start/tick/pause/resume/reset/finish and lifecycle suspension through
  the existing timer screen. Exit is guarded by the save result; reset remains an
  explicit confirmed timer action and does not alter actuals.
- Auto-open only the correct active, incomplete block's saved timer. A finished
  timer reopens finished, without marking the block complete.
- Existing cursor v1/v2 and manual endurance results remain readable. Missing old
  timer metadata is not reconstructed from recorded duration or distance. The B3
  structured cursor remains compatible with both its existing v2 and current v3
  containing envelope; no structured-running prescription contract changed.
- Adjacent necessary fixes: native preference `false` results now signal write/
  removal failure; logout route disposal cannot refresh an unmounted workout;
  authoritative completion takes precedence over a damaged UI envelope.

No `EnduranceResultData`, authored programme, pace/HR target, exercise load,
completion payload, correction or History schema was changed. No Garmin,
distance-ended running, authoring or producer work. Recovery removes only the local
identity/UI companion after confirmation; it never deletes captured actuals.

## Verification

The initial production-route regression reproduced the missing cursor: after starting
and pausing a steady-state timer, `steady_state_timers` was absent from the saved
envelope. The completed implementation passes **23 focused checks** and **488 affected
tests**, including those focused cases; do not add the overlapping counts together.

Coverage includes fresh JSON/dependency-graph restart, active/paused/finished clocks,
two hours closed without counting training, explicit resume/reset, lifecycle events,
workout/block identity, boundaries between blocks, stale duration/active block/future/
malformed state, recovery confirmation/cancellation, retained manual actuals, serialized
writer races, failed writes/exit retry, native platform refusal, foreign account lookup,
logout with pending I/O, route removal and hosted completion precedence. Existing
results/corrections/History, persistence, authentication, B3 launch and completion
regressions pass. Test fixtures are labelled software data, not alpha prescriptions.

All **six architecture safety groups pass**. Fresh full analysis before/final has
the **same 362 inherited diagnostic identities**, zero errors and zero diagnostics
in changed/new files. Full analysis remains non-green; no suppression, dependency
source or analysis configuration changes. Full default Flutter suite, DB replay and
device interactions were not run. No SQL changed, so no new DB gate is claimed.

Interim harness/compilation/style fixes and one wrong test-directory invocation were
corrected; none is counted as successful evidence. Definitive commands, exact log
hashes and preservation results are in VERIFICATION.json.

## Deployment, Git and remaining alpha work

**No migration or hosted deployment is required for this countdown fix.** A reviewed
client build/update is needed to use it on a device; no build, installation or
distribution is authorised/performed here. Separately pending M1.2's one-file hosted
schema/recipient enablement remains governed by its [deployment handoff](../m12_acquisition/DEPLOYMENT.md).
That migration is not applied by publishing this Git change.

The existing task-owned `/private/tmp/cohort_m11_sources` clone was reused on local
main. No new worktree/clone/lifecycle/cleanup operation; all 23 retained checkouts
(including the original dirty checkout) preserve HEADs/branches/indices/files/.temp,
and 28 absent registrations match before/after. Earlier preservation exceptions are
unchanged, not repaired.

One ordinary GitHub main verification retry failed DNS resolution. No alternate
route, network escalation, fetch or push occurred. The implementation and subsequent
evidence commit are local only; remote main freshness/equality is not claimed.
Both previously unpushed checkpoints remain in the exact linear main history.

To close the real alpha journey: complete/approve and admit the genuine Hybrid 10K
and father sources; separately approve schema/publication/recipient operations; obtain
the compatible candidate/distribution route; then prove normal acquisition, timer/
draft interruption/restart, completion, changed correction and History on authenticated
devices. Garmin delivery **and activity return**, governed adaptation, movement guidance,
feedback and release acceptance remain Gate A work. This bounded fix does not close
all M1.3 or Gate A and does not approve any training prescription.
