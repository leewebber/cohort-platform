# Structured Running B3 device validation v1

**Recorded:** 2026-10-01  
**Status:** Local preparation only; hosted publication, assignment replacement,
and phone installation require separate founder approval.

## Purpose and boundary

This is the smallest end-to-end device-validation adoption of the integrated
B3 structured-running path. It is a private developer fixture, not commercial
programme content. Its `90–100%` speed policy is explicitly test-only and does
not approve a pace band for any launch programme.

The slice does not add distance execution, manual laps, device export, Garmin,
or new structured-runner behavior. It supplies the missing bounded paths for a
reviewed interval protocol graph and an authenticated declaration of a real,
completed 5 km test.

## Immutable fixture identity

- Lineage: `B3-DEVICE-VALIDATION-TEST-ONLY`
- Version: `b3d00000-0000-4000-8000-000000000001`
- Plan Package schema: v2
- Canonical package SHA-256:
  `fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a`
- Session lineage: `b3d00000-0000-4000-8000-000000000010`
- Protocol: `B3-DEV-RUN-VALIDATION-R1`
- Protocol graph SHA-256:
  `44e00cacd3e86d6c440279c58aca44f50d46d1af102020bdd6636310ca1f4a17`
- Executable block: `b1ea0297-6f2d-4b5b-8774-6421f01472a9`
- Workout: `rw1:p:5b3e7ec49df769e8`
- Execution mapping SHA-256:
  `91dac4d3717737d84ab31c805a9b69be3c28db68500cfbd368176e587af5a421`
- Timer: three repeats of 20 seconds work and 15 seconds recovery.
- Authorised activation: `2026-10-01`, `Asia/Makassar`.

The package contains one immutable programme version and four same-day slots.
Separate programme versions are unnecessary: target snapshots are occurrence
scoped and freeze independently on first launch. Four occurrences are required
because one occurrence cannot simultaneously prove calculated and intent-only
target states or multiple terminal repetition outcomes.

1. Calculated target, work and recovery restore, completion, History, and
   actual correction.
2. Completed work with pace unavailable.
3. Skipped work, producing partial completion.
4. No eligible benchmark, producing the athlete-facing pace-unavailable target
   state without inventing a pace.

Slots 1–3 accept only eligible manual completed-test evidence. Slot 4 accepts
only Cohort-completed-test evidence. Cohort ingestion remains blocked, so a
manual declaration is deliberately ineligible for slot 4.

## Authority paths

Publication compiles
[`../../tool/programmes/b3_device_validation_v1.plan-package.yaml`](../../tool/programmes/b3_device_validation_v1.plan-package.yaml)
with `PlanPackageCompiler`, verifies the reviewed graph byte hash and exact
projected workout/step/block mapping in
`ReviewedProtocolGraphArtifact.decode`, builds the canonical import payload,
then calls service-role RPC `publish_private_exact_programme_version_v2` from
`publish_private_exact_version.dart`. Title and position are never used as
running identities.

Activation remains an authenticated athlete product action. The private
programme card supplies the authorised date and timezone to
`AthletePrivateProgrammeActivationScreen._confirm`, which calls
`PrivateProgrammeEnrolmentSupabaseStore.enrol` and the
`enrol_athlete_in_private_programme_version` RPC with replacement explicitly
enabled. Replacement marks the prior assignment `reassigned`; it does not
delete that assignment, its occurrences, or its logged evidence.

The internal benchmark form calls authenticated RPC
`record_manual_completed_5k_benchmark`. It requires an exact 5,000 m completed
test declaration, local test date, surface, and elapsed time including pauses.
It is compiled only when `ENABLE_INTERNAL_TOOLS=true`; it does not convert an
ordinary activity into benchmark evidence.

The existing B2 occurrence start freezes eligibility, policy, benchmark, and
target. Slice 1 launch validation and slice 2 cursor restore then pin that same
snapshot. Slice 3 keeps target and actual separate through repetition review,
completion, History, and actual-only correction.

## Fail-closed rules

- Reviewed graph bytes, protocols, revisions, stable block IDs, timers,
  projected workout, authored steps, and executable bindings must all match.
- The canonical package hash and exact publication UUID must match the reviewed
  artifact.
- A missing, stale, or ineligible benchmark produces intent-only state; it does
  not produce an estimated pace.
- Pending work prevents completion. Skipped work makes the session partially
  completed. Timer expiry completes neither a block nor a session.
- Actual correction cannot change target, benchmark, policy, workout, package,
  step, repeat, or block identity.
- Production builds cannot enable the internal benchmark tool.
- v1, Bali, Apollo, unattached v2, and non-running execution remain on their
  existing paths.

## Approval boundary

No hosted programme, athlete assignment, benchmark, build, or phone is changed
by this local slice. Founder approval must name the exact programme version and
package/graph hashes, approve publication to Cohort Field Manual, approve Lee's
replacement activation, and approve an internal-tools development phone build.
The athlete must enter only real benchmark evidence.

