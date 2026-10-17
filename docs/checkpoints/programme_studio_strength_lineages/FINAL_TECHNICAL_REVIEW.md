# Two-lineage technical review and qualified publication authority

2026-10-17 (Asia/Makassar). **TECHNICALLY_REVIEWED_QUALIFIED_PUBLICATION_AUTHORISED**.
This record supersedes the dated stop in [the implementation handoff](./HANDOFF.md)
for this bounded code publication only. [Fresh verification](./FINAL_REVIEW_VERIFICATION.json)
retains the measurements. Broader Programme Studio Stage 2/Sprint C and four
record-dependent phone checks remain open. **NEXT_IMPLEMENTATION_AUTHORISED=false**.

## Founder feedback and authority

The founder said: “I think that works, but honestly I have no idea; this is not
user friendly. Let’s just push through.”

- Founder tentatively observed functionality.
- Detailed manual outcomes were not confidently established.
- Full visual/usability acceptance is **NOT granted**.
- The workflow was reported as confusing and not user friendly.
- Founder explicitly authorises final technical review, scoped confirmed-defect
  fixes and normal main publication if all technical gates pass, without another
  manual walkthrough now. This is not “all founder checks passed.”

Automated technical evidence does not fill the manual evidence gap. The usability
concern remains unresolved and is a limitation of this published synthetic tool.

The [binding Studio contract](../../architecture/Programme_Studio_v1.md), §9,
requires visual founder review before **Sprint A** completion. Sprint A/Stage 1
already has its separate accepted record. No instruction was found that makes
confident visual acceptance mandatory for Git integration of this bounded Stage 2
extension. The launch-library [quality gate](../../architecture/Launch_Programme_Library_v1.md),
§§8/10, requires human coaching and production/device checks for real programme
launch/publication; it is not satisfied or invoked by this synthetic code publication.
The current explicit authority supersedes this slice's earlier review pause.

## Complete review and confirmed fix

Reviewed the entire baseline-to-implementation diff, allocation/authority/evidence,
all changed components, tests and the D1/D2/composition acceptance contracts.

One confirmed defect group: admission and selection returned success after a
notification **queued** workspace reset or disposal. Four new B regressions failed
before the fix (actual true, expected false). Composition now settles notification
microtasks before its final disposed/owning-workspace check. The immutable append
still remains valid when a newer operation starts in the same workspace; existing
regressions prove its busy/receipt state is preserved. No new authorable scope was
added. Fix: `2c4e84906af2190185a52324b196cb061f01cdf9`.

Other reviewed boundaries pass the automated checks:

- B requires explicit empty-root author input; failed/cancelled current creation
  freezes nothing. Roots and descendant reservations/no-op/abandoned-number rules
  remain independent. A's original source bytes and initial slot are retained.
- Full protocol/lineage/revision tuples drive cross-owner operations, picker values,
  keys, confirmations, status and transport. Same-title A/B R1 and R2 stay distinct.
  Integer compatibility methods remain scoped to A or one owning catalogue.
- Live admission requires the exact frozen object retained by the identified owner,
  recompiles its source and compares tuple/digest/meaning/exercise-version bindings
  and the actual deep compiler-profile fingerprint. Foreign/conflicting/unsupported
  sources and altered definitions/mapping provenance are refused atomically.
  Exact repeat admission is idempotent and does not select.
- Confirmed selection changes the explicit required slot. Every slot/body is checked
  in actual Studio review. Both owners invalidate joint receipts; pending work,
  callbacks, late failures, copy consumption, reset and disposal cannot reuse stale
  joint success. Shared exercise fixtures grant no comparison authority.
- Complete deterministic transport-v2 contains exactly all declared admitted revisions,
  including unselected revisions and both roots, excluding drafts/unadmitted entries.
  Original A-only transport-v1 stays byte-identical and reopens unchanged. These local
  transport versions are unrelated to Plan Package v2.
- Reopen recomputes claims and refuses tampering, duplicate/missing/foreign identities,
  altered profiles and unsupported fields. It preserves known A R1 bytes, validates B
  under the fixed policy, and remains separate/read-only. Re-export is deterministic;
  live owners, reservations, references and history are not hydrated or replaced.
  Consistent source digests do not prove historical freezing or founder approval.

## Fresh technical evidence and protection

- **381 affected tests pass**, including four new queued-completion regressions;
  **93 focused composition/lineage/widget tests** pass; **41 canonical-package tests** pass.
- All **six unchanged safety groups** pass, zero failed. A temporary external wrapper
  adds `--no-pub` and suppresses analytics, using cached dependencies; the gate and its
  group definitions are unchanged.
- All **16 changed/new Dart files** have zero diagnostics. Fresh full analysis before
  and after the fix matches every inherited diagnostic line: **367 diagnostics —
  110 warnings, 257 info, zero errors**, exit 1/non-green. No additions, removals,
  suppressions, dependency or analysis-configuration changes.
- Of 2,659 baseline Git entries, only the 15 previously approved existing paths differ;
  the other 2,644 Git objects are identical. The fix touches one already approved
  controller and the new lineage regression file. Shared compiler/schema/hash,
  canonical resolver/revision allocator, source writers, original A fixtures,
  published artifacts, v1/v2 goldens, dependencies, migrations, release guards and
  production entries remain unchanged. Nine inherited skip-worktree `.temp` entries
  are absent in the clean checkout; their Git objects/index entries are unchanged.
- Full-range whitespace and local checkpoint-link checks pass. Before/after inventories
  of all five older checkouts match exactly: file contents, HEADs, branches, indices,
  dirty statuses and `.temp`. Original main remains `a331f52967e1887c4435cccc8f1ecfa192028cd6`
  with exactly 95 outstanding paths; the implementation checkout remains at
  `b81b7e8f79cd77f00353b3c6ea6134eed20d1810`.
- Only the identified task preview was stopped; port 4195 has no listener. No new
  manual visual acceptance is claimed. No hosted project, migration, real-content,
  production/athlete wiring or device operation occurred.

## Linear publication preflight

Review/integration worktree:
`/Users/leewebber/.codex/worktrees/studio-lineages-final-review/cohort_platform`,
branch `codex/studio-strength-lineages-review`. All five older checkouts are preserved.

Fresh main-only fetch verifies `github.com/leewebber/cohort-platform.git` main is the
exact base `c75d38358a8a8bc37f6d0444f206b1bffcb81c29`. No drift/conflict/scope change.
The preserved commits are:

1. `3246511945890c65fd5d05143832de741fc8bb0c` — approved allocation.
2. `1db2eabae086fdfbfd2bc9c1a7fc9a088602ed69` — implementation/regressions.
3. `b81b7e8f79cd77f00353b3c6ea6134eed20d1810` — original verification/handoff.
4. `2c4e84906af2190185a52324b196cb061f01cdf9` — confirmed review fix/regressions.
5. The child documentation commit introducing this record and final verification.
   Resolve its SHA with `git log --diff-filter=A --format=%H -- docs/checkpoints/programme_studio_strength_lineages/FINAL_TECHNICAL_REVIEW.md`.

Publish only the clean five-commit linear range normally using
`git -c push.followTags=false push origin HEAD:refs/heads/main`; no force, merges,
rebase, squash, tags or feature-branch publication. Fetch main afterward and prove
remote main = integration HEAD, divergence 0/0 and clean integration state. The
separate local publication receipt and final task response record the actual SHA;
this immutable preflight record does not claim the push has already happened.

## Stage 2 gaps and recommended next task

The [roadmap](../../architecture/Launch_Programme_Library_v1.md), §14, calls for a
controlled structured-authoring workflow; [Studio](../../architecture/Programme_Studio_v1.md),
§§3/5, requires generating the existing canonical Plan Package/protocol source lanes.
D1/D2/composition and this extension prove bounded synthetic portions of those lanes,
not a complete practical authoring product. The founder-reported usability gap is
real. Intended programme creation/intake, schedule and prescription representation
coverage for the first real authoring use case still needs explicit allocation and
acceptance. Broader Stage 2 closure has no enumerated universal feature checklist.
Locked-contract editing, other schedule/representation coverage and editable archive
restoration are unallocated decisions, not automatically mandatory features.

Real programme content/readiness, human coaching approval, adopted running/tracking
boundaries and the launch-library quality gate remain separate launch requirements.
Stage 3 hosted/operator publication controls are separate; Studio publication buttons
are optional while the approved command-line path remains available. Broader C and
four genuine-record-dependent phone checks remain open.

Arbitrary lineage counts, broader exercise/profile trust and general editable-history
restoration are optional extensions unless a concrete use case requires them. Another
synthetic expansion is not the recommended next task.

Recommend one **read-only practical-authoring usability allocation** for the existing
workflow: trace the current create → validate/freeze → admit → choose slot → review →
export flow, define plain-language action/state feedback and progressive disclosure
of technical identity details, and specify a short outcome-based founder test. Keep
all existing authority boundaries. Identify only first-use-case capability blockers;
do not add lineages, profiles or representations speculatively. Allocate and approve
that task separately; no next-task implementation is authorised here.
