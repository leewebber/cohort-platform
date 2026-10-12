# Proposed composition slice — implementation handoff

**Not current implementation authority.** This ready-to-run prompt becomes an
implementation instruction only after explicit founder approval of ALLOCATION.md
and its local implementation/test/commit/preview authority. Neither a worktree nor
an implementation branch has been created by this allocation.

## Approval prompt for the next conversation

> Founder approval: implement the proposed bounded Programme Studio composition
> slice exactly as allocated. Read repository instructions and
> /private/tmp/cohort-studio-composition-allocation-2026-10-12/ALLOCATION.md,
> IMPLEMENTATION_HANDOFF.md and INSPECTION_AND_PRESERVATION.json. Read the current
> checkpoint, binding Studio/launch-library/frozen architecture contracts and D1/D2
> final acceptance. Create a new managed worktree from exact
> 6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6, on
> codex/programme-studio-composition. Preserve all three older checkouts, original
> 95 paths, indices, HEADs and .temp without switch/reset/stash/clean/advance or bulk
> copy. Preserve a durable approved allocation and authority in the new worktree's
> docs/checkpoints/programme_studio_composition/.
>
> Reuse D1 programme editing and D2 straight-sets authoring in one transient
> synthetic preview. Use the accepted one-week/two-day/one-required-slot D2 package
> seed with its nonempty locked contracts and exact R1. Add the narrow explicit
> D1 source-provider seam with legacy defaults unchanged; supply exact admitted
> source snapshots rather than loosening fixed fixture acceptance. Reuse existing
> writers, D2 exact compiler/identity bridge, immutable revision catalogue and actual
> Studio. Do not change shared compiler/schema/hash/models, published artifacts,
> v1/v2 goldens, dependencies, production entries, migrations or release guards.
>
> Keep freeze, catalogue admission and confirmed per-slot selection separate.
> Admission accepts only genuine frozen workspace D2 entries, verifies exact source/
> tuple/digest/meaning/exercise-version bindings and rejects collisions/unsupported
> constructs. It is append-only; exact repeat is idempotent. Retain unrelated draft
> edits and locked contracts; never update references implicitly or resolve by title.
> Frozen bytes never alias a working tree. An open session draft blocks combined
> export/review until freeze/cancel. Conservatively invalidate joint receipt on D2
> generation changes; programme edits, admission and selection invalidate the
> appropriate current receipts immediately. Failed/stale async results must not
> become current or partially mutate catalogue/reference state. Guard completion
> notifications and consumption, not merely the start of an await.
>
> Compile/review exact programme export bytes alongside every declared immutable
> Founder source. Reuse D2 readerText/verifyReaderText with the real projector;
> avoid its fixed package/first-slot project() assumptions and all Founder title
> fallback. Verify all programmed slots, full bodies and the ordered source-binding
> inventory. Keep programme package hash and source digests separate; do not invent
> a new production identity hash.
>
> Export one complete deterministic strict source transport envelope plus inspectable
> YAML lanes, containing all declared sources, explicit tuples/digests/bindings and
> fixed fixture profile fingerprint. Reject partial/bare-programme reopen, unknown
> or duplicate fields/entries, mismatch/unsupported data and tampered claims without
> partial replacement. Reopen the envelope into a separate read-only reconstructed
> review with fresh validation and deterministic re-export. It must not hydrate an
> editable D2 catalogue, restore reservation/history or overwrite live authoring.
> This is canonical-source transport, not a persisted Studio blob or hosted import.
>
> Add meaningful integration, deterministic round-trip, admission/conflict, same-title,
> source ownership, all-slot projector, controller completion/race, widget, isolation
> and D1/D2 compatibility regressions. Run fresh before/after full analysis and
> changed-file analysis: investigate differences from 367 inherited diagnostics
> (110 warnings,257 info,0 errors); require zero new/changed-file issues and zero
> errors without claiming full analysis green. Run existing affected regressions,
> canonical-package tests, six unchanged safety groups, protected base hash checks,
> diff/link checks and older-checkout preservation proof. Fix scoped confirmed defects.
>
> Local focused implementation/evidence commits are authorised; leave a clean
> implementation branch. Start only the isolated local Chrome composition preview
> with cached dependencies and no hosted configuration. Inspect actual rendered
> editing/invalid/freeze/admit/select/joint review/export/reopen/reset behaviour,
> present the founder walkthrough and stop for founder visual review before any
> integration/publication. No fetch/push, hosted contact/import/publication, production
> wiring, athlete writes, real content, persistence services, v2 running editing,
> unrelated tracking, other block modes, device build/install or broader Stage 2/C
> closure. Four record-dependent phone checks remain pending. Do not start another task.

## Implementation order

1. Read instructions and confirm exact clean base/branch; establish protected base
   file hashes and all older checkout snapshots without optional index refresh.
   Treat cached origin/main as cached. Obtain no dependency/network/configuration
   through a hosted/staging helper. Preserve approved docs and founder authority.
2. Add the explicit D1 provider seam and its unchanged-default compatibility
   tests. Use a trusted detached seed; dynamic sessions are separately exact-checked,
   not excluded from validation. Embedded D1 fixture label must be valid, and its
   actions must not bypass joint source validation or reset only one source lane.
3. Implement immutable admission with atomically captured sources and one lineage.
   Reuse D2 revision allocation/freezing; no frozen-state replacement/deletion.
   Expose separate admitted/select states and a reference table with tuple/digest.
4. Compose exact-source programme-aware review and all-slot validation. Joint
   coordinator owns component lifetimes and tokens. Define invalidation before
   UI wiring; race tests use controlled Futures and completion listener edits.
5. Implement strict deterministic transport export/read-only reopen. Current review
   claims are derived; no envelope field grants trust. Retain exact source strings,
   recompute fingerprints/digests/bindings and reject malformed/incomplete packets.
   Bundle reopen is review reconstruction only, not authoring archive/resume.
6. Reuse the existing forms with optional composition hooks; hide the D2 fixed
   wrapper's programme controls in this mode. Keep standalone D1/D2 entries and
   defaults unchanged. Add combined toolbar, admission/selection confirmations,
   current binding receipt, clear error/readonly status, reset and actual Studio.
7. Run checks below, fix confirmed defects only and record outcomes honestly.
   Document inherited unresolved production traversal edges; do not ignore new
   composition/importer edges to make an isolation check pass. Leave clean commits.
8. Start and inspect the local Chrome preview, then request founder visual review.
   Return implemented scope, exact full commits/worktree, test/analysis/safety/
   protected/preservation evidence, preview address and limitations. Stop there.

## Planned checks (not run by allocation)

From the future implementation root, capture exit statuses and external logs:

```bash
flutter --suppress-analytics analyze --no-pub
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
./tool/testing/run_phase2_consolidation_safety_gate.sh
git diff --check
```

Add scoped analyze for every new/changed Dart file. Compare exact before/final
full diagnostic identities, not counts alone. From packages/cohort_plan_package
run `dart test` using cached dependencies. Existing six-group safety script stays
unchanged; if needed use the accepted Bash flutter wrapper adding --no-pub, record
all six actual groups/tool path and never skip a group. No DB gate is needed for
this purely transient source composition. Validate all added/changed local Markdown
links and protected baseline hashes, including published inputs and goldens.

Meaningful races include joint compile vs programme edit/admission/selection;
async admission vs draft/reset/dispose; selection vs later selection; reopen vs
newer request; errors arriving after newer success; edits in success listeners and
microtasks before export/copy consumes its receipt; stale open review/dialog.
Cancellation/full reset must prove no hidden reference upgrades or late result.

## Future local preview procedure

Verify a free loopback port; 4195 is the established local Studio port. Run only
from the implementation worktree after its checks, not during allocation:

```bash
flutter --suppress-analytics run -d chrome \
  --web-hostname 127.0.0.1 --web-port 4195 --no-pub \
  -t lib/main_programme_studio_composition_preview.dart
```

No Supabase credentials, athlete account or production launch configuration.
Founder walkthrough:
1. Validate original R1 programme and inspect exact source/reference/body receipt.
2. Create a same-title changed session; show an invalid draft clears current
   success, then validate/freeze. Programme still selects R1; new entry is unadmitted.
3. Explicitly admit it; programme slot still selects R1. Explicitly select it for
   one required slot; edit D1 metadata/placement and refresh readable joint review.
   Compare package hash and source digests, showing their separate meanings.
4. Export the complete handoff, reopen in separate read-only review and re-export
   identically. Reject a packet missing/altering a source and bare programme YAML.
   Reset live workspace/reload to original fixture; no temporary edit becomes content.

Retain desktop/narrow/text-scale checks. Record founder review as browser evidence,
not device/hosted validation. Final integration/main publication require fresh
separate founder authority after visual review; no next implementation starts.
