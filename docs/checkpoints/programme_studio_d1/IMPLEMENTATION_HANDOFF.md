# Future founder implementation prompt

**Not current authority.** This is ready to use only after the founder adopts the allocation in `ALLOCATION.md`. Preparation on 2026-10-10 did not authorise implementation, worktree creation, tests, preview, commits or builds.

---

Continue Cohort Platform at `/Users/leewebber/Developer/cohort_platform`.

I accept the already reviewed bounded Sprint C foundation as satisfying the roadmap's “C accepted” dependency **for D1 only**. This does not close broader C or authorise deferred tracking/profile/storage/v3/calculation work. I authorise local implementation and verification of **Sprint D1 / Programme Studio Stage 2: synthetic Plan Package v1 metadata and schedule authoring, deterministic YAML export, and existing Studio review**, exactly as the attached `ALLOCATION.md` defines.

Read AGENTS.md, CURRENT_CHECKPOINT.md, the device validation closeout/handoff, binding launch-library/Studio contracts and revised Sprint C acceptance evidence. Expected main/HEAD/cached origin/main is `a331f52967e1887c4435cccc8f1ecfa192028cd6`; verify it locally. Cached origin is not freshly fetched.

Preserve all 95 outstanding files (four tracked modifications, 91 untracked), the index and repository `.temp`. Use the saved inspection manifest or create a fresh external hash inventory before setup. No reset, clean, stash, bulk staging or copy-all of dirty files. Inspect attached worktrees and use a suitable isolated clean checkout at the exact base if one exists; otherwise create a managed worktree at that exact ref and a dedicated `codex/programme-studio-stage2` branch. Work only in the returned workspace. Recheck the original checkout and hashes afterward. Do not move main, fetch or contact any hosted environment.

Implement the exact field allowlist and workflow in `ALLOCATION.md`:

- Dedicated non-production authoring preview, synthetic fixture catalogue only. Preserve existing Studio/B4 defaults and all real programme review.
- Initialise from valid canonical source YAML, not derived Studio JSON. Restrict intake to allowlisted synthetic lineage/version/session identities. Reopen exported candidates only in the same synthetic identity scope. Reject v2 authoring explicitly and preserve its existing read-only review.
- Metadata: name/description/coaching intent/primary goal/declared sessions per week. Existing week/day titles and coach notes; training/rest transitions. Add/remove/move required slots in existing weeks/days with explicit stable keys/order, fixture session selection, time-of-day/display-title/coach-note fields.
- Preserve locked phases/identity/duration/optional semantics/session catalogue/progression/adaptation/invariant/assessment/evidence/comparison contracts. New slots reuse a fixture's exact required completion/progression template. No inferred coaching content or identity matching by label.
- Pure complete v1 YAML writer with deterministic keys/order/quoting/UTF-8/LF. Use the unchanged shared compiler before and after export. Re-export and reopen must be byte-idempotent; untouched canonical bytes/hashes must match exactly. No package schema/hash/golden modification.
- Path/code/actionable validation; unsupported fields/schema/source shapes, bad identities/orders/refs and unsupported prescriptions fail closed. Resolve session references from exact local fixture protocol/lineage/revision evidence. No hosted fallback. Compiler validity alone cannot attest a referenced protocol.
- Review the exact exported YAML through existing ProgrammeReviewProjector and Studio Coach Review, Athlete Preview, Quality Gate and Technical Integrity. No current-valid hash/export can survive a subsequent edit or failure. Explicit Export/Copy YAML, source and semantic diffs, reset/cancel, no autosave/parallel document store. No persistent review acceptance record is needed for D1; record founder approval in the handoff.

Expected implementation files are the new `lib/features/programme_studio/authoring/` controller, YAML writer, screen and fixture source bundles, plus `lib/main_programme_studio_authoring_preview.dart`, targeted Studio tests and an implementation handoff. Reuse existing source/projector/review APIs. Keep shared compiler, all real sources/publication artifacts, library dependencies, RPCs, SQL/migrations, production navigation and release guards unchanged. Return a bounded decision if unexpectedly needed; do not widen the slice silently.

Run meaningful writer/controller/widget/isolation regressions, all existing Studio compatibility tests, root authored-package tests and isolated canonical-package tests. Planned commands, run **in the isolated worktree** (not run by the allocation task):

```bash
flutter --suppress-analytics test --no-pub test/programme_studio/ test/authored_plan_package/
```

Run the package's own tests from its directory rather than loading them with Flutter tests at the app root:

```bash
cd <implementation-workspace>/packages/cohort_plan_package
dart --suppress-analytics test
```

Return to the isolated worktree root. Analyse every changed/new Dart file with the relevant Flutter/Dart tool and require zero diagnostics. Record a fresh full `flutter analyze` measurement before edits and a final result. Do not reuse consumed baseline exceptions, suppress diagnostics or claim full analysis success from a scoped pass. If unresolved pre-existing warnings prevent the required full-analysis acceptance, report exact counts and ask for task-scoped disposition at the appropriate review boundary; do not fix unrelated warnings.

```bash
FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh
git diff --check
```

Require all six safety groups. Preserve v1/v2 goldens, v2 advisory-overlap/B3 mapping compatibility and retained-publication payload tests. Check import/export/part reachability and absence of hosted/persistent authority. No routine DB gate/reset is needed unless an independently approved scope change introduces concrete SQL risk. Broaden Flutter testing only for demonstrated shared-path risk. Record exact commands/results, tested HEAD or uncommitted diff identity, and inherited versus fresh evidence honestly.

After local checks, prepare a **local synthetic Chrome preview** for founder visual review. No device build/install is required or authorised. Suggested isolated entry command, with a free verified local port:

```bash
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 4195 -t lib/main_programme_studio_authoring_preview.dart
```

Founder walkthrough: edit metadata, exact fixture selection, move/add/remove slot, inspect prescription, validate/export/reopen, invalid ref/order, cancel/reset and edit-after-review. Verify desktop keyboard/focus/labels, 390×844 and 200% text. Keep technical hashes in Technical Integrity. Obtain visual approval of exact source/diff identity, stop preview and record that state. If approval is unavailable, report locally verified implementation awaiting visual review; do not claim Stage 2 accepted.

Pending genuine History phone cases stay pending. Database ledger/postcheck evidence, local test evidence and device evidence remain separate. No manufactured hosted records, publication, private Bali edits, commercial content, profile authoring/storage/v3/arithmetic, protocol-body authoring, EX-* identities, running policy/bands, assignments/pins, athlete writes, default-grant recurrence, unrelated feature, production wiring, release guards, phone build/install or hosted contact.

Do not stage or commit the existing 95 files. Their separate disposition proposal is not commit authority. This prompt authorises local implementation/checks/preview only; no commit, integration, push or publication. Finish with the exact scope/diff, fresh verification, founder visual status, source/worktree preservation and separately gated next step.
