# Sprint D1 final review and founder acceptance — 2026-10-12

**D1_ACCEPTED_FINAL_REVIEW_PASSED.** Founder accepted all four walkthrough steps
and authorised integration and normal publication of main after final review.
This acceptance is bounded to D1. Broader Programme Studio Stage 2 and Sprint C
are not closed; the four genuine-record-dependent History phone checks remain
pending. No next implementation is authorised by this checkpoint.

## Reviewed range and founder evidence

Base: `a331f52967e1887c4435cccc8f1ecfa192028cd6`. Branch:
`codex/programme-studio-stage2`. Clean managed implementation/integration worktree:
`/Users/leewebber/.codex/worktrees/programme-studio-stage2/cohort_platform`.
The complete base-to-code-HEAD diff was reviewed, including the preserved
[allocation](./ALLOCATION.md), [scope](./IMPLEMENTATION_HANDOFF.md),
[authority](./APPROVAL.md) and separate [evidence disposition](./CHANGE_DISPOSITION.md).
The three prepared documents remain byte-identical to their approved originals.

All original D1 commits are retained, followed by two focused review fixes:

1. `3933a39e95fa828bc31a64bab421d28e862a3420` — approved allocation preservation.
2. `9f7722bed691b2821e36bb0cbf8ad2655c3625e9` — synthetic authoring and exact-source review.
3. `c34c30b91b8c23e2f544f1061730ad01886134d0` — original verification/preview handoff.
4. `2d8588d660a5d186c0ae7b6b3caa741a49b5aab9` — rest-day slot recovery.
5. `8b6e4409eb32aea21730fca6af7181e02ce2562c` — malformed fixture-row refusal.

The documentation commit containing this acceptance is the sixth, final child of
that reviewed code HEAD. Resolve its exact SHA from Git; it is the publication tip.
No squash, rebase or merge is needed. Publication postflight must prove that tip
is actual remote main, six commits after the base, with zero merge commits and a
clean integration worktree. The task completion receipt reports that remote SHA.

Founder visually accepted the running `c34c30b` candidate for validation/review,
edit invalidation, refreshed diff/export/reopen and required-name error handling.
The preview's temporary manual name “Test Edit” was discarded through the existing
**Reset to imported source** control. The focused name field then displayed
**“Synthetic authoring — contracts”**, matching the selected fixture's source.
No fixture content was edited to preserve the temporary name. The local preview
at `http://127.0.0.1:4195` was stopped after acceptance. The two subsequent fixes
were verified by regressions; they are not represented as a second founder browser
walkthrough or a device validation.

## Final findings and resolved defects

The v1 writer serializes the complete unchanged canonical manifest, including
nonempty progression, adaptation, invariant, assessment, evidence and comparison
contracts. Map keys are sorted, canonical collection order retained, strings
quoted safely, and LF/final newline deterministic. Export/reopen/export is byte
idempotent; equivalent meaning preserves canonical compiled bytes and hash.
No field filtering or alternate schema/hash authority was introduced.

Source diff uses **original imported bytes**, including comments; semantic
comparison uses their original compiled canonical bytes. Canonical writer output
may normalize formatting. Successful reopen establishes the new imported reset/
comparison baseline, without promising formatting preservation.

Session choices bind exact immutable synthetic protocol, lineage and revision,
with draft/unpublished checks and no identity-by-title. Unsupported intake,
locked-contract mutations, missing/unsupported bodies and invalid references
fail closed. Exact candidate YAML is compiled, projected into existing Studio
review and recompiled at the copy boundary. Edits and failed validation clear
successful review/hash/export synchronously; invalid drafts cannot present stale
success as current. Production import/export/part reachability and forbidden
hosted/persistent paths are checked by isolation tests.

Two confirmed defects were reproduced before fixes:

- A required slot retained on a newly rest-marked day caused `RangeError` opening
  Move / reorder; with no training days the action was still enabled. The dialog
  now offers an explicit existing training destination and requires confirmation;
  without a destination moving is disabled. Cancellation leaves bytes unchanged;
  keys/progression survive a confirmed move. Remaining invalid slots still fail
  validation. Two widget regressions cover both cases.
- An additional malformed fixture protocol tuple was silently filtered, allowing
  successful validation of incomplete source evidence. Every tuple must now match
  the declared columns; mismatch reports `fixture_source_unsupported` and prevents
  successful review/export. A controller regression reproduces the former pass.

The fixes touch only the D1 screen/controller and their tests. Shared compiler,
schema/hash code, existing Studio components, dependencies, published artifacts,
all original real sources, v1/v2 goldens, production/release entries and migrations
are unchanged. Of all 2,587 pre-existing tracked files, only the intentional
`CURRENT_CHECKPOINT.md` pointer differs; the other 2,586 remain byte-identical.

## Fresh final validation

Exact commands, reviewed Dart hashes and results:
[FINAL_REVIEW_VERIFICATION.json](./FINAL_REVIEW_VERIFICATION.json).

| Check | Current result |
|---|---|
| Studio and root authored-package regressions | 117 passed, including three new defect regressions |
| Isolated canonical-package suite | 41 passed; v1/v2 goldens, advisory/B3 mapping and retained-publication compatibility |
| All eight D1 Dart files: scoped analysis | Zero diagnostics |
| Full analysis before/after review fixes | Identical 367 inherited diagnostics: zero errors, 110 warnings, 257 info; exit 1 |
| Six mandatory safety groups | 71 / 17 / 62 / 8 / 1 / 12 passed; zero failed groups |
| Protected source/artifacts | Compiler/schema/hash, published artifacts and goldens byte-identical |
| Diff, documentation links and checkout preservation | Whitespace checks pass; 178 local links resolve; original inventory matches |

Full analysis is **not green**. Every diagnostic line matches both the fresh
pre-fix measurement and the October 10 baseline; there is no baseline difference
to explain, no new diagnostic, suppression or borrowed analysis exception.
The safety script/groups are unchanged. A shell wrapper adds `--no-pub` to each
Flutter test using cached dependencies; the initial resolution attempt was stopped
before tests. All six actual groups then completed successfully. Raw logs and
preservation manifests stay outside Git under `/private/tmp/cohort-d1-*`.

## Integration and protected original checkout

Authorised `git fetch origin` succeeded and actual `origin/main` remains exactly
the expected base `a331f52967e1887c4435cccc8f1ecfa192028cd6`: no remote advancement,
conflict or changed scope. Reviewed code was five commits ahead, zero behind,
with zero merges. The final acceptance commit makes the authorised range six.

Publish from this clean worktree with only:

```bash
git -c push.followTags=false push origin HEAD:refs/heads/main
git fetch origin
```

Require actual remote main = integration HEAD, divergence 0/0 and clean worktree.
Do not force-push, publish the feature branch/tags or advance local `main`.

The original `/Users/leewebber/Developer/cohort_platform` stays on local `main`
at the base. Its 95 outstanding paths, all contents/status, index and `.temp`
are preserved. No switch/reset/stash/clean, bulk copy, evidence staging or
sanitation occurred. Fetch changes the shared `origin/main` tracking ref; normal
publication advances remote main while **local main remains six commits behind**.
The dirty evidence is excluded from this integration, including its newer
security/deployment/device checkpoint pointer. Disposition remains a separate task.

No hosted project operation, migration, device build/install, real programme
content, profile authoring, athlete write, production wiring, running-policy editor
or Stage 3 publication/import UI was introduced.

## Recommended next bounded conversation

Recommend **allocate D2: local synthetic protocol/session-body authoring**, the
remaining source lane named by [Programme Studio §§3,5](../../architecture/Programme_Studio_v1.md)
and [launch-library Sprint D](../../architecture/Launch_Programme_Library_v1.md).
D1 covers package metadata/schedule, not protocol authoring YAML. This is a
recommendation for a fresh explicit allocation; no D2 work has begun.

Start with one existing strength-block representation and synthetic session:
existing session/block titles and notes, ordered exercise rows, and the already
supported sets/reps/rest/RPE/load fields only. Use caller-supplied immutable
synthetic Exercise Definitions; emit the existing Founder protocol authoring YAML,
validate/dry-run through existing pure importer paths with in-memory ports, and
review the exact candidate via Studio. New candidate revisions must be explicit;
never mutate D1's frozen catalogue or an existing published revision in place.
The next allocation must first verify the exact supported grammar and a local
source-to-review bridge, and set a strict field allowlist and revision boundary.

Prerequisites: founder approval of that narrower D2 allocation and its bounded C
interpretation (D1 acceptance does not grant it), confirmed existing canonical
exercise identity resolution and source-faithful dry-run compatibility, synthetic
fixture/revision and fail-closed unsupported-field contracts, and an isolated
worktree from then-current remote main. Require deterministic round trips, stale
review clearing, importer/Studio/isolation regressions, zero new/changed-file
analysis issues, six safety groups and separate founder visual review.
Exclude real prescriptions/content, exercise creation/name-based mapping, v2
running policies, other block formats, profiles/assessments, hosted writes/import/
publication, athlete state and production wiring. Broader C/device gates remain
open; commercial content and Stage 3 still require separate authority.
