# M2.3 — personalised quality-run target admission

2026-10-27 (Asia/Makassar). **QUALITY_TARGET_ADMISSION_LOCAL_VERIFIED**.
The bounded representative-workout slice is complete locally. Overall M2.3/Gate A
remain open for genuine programme adoption and authenticated device acceptance.

Base `5d260bca7490bbc62d890d3aebc90b35ec5d000b`;
implementation `ce9ec89b79cb5c2fe6dcb4b7eb556bec73fff1fb`.
All ten prior local commits after founder-reported published `1cca598` are preserved,
including M1.1/M1.3, timed running and confirmed Zone 2. Work reused clean retained
main in `/private/tmp/cohort_m11_sources`; no new clone/worktree or lifecycle cleanup.

Binding: [M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M1.1 corrected brief](../../programmes/hybrid_10k/CURRENT_BRIEF.md),
[timed runner](../m23_structured_timed_running/HANDOFF.md),
[Zone 2 admission](../m23_personalised_target_admission/HANDOFF.md),
[M1.3 restart](../m13_steady_state_restart/HANDOFF.md).
[Exact approved rules](DECISIONS.md), [verification](VERIFICATION.json),
[undeployed migration proposal](DEPLOYMENT.md).

## Athlete-visible flow

For original fixed-schedule v1/v2 source containing timed structured bodies with
`alpha_quality_pace_v1` on work steps:

1. Open normally through Programme Athlete. Without an accepted current review the
   first start is refused before any session is created; the launcher opens review.
2. Default source is the athlete's representative 5K. Enter elapsed time (m:ss or
   whole seconds), real YYYY-MM-DD date and explicitly confirm a sustained effort.
   Save/confirm the owner input; this action does not start training.
3. Alternatively explicitly select manual threshold, enter seconds/km (or m:ss/km)
   and its manual provenance. Only threshold-labelled work can use it. The founder
   approved the ±2% window; manually reading Garmin supplies no connection.
4. Review the input/source, estimated P5/P10, exact per-work-step whole seconds/km
   windows, rule/version and limitations. The session purpose can be threshold
   development while the target explicitly says 5K estimate or manual threshold.
   **Accept targets and start** sends the exact review hash plus selected source.
   Cancelling never starts. Editing removes the preview and requires reconfirmation.
5. With missing/stale/withdrawn 5K there is no fabricated pace or silent start. An
   explicitly authored RPE alternative can be selected and reviewed; no fallback is
   invented from prose, recovery RPE or a default. Unsupported manual source/category
   or malformed targets refuse admission.
6. Follow unchanged authored warm-up, repeated work/recovery and cooldown in the
   existing timed runner. Only marked work steps resolve; labels/durations/order
   remain exact. Target guidance identifies its source, separate from manual actuals.

The software-only fixture is 300s warm-up + 3×(120s work/60s recovery) + 300s cooldown,
1140s total, with explicit fixture-only RPE 7 alternative. It is **not** an approved
Hybrid 10K workout. Private v1/v2 copies exist only inside disposable local proof.

## Canonical execution, ownership and freeze

Existing private v1/v2 publication → normal M1.2 acquisition/materialisation/schedule
→ Programme Athlete prepared occurrence → existing start store, with exact selected
review → same original canonical fixed start transaction → existing immutable
per-occurrence target snapshot → existing authored timed adapter/controller/runner
→ existing draft, completion, correction and History paths.

One narrow new owner-input table (`athlete_running_quality_inputs`) retains current
confirmed 5K/manual values and revision/withdrawal. It is not another benchmark
platform or B2 completed-test evidence. The existing historically named
`programme_occurrence_zone2_targets` table also freezes quality packets; no second
freeze/result schema or execution runtime is created. Existing input/admission
metadata codecs, result guards and canonical starts are reused.

- Authenticated owner-only reads and expected-owner RPC writes; no direct client
  table writes, helper EXECUTE or service fallback. Shared actor/occurrence locks
  prevent input/start races. Generic non-occurrence start cannot bypass admission.
- Exact owner, occurrence, assignment/version/package hash, protocol/body/block/step,
  input revision/provenance, selected source, rule/parameters/rounding, resolved
  targets, review/acceptance and session identity freeze atomically at first start.
  A failed snapshot write rolls back canonical creation. Concurrent accepted starts
  return one session/freeze; stale review/source/input cannot be substituted.
- Later confirmed input updates or withdrawal require review for future starts;
  resume/completion keeps the original snapshot even when the evidence is now stale.
  No targets, actuals, loads, later sessions or programme prescriptions are rewritten.
- Correct source-scoped targets appear on the exact marked step. Original bodies
  remain immutable. Prescribed input/target metadata survives draft and result JSON
  round-trip; actual correction cannot replace it. Decimal intermediates are strings
  to preserve exact immutable packet equality through Dart serialization.
- Interruption/restart reuses M1.3/full-body state: exact phase/repeat/remaining time
  returns **paused**, with no closed-time catch-up or automatic step advancement.
  Completed clocks remain finished until explicit athlete actions; no timer result,
  distance, actual pace or workout completion is fabricated. Timer identity includes
  the admission digest. Last successful local write remains the durability bound.
- Existing unmarked v1/v2/Zone 2/B2 starts remain compatible. Old fixed/generic start
  function OIDs/ACLs are preserved; the new source-selecting overload delegates the
  same canonical start. V3, accepted-adapted/nonfixed target adoption and automatic
  benchmark ingestion remain unsupported; no deferred HYROX prerequisite is added.

## Verification and limitations

- **24 new unit/widget tests**, **103 final focused tests**, **650 affected tests**
  pass (three opt-in authenticated tests skipped in the broad ordinary command).
  They cover approved calculations/all categories/rounding, malformed inputs and
  civil-date boundaries, exact source/owner/occurrence/step scope, acceptance/source
  choice, RPE refusal, immutable round-trip, paused restart and target/actual separation.
- **Fresh and repeated disposable SQL replay plus real GoTrue/PostgREST proof pass.**
  Four synthetic quality athletes acquire private v1/v2 via normal M1.2 stores;
  confirmation/review/acceptance, exact 56/57-day cutoff, future/stale/withdrawn/missing
  input, opposite date zones at fixed UTC, SQL/Dart bounds, manual/RPE selection,
  stale-review/source, concurrent starts, RLS/write/owner guards, frozen resume,
  canonical completion, snapshot tamper rejection and actual correction/History
  readback pass. The separate unchanged Zone 2 authenticated gate also passes in
  each fresh/repeat run, retaining legacy v1/B2-v2 start/resume compatibility.
- **All six consolidation safety groups pass.** Analysis: **362 identical inherited
  findings**, zero errors or new/changed-file diagnostics; exit 1 remains non-green.
  No diagnostic suppression, dependency or analysis configuration changes.
- Retained preservation inventory is byte-identical: 23 existing checkouts, 28 absent
  registered worktrees, raw indices, tracked/untracked contents and `.temp` untouched.
  Local diff checks pass. No browser/desktop/alternative UI or alternate network route.

**Known existing limit:** terminal one-session completion retry returns
`validation_failure` / `fixed_assignment_ineligible`, with one unchanged result and
snapshot. This is not successful completion idempotence; no completion protocol was
changed here. Retain for M2.4 rather than masking the refusal or duplicating work.

Local port/widget/SQL proof is not installed-device acceptance, OS lifecycle/storage
proof, hosted readiness or distribution. No full aggregate DB/default Flutter suite,
real programme/tester, sensor or Garmin test was performed. The deferred producer is
omitted only from the disposable replay copy; its repository file remains unchanged.

## Deployment and next single milestone

New migration `20261027130000_alpha_quality_running_targets.sql` is **LOCAL ONLY /
UNDEPLOYED**. It requires the retained confirmed-Zone-2 migration and confirmed
training-setup dependency; M1.2 and Zone 2 remain unapplied under this task.
The [exact proposal](DEPLOYMENT.md) separates scoped schema approval from compatible
client distribution, real content approval/publication, eligibility and athlete tests.
No hosted contact or hosted data/account/programme/assignment changes occurred.

Ordinary GitHub lookup fails DNS; remote main freshness remains unverified. All prior
commits remain ancestors. A normal main-only push is authorised and will be attempted;
no force push, alternate route or network permission bypass is authorised.

**Next single build point: M2.4 terminal completion retry/idempotence**, preserving
one canonical result and truthful feedback after interruption. No next build starts
in this task. Genuine Hybrid 10K/father sources/entry/progression, Lee's separate
adjustment, real programme admission, Garmin workout delivery **and activity return**,
accepted adaptation, distribution and authenticated real-device acceptance remain
Gate A requirements. Target-rule decisions for this representative slice are approved;
the fixture does not complete or approve any genuine programme.
