# Prescription comparison — continuation

2026-10-20. Fetched/published base `cfd9bae736e2eb0a537410328006d4920b4e7548`;
scope `091e8375385daf74ca8dc091c65a1f605d1a3217`; implementation
`0f23abc54321ae38687ab16826ef812defb46565`. The evidence commit containing this continuation is the intended
normal main-only publication tip; final remote postflight is reported with that SHA.
Latest founder authority permits implementation, review, commits and normal publication
on local technical gates without another allocation/visual-approval pause.

[Scope](SCOPE.md) · [Verification](VERIFICATION.json) · [Preservation](PRESERVATION.json).
Earlier [source-intake handoff](../programme_studio_canonical_intake/HANDOFF.md) and
[control-revocation incident](../programme_studio_canonical_intake/INCIDENT.md) remain binding.

## Delivered

Use this version… now compares the exact currently selected prescription with the
proposed saved version before consent. It names Week / Day / Workout and both
session lineages/versions, then shows before/after changes to exercise additions,
removals and order, sets/exact reps, unspecified/bodyweight/kg/RPE loads, rest, tempo
and cues. Session/block titles and notes, exercise display labels and estimated
session duration are reported separately as metadata. No prescription or metadata
change and metadata-only change have explicit summaries. Omitted values remain
Unspecified; literal authored text is quoted. No volume, intensity equivalence,
performance comparability, coaching advice or suggested progression is computed.

Exercises pair only by the established canonical exercise identity and exact retained
exercise-version binding; identical titles do not match identities. Matching never
uses revision-local link IDs or row positions. Existing exact-source compiler receipts,
source guard, typed strength prescriptions and StrengthPrescriptionFormatter are reused.
Comments, YAML layout, equivalent supported exact-rep encoding and RPE aliases do not
become prescription changes. Wrapper/source-byte changes are not executable session
prescription changes. Full existing prescriptions and technical source details remain
optional expansions, with exact protocol/lineage/revision, digest, exercise bindings
and occurrence key available under Advanced source identities.

Only the confirmed occurrence selects the version. The confirmation lists other
occurrences sharing the old selection that will keep it; all other selections also
stay unchanged. Saving still does not select. Adding a private version to programme
availability remains part of the existing synchronous atomic selection commit.
Preparation and cancellation do not change availability or selections.

Both current and proposed source receipts are exactly recompiled before comparison.
The immutable comparison, current source, target coordinates and proposed selection
share the existing workspace-generation/editor/catalogue/owner freshness guards.
Edits, moves, replacement/reset, other-owner work, newer preparation and disposal
invalidate stale consent. Stale comparison content disappears and confirmation
disables; commit checks freshness again after notification, before either mutation.
Missing/unsupported/unverifiable comparison refuses with an unavailable explanation
and no selection/catalogue mutation. Existing locked-reference refusals remain intact.

No workspace format, canonical source TAR/index, read-only review transport, shared
compiler/schema/hash/resolver, identity semantics, dependencies, published content,
fixtures/goldens or SQL changed. The fixed synthetic profile, two lineages and one
straight-sets strength block with one/two distinct exercises remain the accepted bound.

## Review and verification

Technical self-review covered all five changed/new Dart files: identity matching and
field coverage; source/ownership checks; comparison preparation and notification races;
optional details and stale UI; cancellation and atomic commit; editable workspace and
both export products. Confirmed presentation defects were fixed before final gates:
stale content is removed immediately and explicit text cannot look like an omitted
value. No unresolved confirmed defect remains. No independent-agent/founder visual
acceptance is claimed.

- **412 Studio tests pass**, including **42 new cases** (35 semantic/controller,
  seven widget). Coverage includes all twelve load-mode transitions, actual values,
  formatting equivalence, titles/notes, no-change, identical exercise/session titles,
  reorder/add/remove, exact later-week selection, reverse comparison after editable
  reopening, canonical re-intake/read-only export, cancellation/failure and stale races
  during preparation, notification and confirmation. Narrow 390px / 2x text is covered.
- **Six mandatory safety groups pass**; final terminal Studio web build passes.
- **Zero diagnostics across all five changed/new Dart files**. Full analysis remains
  **NON-GREEN: 367 identical inherited identities** (110 warnings, 257 info, zero errors),
  no additions/removals, no suppression/configuration edits. Fresh setup required
  initialising unchanged nested package caches before measuring the baseline.
- Accepted **41 canonical-package tests are reused, not rerun** after exact raw-log
  hash, package-tree and relevant compiler/mapper/projector/transport/formatter-byte
  equality checks against `4d78d4681a1f8a64771f7fbf05f5597cfe77b3cc`.
- Full repository default suite and DB replay were not run for this bounded UI/controller
  extension. No SQL/schema/hosted or athlete-runtime change.

No apps/browser/debugger/AppleScript/substitute control or web search was used.
The web build and widget tests **do not establish native browser verification**.
Prior incomplete browser checks (later-week/all-eight final inspection and final native
canonical/read-only export/reopen) and all four record-dependent phone checks remain
pending. There is no new phone build/install/distribution or founder acceptance claim.

## Preservation and publication

All **13 older existing checkout inventories match exactly**: HEADs/branches/indices,
Git pointers, tracked/nonignored/outstanding bytes and present/absent .temp state.
Original dirty main stays `a331f52967e1887c4435cccc8f1ecfa192028cd6` with **95 outstanding
paths**. Four already-prunable registrations are retained. Ignored build caches are
excluded. Raw inventories/logs are in `/private/tmp/cohort-studio-comparison`; durable
hashes and per-checkout summaries are in PRESERVATION and VERIFICATION.

**2,712 present protected baseline blobs** match exactly, and nine already-absent .temp
paths retain their Git identities. The only edited existing paths are two reviewed
composition code files and the current checkpoint notice; comparison/tests/evidence
are additions. All other baseline compiler/schema/hash, source artifacts, goldens, SQL
and accepted evidence bytes are protected unchanged. Publication uses only this new
isolated clean worktree, a linear range and normal `HEAD:refs/heads/main`, no force,
feature-branch or tag push, after fresh exact remote-base verification. Original main
and older checkout branches are never fast-forwarded or staged.

## Binding continuation

[Studio section 4](../../architecture/Programme_Studio_v1.md) calls for prescription-aware
version comparison; that requirement is now technically delivered for the accepted
bounded strength authoring/occurrence-selection surface. Sections 3/5 still require
canonical sources and broader source-authoring coverage. This is not completion of
broader Stage 2 or Sprint C.

The next supported requirement is **complete approved-source prescription coverage and
review**, before first-library publication: identify which distinct prescriptions in an
actually approved source can be faithfully authored/rendered, and retain explicit gaps
where the present straight-sets representation cannot do so. This follows Studio's
complete-prescription requirement, [product plan section 4](../../planning/Athlete_Product_Completion_Plan_v1.md)
and [launch quality gate section 10](../../architecture/Launch_Programme_Library_v1.md).
Actual canonical exercise identities, complete authored progression/substitutions/
assessments/policies, editorial/founder acceptance and production-path/device evidence
remain separate requirements. Do not invent content or expand representations merely
to claim closure. Stage 3 remains the separately scoped trusted command-line
compile/import/approval/publication path under the [delivery roadmap](../../planning/Delivery_Roadmap_v1.md).

No hosted operation, real content publication/assignment, athlete mutation, migration,
payment, numeric derivation, progression or locked-contract editing is authorised by
this checkpoint.
