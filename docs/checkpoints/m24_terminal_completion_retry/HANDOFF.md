# M2.4 — reliable terminal completion retry

Implementation `7cc471b71125cf516b17e8bda03256614b474bc3`.

2026-10-28 (Asia/Makassar). **Bounded retry fix implemented and locally verified**;
overall M2.4 and Gate A remain open for real-programme and authenticated installed
device acceptance. [Controlling M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md).
[Machine-readable evidence](VERIFICATION.json), [exact undeployed migration](DEPLOYMENT.md).

## Defect and reproduction

The actual prior checkpoint filename is
[docs/checkpoints/m23_quality_target_admission/HANDOFF.md](../m23_quality_target_admission/HANDOFF.md).
The fixed private completion body rejected a completed assignment before the
canonical logical/idempotency replay checks. Its delegated generic completion body
also required an active assignment first. A final-slot commit therefore succeeded
once but its exact retry returned `validation_failure / fixed_assignment_ineligible`.
The same assertion was reproduced before any implementation change using actual
local GoTrue/PostgREST and the original one-slot quality fixture. The recorded
pre-fix failure is `/private/tmp/cohort_m24_red.log`; it is expected red evidence,
not a passing check.

## Fix and athlete behaviour

Both existing guarded public programme-completion wrappers retain the exact
claims-derived ownership/link checks and their locks. They now resolve an already
terminal matching outcome before invoking their unchanged write bodies. Replay is
read-only: it returns `already_committed`, original record/session/outcome identities,
current authoritative record (including later corrections) and assignment, and the
terminal-programme flag. It never reopens an assignment or advances its cursor again.
New work still requires the original active-assignment admission. Paused/reassigned
assignments, missing/unavailable versions and cross-athlete/contradictory identities
remain denied. There is no service fallback or widened client table/helper access.

A prospective immutable server request digest binds payload/provenance alongside
the existing actuals fingerprint. Changed actuals fingerprints, terminal status,
notes or frozen snapshots conflict, including a copied fingerprint with changed
payload. A new transport key can recover the same logical result; reusing a key
belonging to another slot conflicts. Transport keys, occurrence routing and locally
recomputed session finish time/elapsed duration are excluded from the digest; the
exact occurrence/identity chain is validated separately. Manually entered block/set
actuals remain bound by their existing actuals fingerprint. Historical outcomes
retain their existing fingerprint contract; original payload digests are not
reconstructed or backfilled. Later corrections never replace the original receipt.

The client skips terminal draft rewrites and still obtains success from the
canonical RPC. Cursor movement alone no longer counts as evidence that this request
committed. Without acknowledgement, show pending/retry. A recovered success uses
the existing **SESSION COMPLETE / Session saved / saved to training history** flow;
subsequent History/Home refresh or local-envelope cleanup failure cannot change an
acknowledged commit into a failed save. Corrected server records take precedence
over stale local actuals. Durable restart uses the existing owner/session draft and
restore authority; no offline completion queue or new execution runtime is added.

## Verification

See VERIFICATION.json for final commands, counts, log hashes and scoped exceptions.
The local authenticated proof covers v1/v2 quality and Zone 2; genuine pre-commit
validation rejection; a forced failure after tentative terminal-record mutation
with unchanged record/outcome/assignment evidence; six competing same/logical
requests yielding one commit and five replay successes; deliberate loss of committed
responses; exact/new-key retry; changed fingerprint/status/note/snapshot conflicts;
foreign athlete and substituted record/session denial; paused/reassigned refusal;
completed assignment refusing new completion; JSON/fresh client/service restart;
one result/History identity; frozen target snapshots and correction/retry readback.
Read-only retries/conflicts compare assignment/outcome/record/occurrence/block row
digests, including timestamps. Authenticated test accounts exist only in disposable
loopback stacks, which are stopped by their gate cleanup.

Separate B3 compatibility proof omits every held alpha migration, checks mapping,
targets, partial/skipped actuals and corrections, then reapplies the new migration
with unchanged application evidence and completion/correction OIDs, owners, ACLs
and definitions. Private helper/client receipt-write denial is asserted. Existing
backfill/identity/correction code is unchanged; the full aggregate DB gate and full
default Flutter suite were not run.

The broader test attempt includes one inherited AuthGate bootstrap failure
(`athlete_runtime_capability_bootstrap_test.dart`, line 124, expected AthleteAppShell
absent). It reproduces on an archive of immutable base `a67e69c`, with package imports
resolved to that archive. It is isolated and reported, not fixed or suppressed by
this slice. Analysis remains non-green with the same 362 inherited diagnostics;
zero errors or new/changed-file findings. Local checks are not installed-device,
OS lifecycle/storage, real source adoption, hosted readiness or Garmin acceptance.

## Git, preservation and next point

Actual working main was clean `/private/tmp/cohort_m11_sources` at
`a67e69c1bbbb5edae4d3a802de9c5c910444841a`, including `ce9ec89` and all preceding
commits. All 13 commits after `1cca598` through that base remain exact ancestors;
there are zero merges in that range. The supplied Developer checkout remains its
older dirty `main` at `a331f52967e1887c4435cccc8f1ecfa192028cd6`; it was not switched,
reset, staged or cleaned. Retained checkout/file/index/.env/.temp preservation is
inventoried by hashes. No managed worktree lifecycle, browser/desktop control,
alternate network route, fetch or permission bypass occurred.

Normal GitHub lookup and main-only push failed DNS resolution. Cached origin/main
is `a331f52967e1887c4435cccc8f1ecfa192028cd6` in the working repository, not current
remote proof. Exact final local commits/push outcome are recorded with verification
and the final report; remote equality/publication is not claimed.

**M2.4 terminal-retry slice: locally verified, migration held.** Overall M2.4 still
requires real-programme installed-device save/resume/complete/correct/History
acceptance. Gate A also requires genuine Hybrid10K/father source/entry/progression
approval and admission (Lee's adjustment is separate), authorised hosted enablement
and ordinary tester setup/acquisition, actual personalisation adoption, Garmin
workout delivery **and activity return**, accepted adaptation, movement instructions,
feedback/distribution and blocking-security/execution acceptance.

**One next milestone point: M2.5 Garmin round-trip access/feasibility audit**, to
establish the real connection/delivery/activity-return boundary before implementation.
No next milestone or hosted/content/device action starts under this handoff.
