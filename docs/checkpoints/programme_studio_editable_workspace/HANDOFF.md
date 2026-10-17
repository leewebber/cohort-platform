# Portable editable workspace — continuation handoff

2026-10-17. Implemented under founder's explicit continued-build and normal main-push
authority; agent verification is not founder acceptance. Base:
`2d97daf71e31c4691eba9cf85e731b4a1b3c2e33`.
Branch `codex/studio-editable-workspace` in
`/Users/leewebber/.codex/worktrees/studio-editable-workspace/cohort_platform`.
Implementation commit: `6cca4282f3e25d2a4e421e03d580124067e62cac`. Evidence checkpoint is the following
linear documentation commit; resolve the publication tip from main/postflight evidence.
See [approved scope](SCOPE.md), [format/limits](FORMAT.md),
[verification](VERIFICATION.json) and [preservation](PRESERVATION.json).

## Delivered behaviour

Save editable workspace downloads local JSON containing programme edits/selections,
both fixed session owners, all frozen private/available versions, active form drafts
(including invalid values), and revision reservations/abandoned numbers. Open editable
workspace uses a file picker, reconstructs separately, then asks explicitly to replace
current work. Cancel/fail/stale confirmation changes neither current work nor receipts.
After opening, editing continues in the same forms; saving a version still does not
select it in a programme. Reviews must be recomputed. Three products stay distinct:
canonical source files for tools, complete read-only review, editable workspace for editing.

The notice and save-state labels explain no browser autosave/cloud backup; file retention
is the author's responsibility. Read-only export never silently becomes editable.
See FORMAT for intentionally excluded transient state and fixed synthetic limits.

## Review and defect correction

Reviewed exact source/profile/owner bindings, independent immutable roots/descendants,
private/admitted state, all-slot references, untrusted bounds, atomic candidate transfer,
reset/disposal/notification freshness and download consumption. A reproduction proved
rejected wrapper text could previously be revalidated/frozen after `reopen` refused it.
Validation now refuses retained rejected text until supported input is reopened or the
draft reset/discarded. The failing-before and passing-after regressions are retained in
external evidence. Reopen also refuses missing standalone root availability. Reset clears
obsolete workspace error UI. Shared compiler/schema/hash/resolver/revision allocator,
writers, fixed fixtures, published artifacts, golden files and safety definitions unchanged.

## Current verification

290 Studio tests pass, including 38 new workspace tests and standalone D1/D2,
composition, same-title/version, old v1/v2 review transport, source download and tamper
regressions. All six unchanged safety groups pass. 14 changed/new Dart paths have zero
diagnostics. Fresh full analysis remains NON-GREEN at exactly 367 inherited diagnostic
identities (110 warnings, 257 info, zero errors), no added or removed identities.
Accepted 41 canonical-package test evidence is reused only after its log hash and every
package byte are reverified unchanged; it was not rerun. Diff/local links/protected files
and all ten older inventories checked. Raw logs/inventories:
`/private/tmp/cohort-studio-editable-workspace`.

## Actual Chrome exercise (agent)

At [local preview](http://127.0.0.1:4197/), entered `bad reps` in A's first exercise,
saved via the editor, opened the downloaded file and cancelled replacement, then reopened
and confirmed replacement. The invalid input survived; corrected to 6 and saved A2
without changing A1's programme use. Explicitly authored B1 using the existing fixture
choice (3 sets, 8 reps), saved the workspace, reloaded the page and opened that file:
three frozen versions, two private, no draft; programme still used A1. Edited restored B1
to 9 reps, saved B2 and downloaded again. Independent extraction checks prove old A1,
A2 and B1 source bytes stayed equal. All four versions survived; only A1 was admitted.
Opening a read-only review file via the editable opener was refused and both histories
remained. [Candidate preview](chrome-candidate.jpg), [refusal](chrome-refused-review.jpg).

These browser checks preceded the final rejected-source and reset-error fixes; focused
regressions and the full final suite cover those fixes. Final bundle hot-recompiled.
No founder acceptance is inferred. Preview entry:
`lib/main_programme_studio_composition_preview.dart`, no hosted services/configuration.

## Remaining roadmap work

[Studio §§3/5](../../architecture/Programme_Studio_v1.md) requires controlled canonical
source authoring; bounded synthetic file output and editable local restoration now exist.
This does not establish general source intake, real programme authoring coverage or Stage
2 closure. [Launch library §10](../../architecture/Launch_Programme_Library_v1.md) and
[product plan §4](../../planning/Athlete_Product_Completion_Plan_v1.md) still require actual
complete progression/policies/canonical identities, editorial/coaching approval, technical
compilation and real-world quality gates. Editors for every locked declaration are not
invented closure requirements. Wider fixture/lineage/profile expansion is optional and
unjustified without a use case. Broader Stage 2/Sprint C and four suitable-record-dependent
phone checks remain open.

Recommended next practical task: establish the first approved source-backed authoring
use case and audit its exact source/schedule/representation gaps against these existing
components, then deliver the smallest supported end-to-end authoring path. Actual content
approval remains separate: do not invent real prescriptions or publish them. No hosted
mutation, real publication, athlete-data changes, payments, migrations or device work.
No further milestone is implemented by this handoff.
