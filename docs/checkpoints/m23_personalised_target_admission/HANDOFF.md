# M2.3 — confirmed Zone 2 target admission

2026-10-27 (Asia/Makassar). **ZONE2_ADMISSION_IMPLEMENTED_LOCAL_VERIFIED**.
Overall **M2.3 PARTIAL**: Hybrid 10K quality pace rules and full-body quality target
admission remain open. Gate A, hosted enablement and device acceptance remain open.

Base `1963338cff87fc6165c2f9fb754afe153547f279`; implementation `eb8fe4e`.
All eight earlier commits after the founder-reported published `1cca598` are
preserved unchanged. Reused clean local main in `/private/tmp/cohort_m11_sources`.
No new worktree/clone, original-checkout edit, index restoration or cleanup.

Binding: [M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M1.1 assessment](../m11_hybrid10k_assessment/HANDOFF.md),
[complete timed running](../m23_structured_timed_running/HANDOFF.md),
[M1.3 restart](../m13_steady_state_restart/HANDOFF.md).
[Verification](VERIFICATION.json), [scoped deployment proposal](DEPLOYMENT.md).

## What the athlete can do

For an original fixed-schedule v1/v2 run explicitly authored with the neutral
`heart_rate_zone_ref` **`athlete_confirmed_zone_2`**:

1. Open through normal Programme Athlete. A new start without accepted current
   targets is refused before creating a session. The existing launcher opens a
   review screen, with no default heart-rate values.
2. Enter lower/upper whole-number **bpm**, or confirm the last saved range.
   Both must be present, 1–250 and strictly ordered. This is an input/representation
   guard consistent with the existing numeric HR model, not a medical suitability
   finding or a universal Zone 2 calculation. No age/max-HR formula is used.
3. Explicitly confirm the limits. That action saves this athlete's current Zone 2
   input with a new server-issued revision and confirmation timestamp. It does not
   start training. Cancel after confirming retains the explicitly saved input.
4. Review the exact workout/step labels and resolved range. Editing a field removes
   the old preview. **Accept targets and start** supplies the exact server review
   hash; confirmation alone, cancellation and withdrawal never start a workout.
5. Follow the existing ordered timed runner. Only steps carrying that explicit
   reference resolve to the accepted BPM range. Warm-up/cooldown and other authored
   targets remain unchanged. Display is prescribed guidance, not live HR capture.

The new input remains confirmed until explicitly replaced or withdrawn. No
unapproved age-based or elapsed-time expiry rule is invented. Here **stale** means
an input revision or exact source changed between review and start. The old hash
then refuses a new start and the athlete must review again. Missing, withdrawn or
invalid inputs cannot silently fall back to a guessed range or fixed easy pace.
Other opaque HR-zone references are not reinterpreted by name/prose matching.

## Existing authority path, freeze and persistence

Private v1/v2 session reference → reviewed block-native `running_workout` body
→ exact prepared Programme Athlete occurrence → existing start store/RPC
→ new confirmed-input review gate around the **same canonical start transaction**
→ immutable per-occurrence target snapshot → existing `SessionExecutionLauncher`
→ existing authored timed adapter/controller/screen → local cursor + actuals.

The source review covers all structured bodies, physical block/step identities,
athlete, assignment, version/package hash, protocol/occurrence and input revision.
At accepted first start the server freezes these plus the range, confirmation,
review hash, acceptance time and canonical training-session link. Any snapshot
write failure rolls back the delegated session/outcome creation. Concurrent starts
produce one session/snapshot; confirmation/start races cannot combine revisions.

- Reopen/resume returns the original server snapshot, even after zone changes or
  withdrawal. A later input is for future starts only. There is no rewrite of a
  started/completed prescription, source programme, authored duration or load.
- The authored body stays unchanged. Only the runtime projection resolves marked
  steps to the frozen `heart_rate_range`. Source and accepted inputs are retained
  separately from athlete-entered actuals in `runningTargetAdmissionV1` metadata.
- Snapshot metadata round-trips through existing plan/draft codecs, results and
  corrections. Server record guards require the exact frozen snapshot and source;
  direct authenticated attempts to change it are rejected. No new actual-result
  type or measured HR/pace values are manufactured.
- The timer identity includes a canonical, object-order-independent admission
  digest. Interruption/restart preserves exact step/repeat/remaining time **paused**,
  without closed-time catch-up. Finish remains a clock state, never actuals or
  automatic completion. Existing M1.3 write/exit/account/recovery guards remain.
- Owner input writes require both authenticated athlete identity and the expected
  owner ID. New tables have owner-only SELECT/RLS and no client writes; helper
  EXECUTE is closed. Public input/review/start APIs are authenticated-only. A
  generic non-occurrence start cannot bypass the opted-in fixed-start gate.
- Unrelated starts keep the existing function OIDs, delegation, status vocabulary,
  v1/v2 package bytes/hashes and B2 snapshots. Explicit old v1 and B2/v2 start/resume
  proof passes. No new v3 source/producer/authentication prerequisite is introduced.
- Accepted-adapted/nonfixed/v3 uses of this new marker are unsupported and fail
  closed; adaptation requires its separate governed Gate A proof.

There are two narrow new tables: one current owner-confirmed input and one
immutable occurrence snapshot. Existing B2 advisory snapshot constraints/policies
cannot honestly carry an HR-zone confirmation for a full phased body; they remain
unchanged. No generic benchmark platform or second execution runtime is added.

## Verification and exact limits

- **14 new unit/widget checks** cover explicit input validation, wrong owner and
  occurrence/version/source scope, withdrawal/malformed input, pace-window unit and
  ordering rejection, immutable serialization, JSON-key-order stability, explicit
  confirmation/acceptance, correct main-step display and canonical local restart.
- **79 final focused checks pass**, including those 14 plus existing full timed-run,
  steady countdown and Programme Athlete launch cases.
- **626 affected tests pass**, two ordinary opt-in local-auth tests skipped in that
  command. Execution, performance/completion/correction/History, persistence,
  endurance, running domain, private programmes, acquisition and auth are covered.
- **All six mandatory safety groups pass.** Full analysis before/after has **362
  identical inherited findings**, zero errors/new/changed-file diagnostics; exit 1
  remains non-green. No suppression, dependency or analysis configuration change.
- **Fresh and repeated disposable SQL replay + real GoTrue/PostgREST proof pass.**
  Two synthetic athletes acquire private v1/v2 fixtures through the normal stores;
  actual confirmation/review/start, input races, concurrent starts, stale/withdrawn
  rejection, owner/RLS/API ACLs, injected freeze failure rollback, server resume,
  canonical completion, snapshot tamper rejection and actual correction/readback
  are tested. Separate existing v1 and B2/v2 fixtures prove legacy start/resume.
  The deferred producer migration is omitted only from the disposable copy, unchanged
  in the repository. No real programme/tester or hosted write is involved.
- Retained inventory is byte-identical: 23 existing checkouts, 28 absent registered
  worktrees, raw indices, tracked/untracked paths and `.temp`. Diff checks pass.

**Observed existing completion limit:** after a one-session programme completes,
retrying its canonical completion returns `validation_failure` /
`fixed_assignment_ineligible`. The original completed record/target remains and no
second record is created. This is not idempotent-success proof. No completion
protocol was changed to hide/fix it; retain it for M2.4 reliability acceptance.

Local HTTP/SQL/port/widget proof is not installed-device, browser, lifecycle/OS
storage durability, device acceptance or current hosted readiness. No full aggregate
DB gate, sensor test, commercial content approval or distribution was performed.

## Migration, remaining decision and next point

One new migration is required for hosted use:
`20261027120000_confirmed_running_zone_targets.sql` — **LOCAL ONLY / UNDEPLOYED**.
The [deployment proposal](DEPLOYMENT.md) pins its hash, prerequisites, scope and
postchecks. M1.2's earlier migration remains separately held. Do not apply a broad
pending batch or the deferred producer. No hosted schema/account/programme/
assignment/eligibility/athlete changes are authorised by this handoff.

New source use needs an accepted compatible client and exact source/content review;
older clients fail closed at the new review gate. No genuine Hybrid 10K/father
programme has been published or approved by these fixtures.

**Precise 5K decision still needed:** approve a versioned qualifying representative
5K protocol/result and evidence provenance/eligibility/freshness/withdrawal rules;
then approve the exact calculation, quality pace windows, rounding and missing/
stale/unsupported-input behaviour for one exact authored quality workout. No draft
formula, universal percentage band or conversion from an arbitrary activity is
admitted. Existing B2 machinery is retained; its scalar mapping is not asserted to
be full-body quality admission. Benchmark-entry/ingestion and distance/lap execution
remain open as previously recorded.

**Next single milestone point: M2.3 quality-run target policy approval/admission**
for one exact representative workout, once those founder decisions exist. Genuine
programme sources/entry/progression, Lee's separate adjustment, Garmin delivery
**and activity return**, accepted adaptation and M4 distribution/authenticated device
acceptance remain Gate A requirements. No next implementation starts automatically.
