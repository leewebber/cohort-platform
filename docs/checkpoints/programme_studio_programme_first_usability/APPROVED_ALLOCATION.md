# Allocation proposal: programme-first session editing and portable review

2026-10-17 (Asia/Makassar). PROPOSAL ONLY — implementation and commits are not authorised.
Exact inspected published commit: `0767ac6a80fc6611598b9ca5f2c991d3f76125a6`.
Inspection/preview checkout: `/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform` (clean, detached HEAD). No fetch or hosted contact.

## Authority and interpretation

Founder feedback remains authoritative: functionality was tentatively observed;
detailed manual outcomes were uncertain; the workflow was confusing and not user
friendly; full visual/usability acceptance was not granted. The technical publication
record does not establish usable-product acceptance. This proposal addresses that gap
using the current capabilities, without another synthetic expansion or invented sprint.

Read root AGENTS.md, CURRENT_CHECKPOINT.md, the strength-lineages FINAL_TECHNICAL_REVIEW,
the binding Studio/launch-library/product roadmap contracts, D1/D2/composition acceptance
records and current controller/screen/transport source. No implementation files were
changed. Preview compilation was local web-only, with cached dependency metadata and
`--no-pub`; no analysis or automated test suite was rerun in this allocation.

## Directly observed interface exercise

Used the published composition entry in Chrome and the local in-app browser. The wide
Chrome opening screen and the live in-app workflow were inspected; the latter used its
normal narrow panel viewport. This is agent inspection, not founder acceptance or a
new device test. The composed interface embeds the accepted D1 and D2 components.

1. Started with A R1 and the existing programme. The untouched seed says “Sources changed — refresh joint review”. The initial session page does not show the selected programme version beside the opened session.
2. Created an A R2 draft. Cleared the first exercise's exact reps and validated. The visible error was `FormatException: exercises[0].prescription.reps: Enter a positive integer.` It is separated from the affected field.
3. Entered 6 reps as mechanical synthetic inspection input (original is 2 sets/5 reps), validated, then froze R2. Saving requires the author to discover validation first; freeze calls validation again internally. Success says “Lineage A R2 frozen; admission and selection remain separate.”
4. In Programme, the version picker still offered only R1. R2 required a separate Catalogue visit, “Admit frozen revision” and confirmation displaying a protocol ID, lineage ID and source digest. Both catalogue rows then said admitted, while the current reference still pointed to R1.
5. Returned to Programme, chose R2 and confirmed another technical tuple/digest dialog. The picker then showed R2. The selection distinction is technically correct, but scattered across screens and expressed in implementation terms.
6. Joint validation enabled export. Review opened an intermediate bindings page; “Open Studio review” finally displayed the understandable prescription: 2 sets/6 reps, 12.5 kg, 1 minute rest, tempo and cue. Existing Studio already supplies the useful human review; it is buried behind navigation.
7. Export opened a JSON/YAML/source-tab dialog, not a plain-language summary. Copied the complete synthetic handoff, pasted it into Reopen, and reconstructed a separate read-only review. It retained both A R1 and R2, including unselected R1. Re-export copied exactly the same 8,490 characters. Reopened Studio displayed the selected 6-rep prescription read-only.
8. Reopen correctly did not replace live editing, but it cleared live review and displayed “Sources changed” / “No current live joint review”, even though live source was unchanged. That is misleading presentation of review freshness, not evidence of a source mutation.
9. Reset through the existing confirmation to the clean A-only R1 seed. Stopped only this task's preview after inspection.

The D1 source also requires typing an “Explicit unique slot key” to add a workout. This
was inspected in source, not exercised in this browser run. It is another internal
identifier that an author should not have to invent.

![Observed existing read-only prescription review](/private/tmp/cohort-studio-usability-allocation/observed-readonly-review.png)

## Evidence pointers

All repository links below refer to the clean inspected checkout at the exact commit.

- [Studio canonical-source and publication boundary](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/architecture/Programme_Studio_v1.md:93), [Stage 2/3 separation](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/architecture/Programme_Studio_v1.md:164).
- [Launch-library sequence](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/architecture/Launch_Programme_Library_v1.md:466), [human launch quality gate](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/architecture/Launch_Programme_Library_v1.md:375), [product launch-library requirements](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/planning/Athlete_Product_Completion_Plan_v1.md:818).
- [Qualified founder feedback and final review](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/checkpoints/programme_studio_strength_lineages/FINAL_TECHNICAL_REVIEW.md:9).
- [Current shell, duplicate validation and tabs](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_screen.dart:47), [catalogue mechanics](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_screen.dart:228).
- [Editor validation/export/freeze actions](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/protocol_authoring/protocol_authoring_screen.dart:154), [freeze already validates](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart:449).
- [Manual slot key](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/authoring/programme_authoring_screen.dart:714).
- [Separate admission mutation](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_controller.dart:179), [read-only reopen and export consumption](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_controller.dart:331).
- [D1 acceptance](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/checkpoints/programme_studio_d1/FINAL_REVIEW_AND_ACCEPTANCE.md), [D2 acceptance](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/checkpoints/programme_studio_d2/FINAL_REVIEW_AND_ACCEPTANCE.md), [composition acceptance](/Users/leewebber/.codex/worktrees/studio-usability-allocation/cohort_platform/docs/checkpoints/programme_studio_composition/FINAL_REVIEW_AND_ACCEPTANCE.md).

## One recommended milestone

Deliver one coherent **programme-first edit → save version → deliberately use version → review → export/open read-only** path over the existing capabilities. It remains a temporary local authoring workspace using the same fixed synthetic sources and supported fields. This is a usable bounded workflow milestone, not Stage 2 completion or a production-ready content authoring product.

Programme opens first with workout cards. Each card shows day, workout title, selected
session version and a concise prescription. Primary action: **Edit session**. A
secondary **Choose version** opens versions for that workout; there is no automatic
“latest” replacement. Sessions is the secondary view for the two existing sessions,
including their existing explicit blank second-session creation; no new lineage or
representation is added. Use stable author-facing “Session A / Session B” subtitles
when titles collide; full identities remain internal, inspectable under Advanced.

Keep D1 metadata and schedule capabilities, including move/remove/add on the current
skeleton. In the composed author-facing add-workout flow, choose an existing day and
session/version; allocate the unique slot key internally using the current D1 identity
rules, against current keys, with the existing locked required-slot template. Do not
ask the author to type keys, infer a new schedule, create unsupported days, or change
the shared revision allocator. A first same-workflow implementation may use existing
admitted versions for adding a slot; choosing a newly saved version then uses the same
explicit version-use coordinator below. Standalone D1/D2 defaults remain compatible.

### Current versus proposed

| Current steps | Proposed author step | Visible outcome |
|---|---|---|
| Session → lineage → frozen source → Create local draft revision | Programme workout card → **Edit session** | “Editing a copy of Version 1. Programme still uses Version 1.” |
| Edit → Validate and refresh review → Freeze local revision | Edit → **Save new version** | “Version 2 saved for this visit. Programme still uses Version 1.” |
| Catalogue → Admit → technical Confirm → Programme → revision picker → technical Confirm | **Use this version…** → confirm named workout/day and before/after prescription | “Week 1 · Day 1 · Workout 1 now uses Version 2.” |
| Joint validate → Review tab → Open Studio review | **Review programme** | Validate all slots, then open the existing human prescription review directly. |
| Export handoff → JSON/YAML/source tabs → Copy | **Export complete review** → plain summary → **Copy review export** | Clear inventory and temporary/read-only limitations; raw content under Advanced. |
| Reopen → paste JSON → Reconstruct → Review → Open Studio | **Open exported review** → paste → **Open read-only review** | Clearly separate read-only programme, selected prescriptions and included versions. |

Do not merge saving a session version with replacing a programme slot. The save result
must offer **Use this version…** and **Keep current version**; neither is preselected
as consent. Leaving the editor does not select. Editing any frozen version makes a new
draft; version numbers may skip after abandoned drafts and are not renumbered for UX.

### What can safely be coordinated

- **Save new version:** validation, exact-byte compilation and immutable freeze behind one explicit button. `freeze()` already validates. Do not require a separate validation click. It does not admit/select/publish, and it does not imply disk storage.
- **Review programme:** joint validation plus opening the actual current Studio view. Do not require knowing which review tab or validation lane to use.
- **Export complete review:** current joint validation plus existing export and final consumption guards. Do not reuse a merely enabled button or stale displayed bytes.
- **Use this version:** exact admission, if needed, plus one confirmed required-slot selection may be coordinated only through a new narrowly scoped atomic operation in the existing composition/controller layer. This is a real prerequisite gap, not a rename of `await admit(); await selectRevision()`.

For the last action, prepare the exact target slot/version and current owner, programme
and catalogue snapshots. Recompile the exact genuine owner-retained object(s), stage
admission and the target reference with existing catalogue/source/slot validation, then
recheck all captured generations and identities. Commit the catalogue references and
one selected slot synchronously as one observable edit, before notifications. If any
check fails or consent is cancelled, mutate neither admission nor selection. Preserve
the saved frozen version so the author can retry. Do not roll back immutable history.

If a B descendant needs its not-yet-admitted B root, include that genuine root in the
staged admission and name the included earlier version in the consent summary. Never
silently introduce a foreign/forged root or omit a declared root from export. Existing
admission-only behavior can remain as a secondary **Add to programme without changing
workouts** action: it means available, not selected. This retains the ability to carry
unselected versions without making catalogue mechanics a required part of the main task.

Preserve original standalone admission/selection methods and compatibility tests. No
new catalogue implementation, editor, persisted store or source of authority is needed.

### States and messages

Treat these as transient workspace states, not new publication lifecycle states.

| State | Required visible text | Primary action / recovery |
|---|---|---|
| Existing selected session | “Using Version 1 in Week 1 · Day 1 · Workout 1” | Edit session / Choose version |
| Working draft | “Unsaved changes. Programme still uses Version 1.” | Save new version; Discard changes |
| Saved, not added | “Version 2 saved for this visit · not in programme or review export” | Use this version…; optional Add to programme without changing workouts |
| Admitted, unselected | “Available in this programme · not used by any workout” | Choose where to use it; included in complete review export |
| Selected | “Version 2 · used in [named workout/day]” | Review programme; never just “latest” |
| Review not yet checked | “Programme has not been checked yet” | Review programme |
| Source changed after review | “Programme changed since review” | Review programme again; old success/export unavailable |
| Reopened review | “Read-only exported review. Your temporary workspace has not been replaced.” | Return to workspace; Copy review export |
| Live review invalidated by reopen | “Review the workspace again before exporting it” | Do not claim its source changed merely because a review receipt was cleared. |

Same-title versions show title + Session A/B + actual version number + selected/available
badges and prescription differences. Use exact tuple keys internally, never titles or
list position as identity. Show all usage locations for versions used in more than one
slot; availability and selection are not mutually interchangeable states.

Default interface wording:

- Banner on all live screens: **“Temporary workspace. Changes are lost when you reload or close this preview. Export a complete review to keep a review copy. Reopened exports are read-only; you cannot continue editing from them.”** Keep the synthetic/example label visible.
- Reps error beside Exercise 1: **“Enter a positive whole number of reps.”** Summary: “Fix 1 field before saving.” Retain the author's input and focus/link to the field.
- No-op save: **“No workout changes to save. Make a change or discard this draft.”** No number reuse or silent version creation.
- Failed version use: **“We couldn't use this version. Your programme and available versions were not changed. The saved version is still here; try again.”** Only use this wording if the new atomic action establishes it.
- Changed during a pending action: **“The workspace changed while we checked this. Review the current workout and try again.”** Never show late success from a stale operation.
- Draft blocks review/export: **“Save or discard your session changes before reviewing the programme.”** Offer a route to the draft; do not silently cancel, save or select it.
- Export summary: “Includes this programme, its selected session versions and every version added to the programme, including unused versions.” List saved-but-not-added versions under **“Not included”** with their names/numbers; do not imply all frozen private versions were exported.
- Copy success: **“Review export copied. Keep the complete copy somewhere safe. It opens read-only.”** No “project saved” or “backup complete” claim.
- Invalid reopen: **“This review export is incomplete or unsupported. Paste the complete review export. Your temporary workspace has not been replaced.”** Preserve rejected text for correction and show exact reason under Advanced. Never accept raw programme YAML as complete.
- Reset: **“Discard this temporary workspace and return to the example?”** Explicit destructive-within-workspace confirmation; no effect on other checkouts or published artifacts.

Advanced retains exact source YAML, byte/text diff, full tuples, owner/provenance,
exercise/profile bindings, source digest, body-excluding package hash meaning and raw
compiler errors. Moving them does not remove checks or imply digest consistency proves
historical freeze provenance or founder approval. Keep supported-form restrictions
visible where they affect decisions, with explanatory text rather than compiler paths.

## Expected component changes after separate implementation approval

| Component | Bounded change |
|---|---|
| `composition/synthetic_composition_screen.dart` | Programme-first shell, contextual edit/save/use/review flow; state badges, optional Advanced, plain export/reopen summaries; reuse actual Studio presentation. |
| `protocol_authoring/protocol_authoring_screen.dart` | Optional embedded author-facing presentation: one save button, draft/selected version feedback, field-error routing, technical exports in Advanced. Reuse the same form and controller. |
| `composition/synthetic_composition_controller.dart` | Atomic prepared use-version operation; distinguish presentation invalidation reasons; reuse both-owner freshness, ownership, async completion/consumption/reset/disposal guards. |
| `authoring/programme_authoring_controller.dart` | If needed, a bounded batched catalogue/target-slot edit so the existing editor emits one coherent notification after preflight. No locked-contract relaxation or parallel tree authority. |
| `authoring/programme_authoring_screen.dart` | Composed presentation hooks for human labels, contextual session editing/version choice and generated unique slot keys; standalone defaults retained. |
| Existing programme revision catalogue | Stage/check batch with existing policy/instances if required by atomic coordination; no new catalogue implementation or trust boundary. |
| Small presentation helper, if useful | Derived display states, version usage and known error-to-field mapping. Preserve unknown/raw diagnostics under Advanced; do not change compiler validation. |
| Existing Studio tests + focused orchestration/widget tests | Cover outcomes and races; preserve old transport, standalone entries and isolation. |

No session compiler, shared schema/hash, canonical resolver, revision allocator, source
writer, fixed identities/profile, representation, real content or transport version
change is proposed. Existing B creation remains explicit and blank, on its fixed policy.
No dependency, backend, persistence, hosted publication or production route is needed.

## Acceptance for this bounded milestone

### Short founder task, judged by outcomes

Use only the existing synthetic example, not a real training prescription:

1. Open the programme. Find the first workout and say which session version it uses. Click Edit session, change the first exercise from 5 to 6 reps, and Save new version.
2. Confirm the screen says the new version exists while the programme still uses the old one. Review the difference, deliberately use the new version in that workout, and confirm the new selected version is unmistakable. A cancelled change must leave the old selection.
3. Review programme. See 2 sets/6 reps and unchanged load/rest/tempo/cue in the actual prescription; navigate every selected workout in the available programme. No tuple, digest, YAML or catalogue knowledge should be needed.
4. Export the complete review and open that copy. Verify the same selected prescription, original unselected version in the included-version list, and read-only status. Explain in the founder's own words that the copy does not resume editing and that live changes are temporary.

A lightweight negative check: clear reps, try to save, find and correct the field from
the message without technical guidance. Record each outcome and any assistance, rather
than translating “I think it works” into a pass. Full visual/usability acceptance for
this milestone requires explicit founder confirmation of these outcomes. That is a
proposed acceptance criterion for the usability task, not a retrospective assertion
about the published slice or a universal integration prerequisite.

### Technical regressions required during implementation

- Save validates and freezes once as an author action; failure/no-op/cancellation cannot create an unintended version or change selection. Old bytes and the other owner remain immutable; abandoned numbers retain their original rules.
- Atomic use-version: no partial admission/slot change on failed source/profile checks, invalid target, failure at the later selection preflight, cancellation, conflict, reset or disposal. Genuine roots included when required; idempotent repeats. No new live admission before explicit final slot consent.
- Existing same-title/same-number A/B identities remain distinct through list badges, editor, dialogs, selection, review and export. Never auto-select latest or lookup by display label.
- Saved/private, admitted/unselected and selected states render accurately, including multi-slot usage. No copy/export summary promises inclusion of private frozen entries. Add-only still does not select.
- All-slot selection, movement/order and auto-generated unique slot keys preserve locked templates and existing refusal of invalid schedules. Cancelled add/move/choose operations leave sources unchanged.
- Async stale responses, competing choices, notification edits, queued reset/disposal, both-owner changes, late failure and copy consumption retain guards. Do not overwrite newer busy/receipt states or allow stale confirmation to apply to a moved/deleted slot.
- Reuse actual projector/Studio with full supported body fidelity. Review opens the candidate, not stale seed or merely the newest version. Unsupported prescriptions remain failures, never omissions.
- Complete deterministic v1/v2 transport, all declared selected/unselected revisions/roots, tampered/duplicate/missing/foreign/altered-profile refusal and read-only reopen/re-export isolation remain compatible. Reopen never hydrates editing or restores history/reservations.
- Desktop keyboard/mouse completion of the whole task; labels/focus and live status support accessibility. Narrow and large-text layouts remain usable without overflow. Raw technical details optional, no required internal IDs.
- Standalone D1, D2, composition, importer/identity, canonical-package and protected-artifact compatibility. Run affected regressions, canonical-package suite, all six unchanged safety groups, full-range diff/local-link checks and checkout preservation inventories.
- Fresh pre-edit and post-edit full-analysis identity comparison; zero errors, zero new/changed-file diagnostics and no new inherited diagnostics. Do not suppress/exclude issues or borrow an old green claim. The LAST VERIFIED result is non-green: 367 diagnostics, 110 warnings, 257 info, zero errors. It was NOT rerun for this allocation.

## Roadmap coverage and product decisions

| Classification | Evidence and remaining gap |
|---|---|
| Binding Stage 2 requirement | Studio §§3/5 requires controlled forms/editors generating the existing canonical Plan Package and protocol authoring sources, without a parallel store or hosted publication. Current D1/D2/composition cover bounded portions; the proposed milestone makes those portions usable as one task. |
| Required launch capability, not automatically a required editor feature | The product plan §4 and launch-library §§8/10 require complete authored progression, canonical exercise identity, full prescriptions/policies, honest evidence, editorial/coaching approval, compile/review and real-world quality gates. An editor for every locked declaration is not specified as the only way to supply those canonical sources. Existing operator paths remain valid. |
| Unallocated coverage decisions | First practical programme creation/intake, schedule structures, prescription representations and treatment of currently locked declarations must be selected against the first real authoring use case. No universal Stage 2 closure checklist is enumerated. Current one-week/fixed-profile workspace does not establish that coverage. |
| Unresolved practical limitation | This visit's edits cannot be resumed from the review export. Founder must decide whether a temporary authoring/portable read-only-review milestone is acceptable now, or whether editable project restoration is a subsequent product requirement. Recommend retain the current boundary for this usability milestone and name it plainly. Do not silently add persistence/archive trust. |
| Optional absent a concrete requirement | More than the existing two lineages, broader profile trust, a generic catalogue/editor framework and arbitrary representation expansion. Editable archive restoration is also not a binding Stage 2 requirement by itself, though it may become a product requirement. |
| Separate downstream gates | Real-content authority and founder coaching approval; hosted import/publish, production/athlete wiring and release/device gates. Studio Stage 3 buttons may stay command-line (Studio §5). Broader C remains open; no inference of comparison authority from shared fixtures. Four record-dependent phone checks remain pending. |

Two decisions need to be explicit before broader product closure: acceptance of this
milestone's temporary/read-only portability boundary, and the first real authoring
use case whose source/schedule/representation coverage defines the next required gap.
Neither decision authorises content or backend work in this allocation. No new sprint
number or broader Stage 2/Sprint C completion is proposed.

## Ready-to-run implementation handoff (requires new founder approval)

> Implement only the programme-first authoring usability allocation in this document,
> after explicit founder approval, from exact published
> `0767ac6a80fc6611598b9ca5f2c991d3f76125a6`. Read AGENTS.md,
> CURRENT_CHECKPOINT.md, binding Studio/roadmap contracts and the strength-lineages
> FINAL_TECHNICAL_REVIEW. Preserve the allocation and qualified feedback durably in
> new checkpoint documentation. Use a separate managed clean worktree on a new
> `codex/studio-authoring-usability` branch; preserve all older checkout contents,
> HEADs, indices, dirty paths and .temp, including original local main and 95 paths.
>
> Reuse D1 metadata/schedule, D2 form/controller, existing two owner catalogues and
> admitted catalogue, actual Studio and complete source transport. Provide one
> Edit session → Save new version → deliberately Use this version → Review programme
> → Export complete review → Open read-only review flow. Saving validates/freezes
> without selecting. Add contextual selected/available/private version feedback,
> field-level recoverable errors, plain temporary-workspace and read-only messaging,
> optional Advanced details and human slot labels/unique internally generated keys.
> Coordinate admission and one confirmed target-slot selection only through prepared
> validation and an atomic current-snapshot commit; never merely chain the two
> mutating methods. Cancellation/failure must change neither side. Preserve the
> original standalone APIs/defaults and all tuple/owner/source/profile, immutable
> revision, every-slot, freshness/notification/consumption/reset/disposal guards.
>
> Keep saving and selecting separate; no automatic latest-version use. Preserve
> exact roots, all declared unused revisions, private-entry exclusion, deterministic
> transport-v1/v2 compatibility and isolated read-only reopen. No persistence claim,
> editable restore, extra lineage/type/profile, compiler/schema/hash/resolver/allocator
> change, real content, hosted publication, production wiring, migration or device
> work. Run the focused tests and all gates above with a fresh full-analysis baseline;
> retain the inherited non-green qualification. Local focused commits and preview
> require the new approval; no fetch/push/integration without separate authority.
> Restore the A-only seed and stop for the short outcome-based founder usability
> review. Do not call the whole Stage 2/Sprint C complete or close the four phone checks.

## Allocation closeout

No implementation or commits. All source changes in the exercised preview were
transient browser state and reset afterward. No tests or analysis rerun; historical
technical gate results are cited only as historical. Preservation proof and final clean
checkout/preview status are in the adjacent local `PRESERVATION.json` receipt. This
allocation and UI evidence are outside the repository; they have not been published.
