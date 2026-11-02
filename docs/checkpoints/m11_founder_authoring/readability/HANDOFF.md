# M1.1 readability and structured prescription presentation

2026-11-02. Base/fresh published main before work:
`906d6b6dfad635e87d37a99ee61059ec07279ef5`.
**LOCAL_IMPLEMENTATION_VERIFIED; FOUNDER_ACCEPTANCE_PENDING; D8_PENDING; GATE_A_OPEN.**

## Visible changes

The founder entry now uses a scoped light builder theme with Cohort's dark toolbar
and olive identity. The cause was a dark app theme surrounding hard-coded light
builder surfaces. Surface/foreground roles now cover page, cards, fields, labels,
values, menus, buttons, warnings and dialogs. Dark toolbar actions have their own
light foreground, including disabled actions. The production app's dark theme and
older standalone entries are unchanged. Text and essential boundary pairs are
measured using relative luminance, including interactive/disabled states.

Inline and modal previews share `StructuredPrescriptionPreview`. Existing typed
`StrengthExercisePrescription` and `RunningWorkoutCodec` decode the exact selected
source, including editable null-ID intent; no compiler-readable prose is split or
interpreted. Strength shows ordered preparation, one card per movement, typed dose,
load/rest/RIR, per-side/per-dumbbell conventions and expandable source setup/tempo/cues.
A duration already containing its authored side convention is not given a second
formatter-added side suffix. Free-text coaching cues remain intact in disclosure;
source-authored overlap/conflicts are not arbitrarily removed.

Running presentation groups only contiguous typed work/recovery cycles with equal
roles, durations, targets, labels and notes, excluding identity from equality.
Every original step remains in the view group's ordered list. Different cues/targets
stop grouping. Counts and final-recovery wording come from that exact list. W4 is
10 min easy, three 20 sec acceleration/40 sec recovery cycles (recovery after the
last), four 5 min threshold repetitions/three 90 sec recoveries (between only), and
5 min cooldown: 42:30. No personal pace/BPM is invented.

The repeated running paragraph came from the bootstrap aliasing workout.notes into
block.coach_notes, and the old preview rendering both. The renderer reads that
workout-level channel once; separately edited block notes remain visible. Header,
block and workout title roles are presented once instead of repeating a flat review.
Legitimate repeated execution steps are retained, not text-deduplicated.

Exact retained preparation/operational paragraphs have an explicit presentation-only
source-channel map. This gives short ordered preparation and preserves meaningful
coaching clauses while routing the original approval/provenance commentary to existing
Advanced source inspection and a concise coach-only readiness panel. Known authored
step-note prefixes have exact source mappings to their useful effort guidance.
Unknown/edited notes pass through unchanged: no keyword deletion or guessing from
step names occurs. These mappings never write source/backup/export fields. The full
original source, including evidence and comments, remains available in Advanced tools.

Common strength fields stay together. Exact rest has one field; genuine ranges show
two bounds. Show rest range bounds is a view-only disclosure until a bound is edited.
Alternate reps/RIR modes and detailed session/source guidance are collapsed. Values,
units, validation, source capabilities and immutable revision/occurrence rules remain.
The reading width is bounded; modal Close preview stays outside the scrollable body.

## W1 summary investigation

Fresh selected `RUNNING_BODIES.json` and actual `GenuineWorkspace.selected()` sources
all contain exactly one 1,500-second work step for:

| Session | Selected body |
|---|---|
| W1 Tuesday | 25 min continuous; first 5 min particularly gentle; confirmed Zone 2 |
| W1 Wednesday | Same one-step 25 min body |
| W1 Friday | Same one-step 25 min body |

The selected SOURCE.json, retained general source and original 2026-10-28 CALENDAR.json
agree on these steps. The October 30 clarification changes four later Tuesdays, not
these W1 runs. This is retained source content in the intended current seed, not a
25-minute summary invented by the renderer. Friday's title says "Easy run / strides"
but its source body contains no strides; that source title/body inconsistency is
flagged for D8 without adding or removing coaching.

Screenshots were referenced but no image attachments were available in this turn.
The actual source/code investigation is therefore distinguished from screenshot
inspection. Without Lee's specific open backup/runtime state, unsaved local changes
or stale selection in that particular view cannot be excluded. The fresh seed does
reproduce the reported summaries. Retained source is not blanket coaching approval
or Lee's separate return-to-running prescription.

## Verification, authority and limits

VERIFICATION.json records focused regressions, actual JSON/TAR readback hashes,
analysis comparison, actual colour pairs, preview HTTP verification and preservation.
No browser/desktop control, screenshot capture, native rendered visual verification
or founder usability acceptance is claimed from widget/layout tests. A manual check
in Lee's browser remains required. There is no new programme feature, coaching change,
model/schema/format change, hosted operation, catalogue apply, programme publication,
assignment or athlete-data action.

Same checkout reused; normal non-force main-only Git publication follows fresh
ancestry/equality checks. Measured older checkouts, outstanding files, indices, HEADs,
refs/FETCH_HEAD, explicit .env/.temp files and bounded bundle inventory are preserved.
Prior previews are left untouched so their in-memory edits are not disturbed.

No autosave/reload recovery is added. Download backup/Open backup remain the durable
editable workflow. The same three missing catalogue setups still block 28 occurrences
and all 20 complete strength sessions. The renderer never invents an admissible
identity. Prepared export and actual programme publication remain separate.

Next single point: **Lee manually checks contrast and the structured coach/athlete
presentation, then records acceptance or concrete remaining friction.** D8 and Gate A
remain open. W1 source suitability/title reconciliation is a separate content decision.
