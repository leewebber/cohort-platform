# M1.1 — bounded founder authoring in existing Programme Studio

2026-11-01 (Asia/Makassar). **IMPLEMENTATION_READY_ALLOCATION; BUILD NOT STARTED.**
Base: `2c716b45ba63432e733ed2fe742472e526954358`, matching live GitHub main.
The [M0–M10 release plan](../../planning/Founder_Release_Plan_M0_M10_v1.md)
controls priorities; this is an allocation within M1.1, not a replacement roadmap.
[Handoff](HANDOFF.md) · [catalogue operation](CATALOGUE_CAPABILITY.md) ·
[ready-to-run implementation prompt](IMPLEMENTATION_PROMPT.md).

## Decision and first outcome

Extend the existing programme-first Studio workspace into one local founder
workspace for the selected Hybrid 10K prescription shapes. Keep its file-based
editable draft mechanism, revision/selection distinction, canonical compiler and
athlete review. Replace fixed synthetic policies through a genuine-source policy;
do not build another editor or reuse the wider Coach Studio as a new product.

First founder acceptance: Lee creates a genuine complete strength session and a
personalised timed running session using names and ordinary training fields, places
both in a programme, saves/reopens the editable draft, and reviews the exact athlete
prescriptions. No manual YAML editing, ID entry or Codex translation is required.
Use selected W1 Monday strength and W4 Tuesday running as the acceptance pair. The
strength session cannot pass genuine complete validation until its missing row is
legitimately created/retained. Pending intent can be saved meanwhile, visibly blocked.

This first pair proves a usable vertical workflow. Completion of this allocation
also requires coverage accounting for **all 70 days: 20 strength sessions, 40 runs
(39 timed and one final 10K), 10 rest days and 105 working exercise occurrences**.
A successful pair does not establish whole-programme admission or D8 approval.

## Owning sources and working components

Paths below describe inspected code at the base, not inferred live deployment.
Older HYROX-first/source-coverage recommendations are historical under M0–M10.

| Existing component | What actually works | Reuse and required change |
|---|---|---|
| `authoring/programme_authoring_controller.dart`, `plan_package_v1_yaml_writer.dart`, `programme_authoring_source.dart` under `lib/features/programme_studio/` | Source-backed programme fields, slots, ordering, metadata, validation and an injectable source policy | Retain source-first edits and compiler issues; add a real-source policy and schema-aware v2 serialization. Do not make the v1 writer silently emit v2 or edit locked contracts incidentally. |
| `composition/programme_first_screen.dart`, `synthetic_composition_controller.dart`, `synthetic_programme_revision_catalogue.dart` | Accepted programme-first local workflow; explicit save/admit/select; atomic consent and stale-result guards | Refactor only common lifecycle/presentation behind source policy. Supply genuine session owners and ten-week schedule; keep old synthetic fixtures/tests as compatibility users. |
| `protocol_authoring/protocol_authoring_controller.dart`, `synthetic_session_revision_catalogue.dart`, `synthetic_strength_lineage.dart` | Separate drafts, immutable saved revisions, parents/reservations, cancel/no-op rules | Generalise owner collection and representation adapter for this source; remove A/B assumptions only from shared path. Use existing session revision conventions, not a new identity allocator. |
| `synthetic_strength_session_compiler.dart`, `founder_strength_source_guard.dart`, `founder_strength_yaml_writer.dart` | Exactly bounded Founder YAML compilation, two EX-900x fixtures, one straight-sets block, exact reps and restricted loads | Preserve old supported path. It is not a real catalogue/compiler adapter. Rich Hybrid fields use existing native protocol graphs below. |
| `workspace_json.dart`, `composition/workspace/`, `local_files/studio_json_files*.dart` | Bounded duplicate-aware parsing; web download/file-picker; atomic editable workspace replacement; invalid drafts/history retained | Extend same editable envelope for genuine owners, graph sources and v2 schedule. Preserve v1/v2/v3 opening, unknown-future rejection and old files; add a new explicit envelope version only because old fixed-profile readers cannot understand these sources. |
| `composition/source_intake/canonical_source_intake.dart`, `source_export/canonical_source_bundle.dart` | Strict complete Studio TAR intake/recompile/export with imported-origin bookkeeping | Reuse safe archive parsing and source/hash inventory. Add an explicitly versioned native-graph inventory member/reader; older archives retain their semantics. Imported history remains unknown. |
| `composition/prescription_comparison.dart`, `projection/movement_prescription_review.dart`, `programme_review_projector.dart`, `presentation/programme_studio_app.dart` | Exact-source comparison, readable review and limitations; compiled catalogue/body projection | Feed exact generated graph and package to existing review. Close only renderability gaps exposed by selected fields; raw JSON is optional evidence, never the main prescription view. |
| `projection/source_readiness_report.dart`, source-coverage handoff | Derived scope/body/identity/coverage findings, not content approval | Reuse categories and explicit omissions; legacy v1/v2 row provenance does not require fabricated v3 definition versions. Do not turn the old v3 readiness requirement into an alpha dependency. |
| `ExerciseCatalogueService`, `ExerciseRepository`, exercise model/detail presentation | Published legacy catalogue reads and equipment/setup/cues where present | Search/filter genuine retained rows; display unknown data as unknown. A search result/name is not sufficient binding evidence. No client writes. |
| `StrengthExercisePrescription`, `StrengthPrescriptionFormatter`, `SessionBlock`, `SessionExecutionPlanBuilder` | Native rep ranges/durations, rest/RIR ranges, per-side/capture data and executable projection | Write the same native prescription JSON used by the selected source graphs. Validate complete field equality and codec round-trip, including authored details. |
| `RunningWorkout`, codec/validator/projector, `TimerConfiguration`, `ReviewedProtocolGraphArtifact` | Structured steps/repeats, timer body and private v1/v2 graph inspection | Add form editing over this representation, retaining exact step order/identity/units; no new running DSL or timer. |
| `alpha_quality_targets.dart`, `running_target_admission.dart`, existing target-review screen/store and M2.3 rules | Real v1/v2 athlete input/review/start/freeze path, locally proved; required hosted migrations held | Author references to these rules. Show symbolic prescription in Studio; any sample target calculation is labelled illustrative, local and non-authoritative. Do not call athlete confirmation/start RPCs from the editor. |
| `bound_personalisation/bound_review_screen.dart` | Explicitly local synthetic v3 integration with partial sessions | Reuse presentation ideas only. It is not Hybrid 10K's v1/v2 target authority or an already connected running editor. |
| `coach_studio/` catalogue/editor/governance | Separate authenticated operations screens over existing programme services | Do not replace or expand into external-coach accounts/CRM. No assumption this surface connects local composition, rich graph authoring or file history. |

Studio authoring entries are dedicated local preview entries. `lib/main.dart` does
not become the founder workspace through this allocation. The primary supported
surface remains the existing local web Studio with file save/open; native file
adapters currently throw unsupported. Provide one documented launch command/entry
for Lee, a genuine-source starting screen and no synthetic seed in the primary flow.
A future in-app/authenticated hosted Studio entry is outside this bounded build.

## Canonical representation and boundaries

Use **Plan Package v2 YAML + native reviewed protocol-graph JSON** for this mixed
programme, consumed by the existing private v1/v2 path and Programme Athlete.
Plan Package v1 remains readable and unchanged. Do not invent exercise fields in
Plan Package or require HYROX v3 source/event/outbox infrastructure.

The selected programme's `SOURCE.json` and associated graphs are retained source
and reconciliation evidence. Bootstrap a local editable draft deterministically
from these, preserving provenance and unresolved identity intents. Subsequent
structured edits own the generated canonical package/graphs, not a second manually
maintained copy of SOURCE.json. Imported published sources open as new local drafts
with exact origins; local draft IDs never claim hosted publication/definition versions.

The Founder YAML mapper does not preserve `per_side`, rest/RIR ranges or full
`authored_details` (its `mapPrescription` reads a smaller set). Do not route richer
native graphs through it and label the result equivalent. Existing source-specific
Hybrid tools are evidence/prototype adapters, not the founder interface. Extract
only needed deterministic conversions into Studio/library code; avoid app imports
of `dart:io` tools or test files.

Use `ReviewedProtocolGraphArtifact.inspect` plus typed block/prescription validation,
source identity checks and native execution-plan codec equality. Graph inspection
alone does not prove every strength field is meaningful or catalogue identity valid.
Package hash does not include all body bytes: retain distinct package, graph and
source digests and exact revision/occurrence bindings in review/export.
The existing `tool/programmes/bin/publish_private_exact_version.dart` already accepts
a reviewed graph path/hash instead of deriving bodies from Founder YAML. Its later
publication artifact requires actual owner/version/activation values; a prepared
Studio export must not fabricate those or invoke that command.

## Bounded adapter contracts for implementation

Extend the existing `ProgrammeAuthoringSource` policy rather than hardcoding a new
fixture. Genuine session compilation takes exact native graph bytes, a local
`SessionRevisionIdentity` and an immutable verified legacy-row evidence collection;
it returns the exact graph/digest, typed blocks/execution plan, binding evidence and
field-level issues. It has no network/write ports. Unknown/unresolved input can remain
an editable draft but cannot return an admitted compiled session.

Extract the existing composition/revision-owner lifecycle into a common adapter used
by the synthetic and genuine policies. The genuine policy supports strength plus
running owners and 1–10 weeks, not just A/B. The source-aware review bridge takes the
compiled package plus **exactly its declared protocol/revision graphs**, validates
and projects those same values; it never resolves by title. Derive the readable review
from that receipt, not an independently maintained example catalogue.

Save genuine workspaces as `cohort_editable_workspace` **v4**, retaining canonical
package/graph sources and local draft/history metadata under an explicit genuine-source
profile. The implementation must document exact allowed envelope keys and limits
before code review. This is a new transport version of the existing editable mechanism,
not a new programme format. Canonical TAR source-index **v2** declares native graph
members and their exact hashes/types; index v1/old editable readers retain original
rules. Retain aggregate selected graphs as derived publication input and individual
unselected sources/history where needed; reject any inconsistent duplicate meaning.
No arbitrary JSON objects, unknown fields or author-supplied profile claims bypass
real source validation.

## Exact functionality to implement

### Exercise selection and catalogue binding

Search by clear name with equipment/movement filters. Result cards distinguish
bilateral chest support, single-arm bench support, seated/back-supported neutral
press and side-held two-DB lunge. Show exact retained equipment/setup/execution,
source-specific coaching constraints separately, and any unknown fields. Technical
IDs/provenance are expandable details. Select an exact row, not an inferred alias.

For the initial local build, load the eight already trusted Hybrid bindings with
their actual row/provenance hashes. Admit additional exact rows only through the
catalogue receipt adapter in [the operation specification](CATALOGUE_CAPABILITY.md).
Do not use the historical 132-row CSV as current global runtime authority or
manufacture ExerciseDefinition versions to satisfy the synthetic profile.

Missing setups appear in the draft as **Unresolved exercise setup — cannot prepare
for publication**, retaining full intended prescription. Offer the prepared operator
request/receipt status. Do not bind EX-090/037/026, substitute a similar exercise or
hide that row. This is saved intent, never an executable null-ID graph.

### Strength fields and actual Hybrid coverage

| Required shape | Selected example and acceptance |
|---|---|
| Multiple blocks and exercises | Separate preparation, main strength and 3–5 minute walking finish. Monday has five work rows; standard Thursday has six. Preserve proposed guidance as guidance, not extra working sets or invented fixed timers. |
| Exact sets; rep ranges | Incline press 3×6–10; pull-up 3×5–8; chest row 3×8–12; lateral raise 3×12–20. Fields show min/max clearly; never collapse to a single rep value. |
| RIR exact/range/lower bound/absent | 2; 1–2; RDL/lunge 2–3; W10 Thursday **at least 3**; Pallof/plank no RIR requirement. Keep lower-bound semantics in authored details/cues, not falsely exact 3. RPE is separate. |
| Rest exact/range/after both sides | 120 s; Pallof/plank 45–60 s; RDL 120–180 s; calf 60–90 s; lunge and unilateral row 90 s after both sides. No invented intra-side rest. |
| Timed hold and per side | Side plank 2×30–45 seconds **each side**, both sides one set, stop before posture loss. Preserve native duration text/semantics; `hold_seconds` is not a replacement for this range. |
| Load/capture conventions | DB external load per DB; RDL total external barbell load; bodyweight initial pull-up; machine/cable actual display/setup. Preserve source unit labels, athlete-selected load and absence; do not fill actuals or assume machine equivalence. |
| Notes, tempo, ordering | Editable coaching notes and source tempo, preparation options/ramp guidance; deliberate reorder included in review. No invented technique or new movement semantics. |
| Week-specific changes | W4 upper three-set work→two, unchanged lower/core doses and no RDL load increase; W7 standard strength; W8 RDL 2×5/lunge 1×6 at 3 RIR, no planned lower increase; W9 reductions/omit lunge; W10 exact short Monday and upper-only Thursday. |

Add/remove/reorder rows and blocks, duplicate a session, create a later draft and
edit any listed field. Validate numeric ranges, ambiguous rest, missing setup,
unknown capture/unit and unresolved representation with readable field errors.
Invalid drafts remain savable, never eligible as validated immutable publication
candidates. No supersets, arbitrary circuit/WOD editor or assistance model is needed.

### Running forms and rule references

Provide ordered phases, duration (minutes/seconds), title/cues, effort/target,
repeat count, work/recovery and **recovery after last repetition** controls. Expand
the UI's repeat convenience into the existing canonical steps; preserve no-edit
imported IDs/shape and create fresh internal IDs for genuine new rows/copies.
Show expanded order and total time before save. Do not change between-only recovery
into a full-cycle repeat accidentally.

First acceptance run: selected **W4 Tuesday**, exactly 10 min easy + 3×(20 s relaxed
acceleration + 40 s very easy), then 4×5 min threshold with only three 90 s recoveries,
then 5 min very easy run-or-walk cooldown: **42:30**. No fixed pace/HR for acceleration
or recovery, no added mandatory walk. The quality work references the existing
threshold target rule. Also cover continuous Zone 2 and stride blocks with their
final recovery included; those are different shapes, not implied by this example.

Select **Athlete-confirmed Zone 2** for marked EASY work or the existing quality
category for threshold/current-10K work. Preserve the exact markers and approved
[M2.3 decisions](../m23_quality_target_admission/DECISIONS.md): explicit athlete source
selection/acceptance, 0–56 local civil days for representative 5K, approved formulas,
manual threshold ±2% only where eligible, exact rounding and immutable started targets.
No new formula, entered athlete data, silent fallback or automatic benchmark ingest.
The current Hybrid source has no scalar fallback RPE for marked quality steps;
RPE ranges in coaching notes must not enable that alternative.

Studio reviews the **authored prescription and target dependency**, not an actual
started athlete snapshot. Unconfigured targets show what input/review is required.
A local example-input panel may use shared pure calculations to explain the result,
but must label samples and never mark athlete review/confirmation or freeze complete.

Retain/import/review the **final 10,000 m** work with 33 timed preparation/cooldown
minutes. Preserve bounded distance form support for this exact source shape, not
arbitrary distance intervals/manual laps. M2.3 now locally supports explicit athlete
external-distance confirmation; it does not provide live distance or Garmin proof.
Do not retime, omit or leave a ten-week export appearing complete without this body.

### Programme arrangement, copies, progression and drafts

Support 1–10 weeks with seven days, training/rest placement and exact session
revision choice; the real ten-week source is the maximum acceptance case. Generate
keys internally. Duplicate a session/week as an explicit source copy with fresh
occurrence keys and deliberate revision use. A later session edit creates a new
immutable local revision; show **this occurrence** versus specifically selected
future occurrences and confirm the exact affected list. Never silently upgrade
all uses. Keep existing locked assessment/comparison/permission references; refuse
an invalid deletion/copy with a readable reason rather than retargeting it.

Week/day/session notes explain authored progression, W4 consolidation, W5–7 build,
W8 lower-body control and W9–10 taper. Copying notes does not calculate progression,
change loads from actuals, create adaptation permissions or reschedule an athlete.
Preserve unresolved D8 content status; a form edit is a proposed source change.

Save/open uses the existing editable JSON file mechanism. Extend the same envelope
with native exact session sources, origin/row receipts, unselected frozen revisions,
owner identities/parents/reservations, invalid field strings, unresolved intents,
programme arrangement and notes. Do not serialize valid review/approval receipts.
Open into an isolated candidate; validate bounds/digests/all references, explicitly
replace, cancel atomically, then recompute review. Show unsaved edits and saved-file
status; browser reload has no autosave/cloud recovery promise. Keep 2 MiB envelope
limit unless real ten-week measurement proves an exact bounded adjustment necessary;
never silently truncate sources/history. Old editable/review/source exports remain
separate products with explicit compatibility fixtures.

### Review and prepare, with distinct states

Use clear states: **Editable draft → locally validated revision → prepared export**.
Approval and hosted publication are later separate actions. These labels describe
local workflow, not new backend lifecycle states. A prepared export is neither an
approval nor a published catalogue programme.

Review every selected occurrence through the same exact graph/typed prescription
projection used for Programme Athlete preparation. Show full sets/reps/time, effort,
rest location, load convention, setup, coaching notes, running order/targets and
week exceptions; details include source IDs/digests, and comparison to the preceding
local version. Any unreadable/uninterpreted executable field blocks completeness.
Any edit or source/catalogue receipt change invalidates current review/preparation.

Prepare creates immutable files in the existing canonical formats: package YAML,
compiled canonical package/hash, native protocol graph JSON/hash, exact source and
catalogue evidence inventory, readable whole-programme review and validation report.
Use an extended versioned source TAR inventory/README; the inventory is a transport,
not another programme model. Exact graph count/protocol revisions must match the
package. Re-import validates the same bytes. No publish/approve/default/assignment
button and no credentials in the file or browser. A later separately authorised
operator uses existing private v1/v2 import/publication controls with these bytes.

## Recommended sequence — one dependency order within M1.1

1. **Build the local genuine-source vertical workflow and bounded catalogue operation
   package together.** Extract source policy/session-owner adapters from existing Studio;
   add the exact strength/running fields, ten-week arrangement and compatible editable
   save/open. Implement the offline operation prepare/verify/retain tooling specified
   separately. No hosted connection, migration or credential action is part of this step.
2. **Complete review/export and coverage proof.** Reuse canonical private graph/package
   inspection and native execution projection. Exercise the acceptance pair and every
   selected prescription shape. While three records are missing, save/review intent and
   report the exact blocked rows; no fabricated genuine full-session pass.
3. **Separately provision and run the reviewed three-record catalogue operation.** Exact
   target/principal/role, connection issuance if needed, manifest/seed hash, dedup/preflight
   and retention must be authorised as stated in CATALOGUE_CAPABILITY. This is an
   environment gate, not another request to choose movements or doses. No programme
   publication or athlete data is included.
4. **Import genuine receipts and obtain founder workflow acceptance.** Lee authors the
   complete strength/running pair, arranges, duplicates/edits, saves/reopens and reviews.
   Then validate all 20 strength and all 40 running graphs, 60 scheduled sessions/70 days
   and 105 exercise prescriptions without null identities, dropped fields or changes to
   selected running rules. D8 content review and a later authorised publication remain
   separate. No repeated whole-source audit is needed.

This orders required work, not new numbered milestones. Step 1 is the **single next
implementation point**. A development fixture can prove software before step 3; it
cannot be labelled genuine catalogue admission or founder acceptance.

## Acceptance and verification contract for the later implementation

| Acceptance | Evidence required |
|---|---|
| Find exact setup without technical IDs | Search/select row cards and missing/ambiguous/unpublished refusal widget/controller tests; provenance/details accessible. Three protected leads never substitute for required identities. |
| Author genuine complete strength | W1 Monday five rows exactly match selected source, preparation/finish separate, before/after/save/open field equality. Thursday includes duration/per-side/rest-range/load cases; W10 lower-bound RIR retained. |
| Author personalised running | W4 Tuesday exact 42:30/order/between-only recovery; continuous Zone 2, normal strides including final recovery, quality marker eligibility and no fabricated fallback. Review target requirements without confirming real athlete inputs. |
| Arrange/edit/copy | One and ten-week cases; rest days and stable keys; independent occurrence edits, duplicate/reorder, locked reference refusal and stale operation cancellation. Older revisions/published/started source bytes unchanged. |
| Save/reopen real draft | Fresh controller rebuild from downloaded-equivalent file; invalid draft, both session types, notes, unselected versions and history preserved. Old v1/v2/v3 compatibility, malformed/oversize/future/tamper rejection, cancel/fail atomicity. |
| Actual prescription review | Typed native execution-plan serialization equals canonical emitted graph fields before/after file round-trip; every source field rendered or visibly blocks complete review. Package-only success is insufficient. |
| Whole selected coverage | Explicit 20 strength/40 running/10 rest/105 exercise inventory; per-source supported/blocked status, including final 10K and W4/W7/W8/W9/W10 differences. Once genuine rows retained: 60/60 exact graph scope and 20/20 complete strength admission. |
| Operator capability | Disposable local DB proof of no credentials/unauthorised apply, exact insert/readback, exact replay, partial/conflict/dedup ambiguity, allocation race, transaction rollback, protected-row invariance and raw receipt tampering. No claim that local proof provisions hosted access. |
| Preparation and separation | One exact export can be revalidated/reopened; edits expire it. No approval/publication/assignment/start/completion or athlete input writes reachable from the local Studio path. |
| Founder usability | Lee completes first outcome with ordinary controls and no source/ID entry. Agent/widget evidence is not founder usability acceptance. Browser/desktop automation remains revoked; record Lee's own result later. |

For implementation, run narrow tests for changed adapters/fields/save/review first,
relevant existing Studio/private graph/running/codec regressions, and mandatory
`./tool/testing/run_phase2_consolidation_safety_gate.sh` for architecture-affecting
changes. Use disposable local DB tests only if the operator apply implementation
changes executable SQL. Get a fresh pre-edit analysis baseline; require zero errors,
zero changed-file findings and no new diagnostic identities under a newly explicit
task-scoped baseline-tolerant authorisation (362 is prior evidence, not permission).
The ready-to-run prompt supplies that bounded exception; no suppression/global reset.
Do not rerun repaired AuthGate diagnosis or unrelated broad audits/tests.

## Unlocks and exclusions

This unlocks a founder-usable route to genuine M1.1 source preparation, exact review
and later controlled publication. It does not close M1.1 until content, full admission,
authorised publication/access and genuine-programme acceptance are satisfied. D8 stays
pending; movement/dose choices already decided need no repeated approval. Father's
source/programme remains a separate genuine M1.1 requirement.

Gate A remains open for compatible held setup/acquisition/target/retry deployments,
normal private-free onboarding/access, actual programme/benchmark adoption and restart,
strength/running/History/device acceptance, governed M3 adaptations, genuine Garmin
Training + Activity access/round trip, installable distribution, movement instructions,
feedback and release sign-off. See the controlling M0–M10 rows; no new audit or build
of those dependencies is allocated here. AuthGate fixture repair is complete; final
10K support is locally verified, with genuine programme/device acceptance still open.

Exclude external-coach accounts, messaging, CRM, payments, cloud collaboration,
AI generation, broad catalogue redesign, published/started edits, automatic progression,
new runtime/parallel programme formats, hosted work or device/UI control. Future coaches
can reuse this foundation; the athlete product remains primary.
