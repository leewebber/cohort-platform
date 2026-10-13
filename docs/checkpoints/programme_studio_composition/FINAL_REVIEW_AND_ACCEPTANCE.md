# Programme Studio composition — founder acceptance and final review

**2026-10-13 · COMPOSITION_ACCEPTED_FINAL_REVIEW_PASSED.**
Founder reports all four composition walkthrough steps work with no reported
issues, and accepts the demonstrated bounded synthetic workflow. Founder separately
authorises final review, scoped fixes, clean linear integration and normal main-only
publication if verification passes. This supersedes the [implementation handoff's](./HANDOFF.md)
visual-review pause; its earlier evidence remains historical.

Binding: [approved allocation](./ALLOCATION.md), [Studio contract](../../architecture/Programme_Studio_v1.md),
[launch-library roadmap](../../architecture/Launch_Programme_Library_v1.md),
[D1 acceptance](../programme_studio_d1/FINAL_REVIEW_AND_ACCEPTANCE.md) and
[D2 acceptance](../programme_studio_d2/FINAL_REVIEW_AND_ACCEPTANCE.md).
Fresh results: [final verification](./FINAL_REVIEW_VERIFICATION.json).
[Next bounded task handoff](./NEXT_STAGE2_HANDOFF.md) is a proposal for a new
conversation, not implementation authority.

## Review outcome

Reviewed the complete exact baseline-to-branch range, including source-provider
and embedding changes, new composition/controller/catalogue/bridge/transport/UI,
all regression/isolation tests and checkpoint evidence. Two confirmed defect groups
were fixed entirely within composition; no new authorable scope or content was added.

1. **Notification lifecycle and completion:** callback reset could dispose D1/D2
   owners while their own notifications were active; self-disposal could do the same
   to the composition notifier. Admission/selection could report success after a
   notification replaced/disposed the owning workspace, and could overwrite a newer
   pending operation's busy state. Detach owners and invalidate tokens immediately,
   defer child cleanup until callbacks unwind, defer the notifier's final disposal
   until its notification stack exits, and check owner identity after completion.
   Preserve newer-operation state. Normal completed admission remains valid if a
   later same-workspace edit leaves its immutable append intact.
2. **Export consumption:** the UI's awaited copy boundary compared only text bytes;
   a queued edit could invalidate the owning receipt before those bytes were consumed.
   The composition-only synchronous gate now checks the exact currently owned receipt
   and deterministic handoff bytes immediately before opening/copying an export.
   Stale copy is refused; a normal fresh copy still succeeds.

Reproduced failing checks before fixes. Ten new regressions cover reset from both
source-lane notifications, notification disposal, reset/disposal after admission,
reset after selection, admission/selection preserving a callback-started newer
validation, stale clipboard consumption and successful exact clipboard consumption.
Founder's visual acceptance is of the demonstrated workflow; these narrow callback
and copy guards were subsequently verified locally and do not add a new workflow.

The remaining reviewed boundaries pass:

- Default standalone D1/D2 behaviour is preserved; optional source/embedding hooks
  remain isolated. The dedicated graph strictly resolves its local/compiler/importer
  edges and has no hosted/persistence/athlete service. Older entry graphs cannot reach
  composition; inherited unrelated production traversal gaps retain their documented
  qualification, with a complete direct-edge scan as independent negative evidence.
- Admission requires an identical genuine frozen entry from the owning D2 catalogue,
  recompiles exact bytes and compares immutable tuple/digest/meaning/version bindings.
  One fixed synthetic lineage/profile is enforced; conflicts/foreign/unfrozen/wider
  unsupported sources fail closed. Exact repeats are idempotent and never select.
- Confirmed selection changes one required slot only. Labels/titles are display data;
  explicit tuples and source bindings identify revisions, including same-title cases.
- Source trees/collections and derived projections cannot mutate retained frozen
  sources. Actual existing Studio validates every programme slot and complete supported
  body. Edits/failures, pending work and callback races cannot expose stale joint success.
- Complete transport includes every declared source, selected and unselected, explicit
  tuples/bindings and the fixed profile fingerprint. Read-only reopen recomputes claims,
  rejects missing/extra/duplicate/unsupported/tampered inputs and cannot hydrate or
  replace live authoring, reservations or frozen-parent history. Deterministic re-export
  retains exact source bytes. This is source transport, not a persisted Studio store.
- Existing package hashes retain body-excluding meaning; source-byte digests remain
  distinct. Tests demonstrate identical package hashes under fixed references with
  changed body bytes, while live immutable replacement is refused. No joint hash,
  name-based identity or inferred approval/publication provenance was introduced.

## Fresh verification and protection

**341 affected root tests pass**, including unchanged standalone D1/D2, Founder
import, authored packages, session/identity regressions and the expanded composition
checks. The focused composition set now has **55 passing checks**. **41 canonical
package tests pass**, protecting existing v1/v2 compiler/hash/golden behaviour.
All six unchanged safety groups pass. Changed-file analysis across all **15 Dart
files** has **zero diagnostics**. Full analysis is explicitly **non-green**:
**367 inherited diagnostics, 110 warnings, 257 info, zero errors**. The fresh
complete diagnostic lines exactly match the original verified log whose SHA-256
is retained in committed implementation evidence; no additions or removals.
Three brace-style diagnostics introduced during the fixes were identified and
removed before final verification; they are not an accepted baseline increase.

Protected all 2,637 baseline file entries, allowing only the four originally
approved D1/D2 hooks/isolation test and current-checkpoint pointer to differ.
All other baseline bytes remain identical: shared compiler/schema/hash/writers,
canonical resolver/revision allocator, existing published artifacts, v1/v2 goldens,
migrations, release guards, dependencies and production entries. Diff whitespace
and checkpoint relative links pass. No real content, hosted project operation,
production wiring, migration, athlete write or device build/install occurred.

## Preview and preservation

Restored the original synthetic workspace with the existing full reset mechanism:
R1-only frozen/admitted catalogue, initial required R1 slot and programme name from
source **Synthetic D2 revision selection**. Verified source name and catalogue/slot
rendering. Stopped only the identified composition Flutter preview process;
127.0.0.1:4195 has no listening process. Preview is no longer running.

All three older checkouts retain exact branch, HEAD, index hash, tracked/dirty
contents and `.temp` against their pre-implementation snapshots:

- Original: `a331f52967e1887c4435cccc8f1ecfa192028cd6`, local `main`, exactly 95
  outstanding paths. Local main remains attached here and is deliberately not advanced.
- D1: `6318f319db15ff7a42283c7719dc22a6dc28daa5`, `codex/programme-studio-stage2`, clean.
- D2: `6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6`, `codex/programme-studio-d2`, clean.

The old allocation's first-status-path serialization defect remains explicitly
corrected only for snapshot comparison. No older checkout was switched, reset,
stashed, cleaned, staged, committed or advanced. Fresh origin tracking refs are
shared Git metadata; their approved update does not advance older local branches.

## Exact range and publication preflight

Clean integration/publication checkout is the managed composition worktree:
`/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform`,
branch `codex/programme-studio-composition`. Its five reviewed code/evidence commits
from exact baseline `6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6` are preserved:

1. `f90a2094d0a63d78803790471fb42863645b688c` — approved allocation.
2. `9a78f4cf5cbadabe948a1870972a8292beef8043` — implementation.
3. `2198a78b94872beccf1dd7d15f3b816a79723d29` — original regression evidence.
4. `ec164a9669e6d1c874cba5643c14b92c949327ab` — implementation handoff.
5. `4a65e865ae1f537182be7a90aa91a0d3c9a0320c` — scoped final-review fixes/tests.
6. The immutable commit introducing this acceptance checkpoint and fresh evidence.
   Obtain its exact SHA with `git log --diff-filter=A --format=%H -- docs/checkpoints/programme_studio_composition/FINAL_REVIEW_AND_ACCEPTANCE.md`.

Fresh main-only origin fetch verified `github.com/leewebber/cohort-platform.git`
main exactly equals the expected baseline; no remote advance/conflict/scope change.
Five code/evidence commits are linear with zero merges; this acceptance commit
extends that same linear range to six. Publication is authorised only from this
clean checkout using normal `HEAD:refs/heads/main`, with follow-tags disabled.
Keep original local main unchanged because it is attached to the dirty checkout.
No feature branch or tag publication, force push, merge, squash or rebase.

This checkpoint records review acceptance and preflight before its own commit can
be published. The task's final response and separate local publication receipt
record the actual pushed/refetched SHA, exact six-commit range, divergence 0/0 and
clean worktree after publication. Resolve the acceptance commit above to identify
the exact intended published range without a self-referential embedded commit SHA.

## Remaining boundary

Only this synthetic composition workflow is accepted. Broader Stage 2/Sprint C
remain open; four genuine-record-dependent phone checks remain pending. No real
programme or profile content/publication authority follows. Stage 3 remains separate.
**NEXT_IMPLEMENTATION_AUTHORISED=false.** Stop after publication verification;
do not implement or begin the proposed next task.
