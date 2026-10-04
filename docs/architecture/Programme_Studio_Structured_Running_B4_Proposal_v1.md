# Programme Studio structured running B4 proposal

**Status:** `PROPOSED_FOR_FOUNDER_REVIEW`

**Recorded:** 2026-10-04

**Verified base:** `d1585aff2ae6ef4bfcd066927782ce349d8a6924`

**Scope:** inspection and documentation only; B4 implementation is not
authorised.

## 1. Decision summary

The smallest safe B4 slice is a **derived, read-only structured-running review
projection inside Programme Studio**. It should join a valid canonical Plan
Package v2 slot to a separately hash-pinned and validated protocol graph, then
reuse the B1 workout projection and B2 policy calculation primitives to show
what was authored and whether the current B3 runner can execute it.

Studio must not become a prescription, publication, benchmark, occurrence, or
snapshot authority. It must never repair a binding, infer a step from a title
or position, choose a pace policy, persist a hypothetical calculation, or
create an occurrence-frozen target. Invalid or incomplete joins remain visible
and fail closed.

This proposal authorises no implementation, programme content, commercial pace
bands, metrics profile, hosted operation, assignment change, device build, or
Garmin work.

### Audit basis

The audit began after fetching `origin` with a clean worktree and confirming
`HEAD = origin/main = d1585aff2ae6ef4bfcd066927782ce349d8a6924`
(divergence `0/0`). It reviewed repository guidance, the live checkpoint, the
Athlete Product Completion Plan and Delivery Roadmap, Launch Programme Library
and Programme Studio architecture, Running Workout and Device Interop, the
Programme Studio Stage 1 handoff, and the B1, B2, B3 slice 1–3, and B3 device
validation handoffs. Source inspection was read-only; no hosted system was
contacted and no test/build command was run.

## 2. Audit findings

### 2.1 Authority that already exists

| Concern | Existing authority | B4 use |
|---|---|---|
| Programme schedule and running attachment | `PlanPackageManifest`, specifically `PlanPackageSessionSlot.authoredRunningV1` in `packages/cohort_plan_package/lib/src/plan_package_manifest.dart` | Read only after the canonical compiler succeeds. |
| Exact executable mapping | Ordered `step_ids`, exact `step_id` → canonical `session_block_id` bindings, and `execution_mapping_sha256` emitted by `PlanPackageCanonicaliser` (`packages/cohort_plan_package/lib/src/plan_package_canonicaliser.dart:147`) | Display and validate; never reconstruct from titles or list positions. |
| Policy identity and arithmetic inputs | Versioned advisory attachment and policy in Plan Package v2 | Display exactly. A preview may call the existing pure B2 calculator with explicitly hypothetical input. |
| Executable block | Hash-pinned reviewed protocol graph, exact protocol/revision scope, stable block identity, and timer configuration validated by `ReviewedProtocolGraphArtifact` (`lib/features/private_programme/reviewed_protocol_graph_artifact.dart:21`) | Consume a shared validated projection. Do not add a second graph parser with weaker checks. |
| Ordered workout steps | `RunningWorkoutProjector` and the B1 workout model | Render the canonical projected roles, duration, repeats, recovery, and guidance. |
| Athlete target | B2 occurrence snapshot frozen by the authenticated B3 launch path | Outside B4. Studio neither reads nor creates an athlete snapshot. |
| Athlete actuals and History | B3 completion and server-derived History authority | Outside B4. Studio is a programme review surface, not an athlete evidence viewer. |

The Plan Package validator already rejects unsupported package/schema versions,
invalid or duplicate step identities, incomplete or reordered bindings,
multi-block mappings, undeclared advisory step references, invalid policy
ranges, unsupported external evidence, and invalid rounding increments
(`packages/cohort_plan_package/lib/src/plan_package_validator.dart:25`). The
reviewed graph validator additionally pins the graph hash and checks exact
protocol/revision scope, stable block identity, timer projection, workout ID,
and step order. B4 must preserve both layers.

### 2.2 Current Studio gaps

1. `ProgrammeReviewSourceSpec` and `ProgrammeReviewSourceBundle` have no
   reviewed protocol-graph source or expected graph hash
   (`lib/features/programme_studio/projection/programme_review_source.dart:3`).
2. The Studio catalogue currently includes Apollo, Bali, and Spartan only;
   the controlled B3 validation package is not part of real inventory
   (`lib/features/programme_studio/projection/programme_review_catalog.dart:13`).
3. `ProgrammeReviewProjector._weeks` passes a slot to `_session`, but
   `_session` does not project `slot.authoredRunningV1`
   (`lib/features/programme_studio/projection/programme_review_projector.dart:413`).
4. `ProgrammeReviewSession` and `ProgrammeReviewBlock` have no typed structured
   running review data (`lib/features/programme_studio/domain/programme_review_models.dart:111`).
5. Coach Review renders only generic block/timer/movement information; it has
   no canonical step sequence, repeat structure, binding state, target scope,
   or policy (`lib/features/programme_studio/presentation/programme_studio_coach_review.dart:300`).
6. Studio readiness still says structured running and pace calculation are not
   implemented, including a stale B2 statement for Bali
   (`lib/features/programme_studio/projection/programme_review_projector.dart:650`).
7. Technical Integrity already provides the correct secondary surface for
   hashes, source paths, lineage, compiler stages, and findings. B4 should add
   running evidence there rather than expose technical IDs in the main coach
   review.

## 3. Proposed coach review surface

### 3.1 Primary session review

For a Plan Package v2 slot with `authored_running_v1`, show a **Structured
run** section below the session prescription. Its status must be one of:

- **Verified for current structured runner** — package, reviewed graph,
  executable block, workout, ordered steps, mapping hash, policy scope, units,
  and current B3 execution capability agree.
- **Authored, not attached to structured execution** — canonical workout and
  policy are present but no executable mapping exists. Show the authored
  structure without claiming it can launch in B3.
- **Invalid binding** — a binding, hash, identity, role, scope, or unit is
  missing or disagrees. Show the blocking finding; do not fall back to a
  guessed match.
- **Unsupported by current runner** — the authored shape is valid but requires
  a capability outside current B3, such as distance execution or manual laps.
  Do not describe it as launch-ready.

The primary sequence should use coach language and omit technical IDs:

```text
Repeat 3 times
  Work · 20 seconds
    [authored guidance]
    Advisory pace policy applies
  Recovery · 15 seconds
    [authored guidance]
Final recovery is included
```

Rows stay in canonical order. A one-level repeat is shown once as a repeat
group, not flattened into duplicated authored steps. Duration, role, work,
recovery, repeat count, and final recovery come from the B1 workout projection;
guidance remains authored prose. Studio must not add physiological labels.

### 3.2 Target scope and policy

Show an **Advisory pace policy** card only when an explicit advisory attachment
exists. It must state:

- the exact work steps in scope, described by their visible role/order;
- the authored minimum and maximum benchmark-speed percentages;
- eligible completed-test sources and freshness window;
- the authored display rounding increment and direction; and
- whether every scoped step is a work step supported by the current runner.

A numeric attachment to recovery, warm-up, cool-down, or another non-work step
is a blocking error. Overlapping numeric attachments for the same work step are
also a blocking error even though package-level validation does not currently
detect cross-attachment overlap. Missing mappings, duplicate bindings, invalid
units, workout/step/block mismatches, and a mapping-hash mismatch all fail
closed.

The card must say **Advisory**, not prescribed outcome, threshold, zone, race
pace, or any other physiological interpretation not present in the authored
package.

### 3.3 Hypothetical calculation

The secondary control is collapsed by default and labelled:

> **Hypothetical preview — not an athlete target**

It has no default benchmark. A coach may explicitly enter a hypothetical
completed 5 km time. Studio then calls the existing pure B2 calculation and
rounding code using only the already-authored policy, and presents:

> If an eligible 5 km result were **[entered time]**, this authored policy
> would display **[calculated range]**.

The control must also state:

> This preview is not saved and does not create or read an athlete occurrence
> snapshot. Athlete targets freeze only when the verified session launch
> succeeds.

The input and result are ephemeral view state: no source file, local draft,
database, analytics event, publication payload, or clipboard export is written
by B4. A real athlete benchmark must not pre-populate the field.

### 3.4 Intent-only and no-evidence behaviour

Alongside the policy, show the exact no-evidence outcome without estimating a
pace:

> **Pace target unavailable**
>
> If no eligible recent completed 5 km benchmark is available when the session
> starts, the athlete follows the authored guidance. Cohort does not estimate a
> pace.

This is a policy-behaviour preview, not evidence that a particular athlete will
be intent-only. Internal eligibility failure reasons may appear only in
Technical Integrity; the coach-facing outcome remains one message.

### 3.5 Secondary technical evidence

Behind **View technical evidence**, add:

- package schema, canonical package hash, source path, and compiler findings;
- publication artifact path and reviewed graph SHA-256;
- session, protocol, revision, slot, canonical block, workout, and step IDs;
- ordered step-to-block bindings and mapping SHA-256;
- attachment, policy, method, and version identities;
- exact policy basis points, evidence flags, freshness, units, and rounding;
- supported/unsupported execution capability; and
- stable validation codes for every fail-closed finding.

This evidence supports review and diagnosis. It must not offer repair, rebind,
publish, activate, or athlete-data actions.

## 4. Hard separation: preview versus frozen target

| Property | B4 hypothetical preview | B2/B3 occurrence snapshot |
|---|---|---|
| Purpose | Review policy arithmetic before content approval | Authoritative target used by one athlete occurrence |
| Benchmark | Explicitly typed hypothetical value | Selected eligible evidence at successful launch |
| Persistence | None | Hosted immutable snapshot |
| Athlete identity | None | Exact authenticated athlete and occurrence |
| Binding | Validated authored package/graph only | Exact version, slot, package hash, workout, steps, mapping, units |
| Resume | Not applicable | Must reuse the same frozen snapshot |
| Can establish History target | No | Yes, through server authority |

No Studio label may call a hypothetical result “frozen”, “assigned”, “actual”,
or “athlete target”.

## 5. Smallest implementation slice

1. Extract or expose a shared, pure validated result from
   `ReviewedProtocolGraphArtifact` containing the exact graph, mapped block,
   and B1 projected workout. Keep the existing publisher on this same validator
   so Studio cannot drift to weaker acceptance.
2. Extend the Studio source specification/workspace with an optional reviewed
   graph path and expected SHA-256 obtained from the canonical publication
   artifact. A missing or disagreeing source produces a finding, never a
   guessed graph.
3. Add immutable derived review types for structured workout groups/steps,
   mapping state, policy scope, hypothetical result, capability, and technical
   evidence. They are display projections, not new authoring DTOs.
4. In `ProgrammeReviewProjector`, join the compiled slot, session revision,
   validated graph, exact block, B1 workout, mapping hash, and advisory policy.
   Add the B4-only joint checks for attachment overlap and numeric target scope
   against B1 step roles.
5. Render the coach surface and technical-evidence disclosure. Keep the
   calculator empty by default, ephemeral, and explicitly hypothetical.
6. Register the existing B3 device-validation artifact only as a clearly
   labelled developer fixture behind `includeDeveloperFixtures`; do not add it
   to the real programme inventory and do not publish it.
7. Replace the stale running/pace readiness text with evidence-based states for
   each reviewed programme. Preserve Apollo, Bali, Spartan, Plan Package v1,
   and programmes without running attachments exactly.

This slice remains read-only. Studio Stage 2 authoring, policy selection,
metrics profiles, publication controls, and athlete data are separate work.

## 6. Acceptance checks

### Canonical and fail-closed

- A valid controlled v2 fixture deterministically shows one repeat group,
  ordered work/recovery steps, exact durations, repeat count, final recovery,
  guidance, target scope, policy, mapping status, and all secondary evidence.
- Repeated projection of identical bytes produces identical review JSON.
- Package v1 and slots without `authored_running_v1` produce byte-for-byte
  equivalent derived review JSON except for an intentional readiness-copy
  update.
- Package, graph, protocol, revision, block, workout, step order, binding,
  mapping hash, policy identity/version, role/scope, overlap, unit, and rounding
  disagreements each produce stable blocking findings and no “verified” state.
- Valid but unsupported distance, manual-lap, or deeper-repeat structures are
  labelled unsupported and never presented as executable.

### Coach presentation

- Primary review contains no UUIDs, hashes, raw basis points, or internal error
  codes; all remain available in the secondary evidence view.
- Numeric policy information appears only on explicitly scoped work steps.
  Recovery/open steps show guidance and duration but no numeric target.
- The hypothetical calculator starts blank, uses only authored policy, says it
  is not an athlete target, performs no persistence/network call, and agrees
  with existing B2 calculator vectors including rounding boundaries.
- No-evidence preview uses the wording in section 3.4 and invents no pace.
- Narrow layout, text scaling, keyboard input, and screen-reader semantics keep
  sequence, status, and warnings understandable.

### Compatibility and verification

- Focused canonical package, reviewed graph, Studio projection/controller/UI,
  B2 calculation, and golden tests pass.
- Apollo, Bali, Spartan, Plan Package v1, and fixture-isolation tests pass.
- Changed-file analysis has no diagnostics; `git diff --check` and the Phase 2
  safety gate pass. The full Flutter suite belongs to the final implementation
  gate, not this documentation-only proposal.
- Tests prove no database, hosted, publication, assignment, programme-source,
  or athlete-snapshot write path is reachable from B4.

## 7. Outstanding running gaps

### Required before HYROX authoring begins

1. **Founder acceptance and implementation of this B4 review slice.** Authors
   need to see the exact runnable structure, policy scope, and fail-closed
   state before approving prescriptions; generic block summaries are
   insufficient.
2. **Founder/head-coach approval of commercial pace policies.** The current
   device fixture uses explicit test-only values. They must never be reused as
   commercial HYROX bands. Policy IDs, methods, versions, eligibility,
   freshness, percentages, and rounding require deliberate approval.
3. **Metrics profile decision and approved implementation sequence.** The
   launch architecture places the programme metrics profile before content
   authoring. This audit does not implement or authorise it.
4. **Execution-shape decision for the first HYROX family.** Decide whether the
   initial prescription can be time-only with one-level repeats. If distance or
   manual-lap work is required, that B3 capability is a blocker; it must not be
   silently translated into time. The decision precedes prescription writing.
5. **Canonical graph/package workflow for launch content.** Authors need one
   supported path that creates immutable protocol revisions first, then exact
   v2 package mappings and hashes. Copying IDs by hand or binding by title is
   not acceptable.

### Required before launch, but not before bounded authoring

1. **Real launch-programme adoption and representative device validation.** The
   private TEST ONLY fixture proves infrastructure, not a commercial programme
   or its coaching prescription.
2. **All execution capabilities used by approved content.** Distance,
   manual-lap, or other unsupported shapes become launch blockers if approved
   content contains them. Otherwise they remain explicitly excluded from the
   first launch contract.
3. **Evidence-source readiness matching each policy.** Cohort-test ingestion is
   currently blocked. A policy that marks Cohort completed tests eligible
   cannot launch until that ingestion path is trustworthy; a separately
   approved manual-only policy does not make Cohort ingestion complete.
4. **Correction evidence.** Actual correction preserves targets in automated
   coverage, but a genuine changed correction and audit-row creation was not
   completed in the device walkthrough. Validate it before launch if athlete
   correction is in the launch surface.
5. **End-to-end launch gate.** Approved content, immutable publication,
   activation/default or private assignment behaviour, target freeze/resume,
   skip/partial completion, final recovery, History, recovery/rollback, and a
   complete representative programme journey require explicit evidence.

### Safely deferred from the first time-only launch contract

- Garmin and other device export/import, FIT generation, provider readiness,
  and device-specific audio/haptics. Structurally exportable is not device
  ready.
- Running target overrides, automatic adaptation, and future-session rewrites.
  They are separate authorities and are not needed to preserve authored policy.
- External benchmark import and inferred activity promotion. Current authority
  intentionally accepts only eligible completed tests.
- Nested repeats, multi-block step mappings, GPS distance auto-advance,
  manual-lap execution, and additional target units **only if** the approved
  first programme explicitly excludes them.
- Physiological labels, zones, and performance claims not present in approved
  programme policy. They are not required for faithful structure or advisory
  pace display.

Deferral is conditional on the launch contract staying within verified
time-based, one-level-repeat execution. Content approval cannot redefine an
unsupported feature as supported.

## 8. Founder review decisions

Founder review should decide only:

1. whether the primary/secondary information split is correct;
2. whether an explicitly entered, non-persisted hypothetical benchmark is
   acceptable in B4;
3. whether the four structured-running status labels are clear;
4. whether the first HYROX authoring contract is time-only or requires another
   B3 execution slice first; and
5. whether to authorise the seven-step implementation slice in section 5.

No percentage bands, metrics profile, programme prescription, publication, or
device integration is approved by accepting this proposal.
