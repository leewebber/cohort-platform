# Programme Studio composition — local implementation handoff

> **Final review continuation — 2026-10-13:** [Founder acceptance and final review](./FINAL_REVIEW_AND_ACCEPTANCE.md) supersede the visual-review pause below. All four founder walkthrough steps passed; scoped callback-lifecycle/completion and export-consumption guards are verified, original R1-only seed restored and preview stopped. [Fresh final evidence](./FINAL_REVIEW_VERIFICATION.json) retains the inherited non-green analysis qualification and preservation proof. Earlier implementation facts below remain historical; broader Stage 2/C and four phone checks remain open.

**2026-10-13 · COMPOSITION_IMPLEMENTED_LOCALLY_AWAITING_FOUNDER_VISUAL_REVIEW.**
This implements only the [approved allocation](./ALLOCATION.md),
[implementation scope](./IMPLEMENTATION_HANDOFF.md) and [founder authority](./APPROVAL.md).
It is a bounded Sprint D / Stage 2 composition slice, not a new roadmap-numbered
sprint or broader Stage 2/Sprint C closure. Four record-dependent phone checks
remain pending. No integration, fetch, push or hosted project operation occurred.

Binding references: [launch-library roadmap](../../architecture/Launch_Programme_Library_v1.md),
[Studio contract](../../architecture/Programme_Studio_v1.md),
[D1 acceptance](../programme_studio_d1/FINAL_REVIEW_AND_ACCEPTANCE.md),
[D2 acceptance](../programme_studio_d2/FINAL_REVIEW_AND_ACCEPTANCE.md).
Fresh task results are in [verification](./VERIFICATION.json),
[protected artifacts](./PROTECTED_ARTIFACTS.json) and
[older-checkout preservation](./PRESERVATION.json).

## Delivered workflow

The dedicated [local entry](../../../lib/main_programme_studio_composition_preview.dart)
opens the existing D2 synthetic seed: one week, two existing days, one initial
required slot selecting R1, and nonempty progression/adaptation/invariant/
assessment/evidence/comparison contracts. Programme name from seed source:
**Synthetic D2 revision selection**; R1 session title: **Synthetic strength session**.

- Reuse D1 metadata, existing week/day titles/notes, and required-slot add/remove,
  order/placement and exact revision choice. Locked contracts remain source authority.
- Reuse D2's one-block straight-sets editing, canonical exercise identity resolver,
  complete Founder writer, exact-byte validation and immutable local revision freeze.
  A no-op draft cannot freeze. Frozen-parent bytes and references remain intact.
- Separately confirm admission of a genuine owning-catalogue frozen entry. Exact
  recompile verifies tuple, digest, complete meaning and fixed exercise-version
  bindings; append-only exact repeats are idempotent. Foreign, unfrozen, conflicting,
  missing and unsupported sources fail closed. Admission alone does not select a slot.
- Separately confirm an admitted exact revision for an existing required slot.
  Same-title revisions are distinguished by protocol/lineage/revision tuple and
  source binding. No title lookup, implicit latest selection or replacement.
- Validate the exact D1-written programme bytes and every declared frozen source.
  Actual existing Studio projection reviews every slot with its complete supported
  prescription. The joint receipt retains canonical programme JSON/package hash,
  exact source strings/digests/exercise bindings and an ordered slot/source inventory.
- Export a complete strict deterministic JSON source handoff, with inspectable
  programme YAML and every declared Founder source, including unselected revisions,
  explicit bindings and the fixed fixture-profile fingerprint. Programme YAML alone
  contains references and is insufficient to reconstruct session review.
- Reopen into a separate read-only reconstruction, recompile and recompute every
  claim, and deterministically re-export. Reopen never hydrates/overwrites the live
  editable catalogue or restores reservations, frozen-parent history or draft state.

[Controller](../../../lib/features/programme_studio/composition/synthetic_composition_controller.dart),
[catalogue/source policy](../../../lib/features/programme_studio/composition/synthetic_programme_revision_catalogue.dart),
[review bridge](../../../lib/features/programme_studio/composition/synthetic_composition_review_bridge.dart)
and [transport](../../../lib/features/programme_studio/composition/synthetic_composition_handoff.dart)
are isolated local composition components. Narrow optional D1 source/selection
and D1/D2 embedding hooks preserve standalone defaults. Shared compiler, schema,
hash, writers, resolver, revision allocator and existing Studio presentation are unchanged.

## Ownership, freshness and hash meaning

Both exact source lanes and immutable tuples/binding maps are retained independently
of editable trees and rendered projections. Programme/catalogue/selection edits clear
D1/joint success; D2 draft creation/edit/reset/reopen/cancel, failed validation and
freeze conservatively clear joint success. An open session draft blocks live joint
review/export until freeze or cancellation; frozen selections remain unchanged.
Failed operations clear joint success without partial catalogue or selection updates.
Monotonic tokens protect awaits, notifications, completion microtasks, reset and disposal;
stale success and errors cannot become current. Open Studio/export views lose current
status when their receipt is invalidated. Read-only reconstruction is a separate source
review, and conservatively clears on subsequent workspace edits.

The programme package hash retains its existing **body-excluding** meaning.
Session source SHA-256 binds exact UTF-8 bytes and is displayed separately. Neither
fingerprint nor source digest proves founder approval, publication or historical freeze
provenance. A pure regression demonstrates identical programme hash for changed body
bytes under a fixed tuple; live admission rejects that replacement. No production joint
hash was introduced. Text comparisons use original imported programme bytes and exact
frozen-parent Founder bytes. Canonical export normalizes formatting; formatting
preservation is not promised.

## Fresh validation

- **331 affected root regressions pass**, covering Studio/D1/D2, new composition,
  Founder import, authored packages, identity boundaries and session compatibility.
  The new composition set contains 45 meaningful controller/admission/transport,
  widget and isolation checks, including disposal, latest-selection, pending edits,
  reset, stale failure, synchronous and queued completion edits.
- **41 canonical-package tests pass**, including existing v1/v2 compatibility/goldens.
- **Zero changed-file diagnostics** across all 15 changed/new Dart files.
- Full analysis is **not green**: fresh before/after diagnostic lines are identical,
  **367 inherited issues: 110 warnings, 257 info, zero errors**, no additions/removals.
  Initial analysis without the ignored server package configuration produced import
  noise; cached local package configuration was prepared before implementation and
  the valid pre-edit baseline rerun was 367. No tracked dependencies were changed.
- All **six unchanged safety groups pass**; diff whitespace and checkpoint relative
  links pass. Baseline file hashes protect every existing file outside four narrow
  code/test seams and the new current-checkpoint pointer. Compiler/schema/hash,
  published artifacts, v1/v2 goldens, migrations, release guards and production entries
  are byte-identical to the exact approved baseline.
  Dedicated composition/importer dependency traversal resolves every local edge
  strictly. Existing production traversal retains D2's documented qualification
  for inherited unresolved relative edges; an independent scan of every older app
  source proves no direct import/export/part into composition, and all older entry
  graphs remain unable to reach it. No new missing edge is ignored.
- Meaningful fail-closed cases include altered bytes/digests, bindings, identity,
  fixture fingerprint, missing/extra/duplicate sources and escaped duplicate JSON
  fields, unknown envelope fields, wider unsupported wrappers and bare programme YAML.
  Exact profile checks reject changed exercise versions even when compilation succeeds.
- Native Chrome inspection exercised required-name and no-op refusal, changed draft,
  validation/freeze, admission with R1 still selected, confirmed R2 selection, actual
  Studio display of 2 sets × 6 reps / 12.5 kg / tempo, programme edit invalidation,
  complete two-source export and separate read-only reopen with identical re-export.
  Full reset restored original R1-only catalogue, initial slot and programme name.
  Layout overflow found by the large-text widget check was fixed in the new export
  dialog. Test-only scroll/focus timing was corrected; no standalone changes required.

## Branch and commits

Managed worktree: `/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform`.
Branch: `codex/programme-studio-composition`.
Exact base/cached origin-main: `6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6` (no fetch).

1. `f90a2094d0a63d78803790471fb42863645b688c` — preserve approved allocation/scope.
2. `9a78f4cf5cbadabe948a1870972a8292beef8043` — isolated implementation and hooks.
3. `2198a78b94872beccf1dd7d15f3b816a79723d29` — bindings/freshness/handoff regressions.
4. This checkpoint/evidence commit — retrieve exact HEAD with `git rev-parse HEAD`;
   the final response reports its full SHA. All commits are local and linear.

All three older snapshots retain HEAD, branch, index bytes, tracked/dirty contents
and `.temp`; the original still has exactly 95 outstanding paths. Allocation's
line-based status serialization lost a leading character on its first path; fresh
NUL-delimited status explicitly corrects that serialization defect only and proves
unchanged index/content/95 paths. No older checkout was switched, reset, stashed,
cleaned, staged, committed or advanced. Original local main stays at `a331f529…`;
older D1 stays at `6318f319…`, D2 at `6f83f732…`. No remote relationship was fetched.

## Founder Chrome walkthrough

Preview: <http://127.0.0.1:4195/> — running locally, original seed restored.
Established procedure, from the isolated worktree:

```bash
flutter --suppress-analytics run -d chrome --web-hostname 127.0.0.1 --web-port 4195 --no-pub -t lib/main_programme_studio_composition_preview.dart
```

1. In Session create a draft; edit a rep count, validate and freeze. Catalogue shows
   it frozen/unadmitted. Admit it and verify the programme still selects R1.
2. In Programme explicitly choose/confirm the new revision for the required slot;
   edit programme/day metadata if desired. Validate joint review; open Studio from
   Review and inspect the exact prescription, slot mapping and separate digests/hash.
3. Edit programme/session again: previous joint review/export becomes unavailable.
   Freeze/cancel the session draft as appropriate, then refresh joint validation.
4. Export complete handoff; copy/paste into Reopen read-only review, inspect its
   separate Studio and deterministic re-export. Live authoring remains intact.
   Reset to original seed restores the original synthetic workspace.

Founder visual acceptance is **pending**, not inferred from agent inspection.
Preview remains running; no integration or publication is authorised by this handoff.

## Limits and stop boundary

No scope deviations or new content authority. Only the two fixed synthetic exercises,
one D2 strength-block representation and one local lineage are supported. Unsupported
contracts/types/wrappers fail closed. Workspace is transient; reload/reset discards local
additions. Read-only transport is not an authoring archive or a persistence service.
No real content, profiles, hosted import/publication, production wiring, athlete writes,
v2 running authoring, tracking work, migrations, release changes or device build/install.
Broader Stage 2/Sprint C and the four record-dependent phone checks remain open.
Stop here for founder visual review; do not start another slice.
