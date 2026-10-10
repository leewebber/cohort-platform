# Sprint D1 implementation handoff — 2026-10-10

**LOCALLY_VERIFIED_AWAITING_FOUNDER_VISUAL_REVIEW.** No integration or publication.
Implementation commit: `9f7722bed691b2821e36bb0cbf8ad2655c3625e9`, preceded by
allocation preservation `3933a39e95fa828bc31a64bab421d28e862a3420`. The final checkpoint
commit contains this handoff and a checkpoint pointer; it adds no product code.

Branch `codex/programme-studio-stage2`; managed worktree:
`/Users/leewebber/.codex/worktrees/programme-studio-stage2/cohort_platform`.
Exact base `a331f52967e1887c4435cccc8f1ecfa192028cd6`. [Founder authority](./APPROVAL.md),
[approved allocation](./ALLOCATION.md), [original implementation scope](./IMPLEMENTATION_HANDOFF.md)
and the separate [change-disposition proposal](./CHANGE_DISPOSITION.md) are retained.
The dated proposed/no-commit wording in those preparation records is superseded
only by the direct founder authority described in APPROVAL.md.

## Delivered workflow

Dedicated `lib/main_programme_studio_authoring_preview.dart` initializes from a
valid synthetic canonical source, with two unpublished exact fixture session
revisions and two source bundles (empty and nonempty protected contracts).
Everything is transient. Reloading the page discards edits. No source is loaded
from derived Studio JSON, a live registry or a hosted system.

Edit programme name, description, coaching intent, primary goal and declared
sessions/week. Edit existing week/day titles and coach notes; change training/rest
placement. Add explicitly keyed required slots, remove with confirmation, move
between existing training days, and choose explicit order, exact fixture revision,
time of day, display title and coach note. Revision changes require confirmation.
Stable keys and locked completion/progression templates remain intact. Broken
contracts remain errors; they are never silently rewritten to fit a schedule.

Validate & refresh review compiles the **exact deterministic YAML** subsequently
shown/copied, checks exact protocol/lineage/revision/unpublished fixture evidence,
and projects those same bytes through the existing ProgrammeReviewProjector and
ProgrammeStudioScreen. Coach Review, Athlete Preview, Quality Gate and Technical
Integrity remain the existing read-only review surfaces. Copy independently
recompiles/checks canonical bytes/hash and current revision before exporting.

Every edit synchronously clears validation, hash, review and export. Invalid
source/drafts display path/code/messages and cannot show an old successful review
or export as current. Unsupported schema/fields/shapes, foreign fixture identities,
changed locked contracts, absent or unsupported prescription sources and wrong
revision evidence fail closed. v2 intake is explicitly refused by D1; existing v2
review is untouched. Optional semantics are locked, not extended as a product.

The textual baseline is **the exact originally imported source bytes**, including
comments. A successful Reopen establishes that imported source as the new reset/
comparison baseline. The line diff aligns unchanged lines and exposes normalized
formatting separately from authored edits. Semantic comparison uses original
compiled canonical bytes/hash. No formatting-preservation promise is made.
The writer serializes every canonical v1 field, sorts map keys, preserves canonical
collection order, safely quotes strings and emits LF with one final newline.
Export/reopen/export is byte-idempotent; equivalent meaning keeps canonical bytes
and hash exactly. Shared compiler, schema and hash code are unchanged.

## Fresh verification

Machine-readable commands/results and implementation hashes: [VERIFICATION.json](./VERIFICATION.json).
Checks ran against the code subsequently committed as `9f7722b`; no code changed
after those successful checks. Dependency setup was offline, including nested Dart
package dev dependencies. No dependency files or lockfiles changed.

| Check | Result |
|---|---|
| All Studio and root authored-package regressions | 114 passed |
| Isolated canonical-package tests | 41 passed; v1/v2 goldens, advisory-scope/B3 mapping and retained payload compatibility unchanged |
| Every new Dart file: scoped Flutter analysis | Zero diagnostics |
| Fresh pre-edit and final full repository analysis | Identical 367 diagnostics: 110 warnings, 257 info, zero errors; exit 1 both times |
| Mandatory consolidation safety gate | All six groups passed (71 / 17 / 62 / 8 / 1 / 12 tests) |
| Diff and checkpoint links | Checked before final checkpoint commit |
| Protected tracked source/artifacts | All 2,587 pre-existing tracked files byte-identical before the intentional checkpoint pointer edit |

Full repository analysis is **not green**. No consumed exception was reused,
warning suppressed, unrelated warning repaired or full-analysis pass inferred
from the scoped result. The unchanged inherited diagnostics remain disclosed at
the founder review boundary; the latest task requires zero changed-file diagnostics.

Writer/controller tests cover complete protected-contract round trips, quoting,
Unicode, semantic equivalence, exact refs, source/body failures, invalid orders/
counts/targets and stale result clearing. Widget tests exercise copy bytes, reset,
malformed reopen, revision cancellation/confirmation, reordering/removal/addition
and 390×844 with 200% text. Isolation checks walk import/export/part reachability
and prohibit production/hosted/persistent consumers. The review is mounted in a
scrollable D1 viewport to accommodate the existing Studio header at narrow widths
and large text without modifying existing Studio components.

Raw test/build logs remain in `/private/tmp/cohort-d1-*`; no secret/configuration or
existing dirty deployment/device evidence was copied into product code or committed.

## Chrome walkthrough and founder review

Preview remains running at **http://127.0.0.1:4195**. Established launch procedure,
from this managed worktree (the port was verified free before launch):

```bash
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 4195 --no-pub -t lib/main_programme_studio_authoring_preview.dart
```

The agent inspected the rendered Chrome workflow using native accessibility and
screenshots: edited metadata, observed successful review disappear on edit,
cleared a required name, saw `programme.name / type_error` and disabled export,
reset and refreshed review, inspected/copied complete YAML, pasted/reopened those
bytes, selected and confirmed exact revision 2, reordered with stable keys,
removed a slot, added `SYN-VISUAL-SLOT`, and refreshed the actual Studio from that
candidate. Source comparison reported original-byte normalization and changed
compiled meaning; Technical Integrity was reachable. After inspection the page
was reloaded to its **original synthetic fixture, initially unvalidated**, ready
for the founder. Desktop rendering was inspected in Chrome; narrow/200% text
coverage is automated widget evidence, not a phone or browser-device claim.

Founder walkthrough:

1. Validate & refresh review; inspect Coach Review and the immutable fixture body.
2. Edit metadata; observe review/export invalidation, then refresh.
3. Scroll the author pane to schedule; choose an exact revision, move/reorder or
   add an explicitly keyed slot, and inspect source comparison before refreshing.
4. Export/Copy YAML; Reopen YAML and paste it; validate again. Formatting may
   normalize, while equivalent compiled meaning/hash stays fixed.
5. Clear the required name or remove a contract-referenced slot; validate and
   inspect actionable errors. Reset to imported source and refresh to recover.
6. Inspect Athlete Preview, Quality Gate and Technical Integrity, then review
   this exact implementation commit. Founder visual approval is still pending.

After explicit visual approval, stop the preview and record that approval/state.
Integration needs separate authority. This implementation does not declare D1
accepted, all Stage 2 complete, broader Sprint C complete, or the four genuine-
record-dependent History phone checks passed.

## Preserved boundaries and checkout

No protocol-body or running-policy authoring, real programme/profile content,
publication/import, athlete writes, persistence, production wiring, migrations,
release guards, hosted contact, fetch/push or device build/install. Existing
published artifacts, authored prescription, progression, adaptation, invariants,
assessments, evidence and comparison contracts and v1/v2 hashes remain protected.

The original main checkout remains at `a331f52967e1887c4435cccc8f1ecfa192028cd6`:
95 outstanding paths (four tracked, 91 untracked), all original bytes/status
unchanged, zero staged paths. Its `.temp` remains unchanged (zero regular files at
both inventories). No stash/reset/clean/bulk copy or evidence sanitation occurred.
The original evidence-disposition proposal remains a separate task.
