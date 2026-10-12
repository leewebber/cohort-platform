# D2 implementation handoff — proposed, not authorised

Prepared 2026-10-12. This packet is allocation work only. The instructions below become operative only when the founder explicitly approves implementation of the accompanying [ALLOCATION.md](./ALLOCATION.md). No current implementation/commit/integration/publication authority is implied.

## Ready-to-run founder prompt

> Implement Sprint D2 exactly within the prepared allocation. Accept the same bounded C prescription/tracking separation for this profile-free editor as the D1 prerequisite, without accepting broader Sprint C or closing the four pending phone checks. Approve the explicitly narrower D2 rules: one strength session, one straight-sets block, one or two distinct fixture exercises, exact positive reps/sets, optional positive rest seconds, opaque tempo/cue, and no-load/bodyweight/positive finite kg/integer RPE 1..10. Use the existing Founder grammar and canonical models. No invented prescription or alternate schema.
>
> Create an isolated managed worktree from exact `6318f319db15ff7a42283c7719dc22a6dc28daa5`, on `codex/programme-studio-d2`. Retain the clean accepted D1 worktree. Preserve the original dirty main checkout, its 95 files/index and `.temp` byte-identically; do not switch, reset, stash, clean, advance or stage it. No fetch is authorised. Read repository instructions/checkpoint and this allocation. Preserve a durable approved copy and authority record under `docs/checkpoints/programme_studio_d2/` in the implementation worktree.
>
> Implement the dedicated transient synthetic controller/screen, strict intake and complete deterministic Founder YAML writer, pure existing-component session compiler adapter, exact local source-to-Studio bridge, immutable revision catalogue and explicit programme revision selection. Add only the identified existing Studio typed-load/tempo presentation support. Do not loosen D1's source acceptance or change its writer/controller/fixtures. No shared compiler/schema/hash/model, dependency, migration, golden, published-artifact, production or release changes.
>
> Every edit/reopen/reset/identity/reference change and failed validation must invalidate previous current validation, review, hashes and export synchronously; discard outdated asynchronous results. Compile exact writer bytes; preserve original imported bytes for textual diff and normalized typed meaning for semantic comparison. Separate source-byte digest from existing package hash. Freeze never selects or overwrites another immutable revision; selection must be explicit and confirmed. Show actionable located errors and retain rejected source for correction.
>
> Run focused tests, fresh before/after analysis, protected-file verification, the unchanged six-group safety gate and diff/link checks. Investigate any difference from the D1 inherited 367 diagnostic baseline; require zero new/changed-file diagnostics and zero errors, without claiming full analysis green. Fix confirmed defects within scope. Focused local implementation/evidence commits are authorised; leave the implementation checkout clean.
>
> Start an isolated local Chrome preview using the established repository procedure, inspect the rendered workflow and exercise validation, editing/error invalidation, source diff/export/reopen, candidate revision freeze and explicit package selection before presenting it. Return exact branch/commits/worktree, evidence, protected-artifact/preservation proof, preview address and founder walkthrough. Stop for founder visual review. No integration/push, hosted contact/import/publication, device build/install, real content or athlete writes. Do not begin another slice or declare broader Stage 2/C complete.

## Implementation sequence and proof requirements

1. **Establish boundaries:** read root/subtree instructions, CURRENT_CHECKPOINT, Studio/launch-library contracts, D1 final acceptance, canonical architecture freeze and identity-consumer contract. Verify the exact base and clean managed checkout. Inventory all original 95 paths/status/hashes, index bytes, HEAD/main and `.temp` without optional Git index refresh; compare with the allocation receipts. Inventory all base tracked files in the implementation checkout. Identify production/preview entries and cached dependencies without secrets or hosted calls.
2. **Preserve approved scope:** copy only this reviewed allocation/handoff into the new checkpoint after authority, plus the founder approval text and current preserved state. Do not copy dirty deployment/device/security evidence, historical catalogue export or `.temp`.
3. **Strict source guard and writer first:** support exactly the documented wrapper/fields; reject all unknown/lossy keys, conflicting aliases, incorrect types, duplicate mapping keys and unsupported source constructs before permissive parsing. Strings, ordering, units, optional absence and numeric normalization have explicit rules. Canonical YAML uses stable field order, safely quoted strings, UTF-8/LF/final newline. Test byte-idempotence and normalized semantic meaning including Unicode, multiline text and accepted exact-rep/RPE aliases.
4. **Pure compiler and identity composition:** use unchanged Founder parser/validator/resolver/mapper; immutable fixture definitions and in-memory bridge; a read-only ProgrammeVersionStore whose writes throw. Build existing typed models with deterministic local IDs; follow the private import builder's supported mapping without invoking apply/import or introducing alternate prescription semantics. Check block validation, legacy projection and execution projection. Verify every supported field through importer/application typed conversion. No dosage defaults for a newly added row.
5. **Catalogue and review bridge:** use the existing protocol/lineage/revision tuple and deterministic number helper only (do not invoke clone/persistence methods that allocate time-based IDs). Distinguish retained read-only R1, reserved mutable candidate, frozen unpublished snapshot and explicitly selected package reference. Bind exact source bytes/digest, immutable exercise versions, typed body and tuple before generating in-memory reader text. Verify every reader row and then use the existing actual Studio projector/surface. Do not pass founderYaml to its title-based lookup. Reuse D1's pure complete package writer/compiler; keep D1's fixed-fixture controller unchanged. Candidate review uses a disposable proposed package; no implicit author-programme selection.
6. **Presentation and state:** render fixed kg/bodyweight/RPE plus tempo via the existing formatter, retaining raw data/fallback behavior. Make source diff and source-digest/package-hash distinction available. Protect sealed snapshots; new edits require a new reserved revision. Export/copy/freeze revalidate exact generation/bytes. Dynamic revision history is transient; no cross-browser-restart archive restore or publication-ready Founder identity claim.
7. **Validation and evidence:** run affected checks below, protect artifacts by hashes, compare full diagnostic identities and counts, prove deep immutable/reference/freshness behavior and production isolation. Never change a golden or shared contract to clear a failure. Capture commands/results in the checkpoint; raw generated logs/inventories may remain outside Git. Do not borrow historical D1 passes as current results.
8. **Local preview and stop:** verify actual rendered UI and errors, present founder walkthrough, record reviewed HEAD and stop preview after review. Preserve all qualifications. Integration/main publication require subsequent authority.

## Planned verification commands

These are future implementation commands, not commands run for this allocation. Use the implementation checkout, cached dependencies and the existing Flutter toolchain. Missing cached dependencies are a stop/report boundary; do not acquire a new dependency under this allocation.

Fresh full pre-edit and post-edit analysis (capture stdout/stderr externally, preserving exit status):

```bash
flutter --suppress-analytics analyze --no-pub
```

Do not infer a pass from exit 1. Compare errors/warnings/info and each diagnostic identity; D1's committed record is 0/110/257, total 367. Scope analysis to every changed/new Dart file after editing and require zero diagnostics.

Root affected regressions (the new D2 tests live under programme_studio):

```bash
flutter --suppress-analytics test --no-pub \
  test/programme_studio/ \
  test/founder_programme_import/ \
  test/authored_plan_package/ \
  test/architecture/founder_programme_identity_consumer_boundaries_test.dart \
  test/models/strength_exercise_prescription_test.dart \
  test/session_builder/session_block_validation_test.dart \
  test/session/session_execution_projection_test.dart \
  test/session_revision/session_revision_service_test.dart \
  test/domain/exercise_knowledge/founder_approved_identity_mappings_phase_3_1f_test.dart
```

From `packages/cohort_plan_package`, also run:

```bash
dart --suppress-analytics test
```

Run the existing mandatory safety entry point from repository root:

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

D1 established a Bash shell wrapper that delegates each `flutter test` to the actual tool with `--no-pub`, leaving the script unchanged. If needed, use that same cache-only procedure and record the precise wrapper/tool path and all six group outcomes. Do not edit the gate or skip a group. No database replay/DB gate is required by this purely in-memory slice.

Run `git diff --check`; verify all changed-document links and base-to-HEAD hashes of protected compiler/schema/hash, published inputs/artifacts and v1/v2 goldens. Compare the full base file inventory, allowing only approved D2 files, the two narrow Studio presentation changes/tests and intentional checkpoint pointer. Traverse nested package imports in isolation tests; an ignored importer-package edge would not prove no hosted/persistent reachability. Assert the read-only store receives zero writes and no entry initialises clients/auth/network.

## Future preview procedure and founder walkthrough

Use the isolated main entry and a free loopback port (4195 was the established D1 port; verify availability before choosing it):

```bash
flutter --suppress-analytics run -d chrome \
  --web-hostname 127.0.0.1 --web-port 4195 --no-pub \
  -t lib/main_programme_studio_protocol_authoring_preview.dart
```

No Supabase keys/hosted environment or athlete profile is needed. Do not start the production app. Inspect actual desktop rendering plus narrow/text-scaled layouts after widget coverage. Walk through:

1. R1 read-only review: exact fixture IDs, sets/reps, kg/bodyweight/RPE/rest/tempo/cue, source and reference evidence.
2. Create R2; add/remove/reorder/change exact exercise; make a valid edit and then an invalid one. Previous successful review/hash/export disappears immediately; errors identify the field.
3. Validate exact canonical bytes; inspect source diff and semantic proof; export/reopen is deterministic. Freeze R2 while the selected author programme remains R1.
4. Explicitly select R2 in the fixed synthetic programme; complete v1 package export/compile/Studio review uses that exact snapshot. Verify R1 and its source remain unchanged, same-title revisions stay distinct, cancelling selection/edit is harmless, and editing a frozen revision requires R3.

Record limitations honestly: only one straight-sets representation, fixture identities only, unpublished/transient catalogue, Founder export alone lacks the revision tuple, package hash excludes bodies, full analysis remains inherited/non-green, no hosted/device/content validation. Stop for founder visual review; no integration/publish or next task.
