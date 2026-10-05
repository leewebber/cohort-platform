# B4 overlapping running advisory scope authority proposal

**Status:** `IMPLEMENTED_LOCALLY_AWAITING_INTEGRATION_AND_HOSTED_APPROVAL`

**Recorded:** 2026-10-04

## Finding

Two `authored_running_v1.advisory_attachments` can currently name the same
authored step and still pass both canonical Plan Package compilation and the
hosted `public.cohort_authored_running_v1_is_valid(jsonb)` validator.
Per-attachment duplicate step IDs are rejected, but cross-attachment overlap
is not.

The B3 frozen-target/runtime path already fails closed when two frozen targets
cover one step (`duplicate_step_scope` / `overlapping_target_scope`). Programme
Studio can expose the ambiguity as an error, but that is not an adequate
canonical rejection boundary: publication could still accept an ambiguous
package which only fails later at athlete launch.

## Required coordinated change

A consistent fix requires one separately approved authority change:

1. Update `PlanPackageValidator._validateAuthoredRunning` to maintain a
   slot-local set of advisory-scoped step IDs across all attachments and emit
   `overlapping_advisory_step_scope` for the second claim.
2. Add a new additive migration replacing
   `public.cohort_authored_running_v1_is_valid(jsonb)` with equivalent
   cross-attachment scope tracking. Preserve its immutable volatility,
   `search_path`, ownership, and grants exactly.
3. Keep B3 snapshot and structured-runner overlap rejection as defence in
   depth; do not relax their error semantics.
4. Add a shared parity fixture proving Dart compiler, SQL validator,
   publication, snapshot, runner, and Studio all reject the same overlap while
   valid disjoint attachments remain accepted.
5. Prove the migration locally with the disposable database gate, including
   v1, existing v2, B3 device fixture, grants, retries, and rollback checks.

## Why it is not included in B4

Changing only the Dart compiler would leave hosted SQL validation inconsistent.
Changing only Studio would leave publication authority permissive. Because the
complete correction requires a schema-function migration, the founder's B4
instruction requires this portion to stop at a concrete proposal.

No migration file, compiler rule, hosted object, or package hash is changed by
the current B4 implementation. Studio labels detected overlap as invalid for
review, but that label is explicitly defence in depth and does not claim the
canonical gap is closed.

## Implementation record — 2026-10-05

Founder approved the bounded proposal after visually approving B4 at
`993e51649c2e6c82a740b97062456407a2f84a59`. Local implementation commit
`fb8b6b65a668869d638c64043c3b3f87b94cc81d` now closes the Dart/SQL/Studio
agreement gap for future publication once integrated and, for SQL authority,
once its migration is separately approved and applied.

- canonical Dart validation emits `overlapping_advisory_step_scope` when a
  second attachment claims an authored step;
- additive migration
  `20261005120000_reject_overlapping_running_advisory_scope.sql` applies the
  same rule to `public.cohort_authored_running_v1_is_valid(jsonb)` while
  retaining its owner, immutable volatility, fixed `search_path`, and
  service-role-only execution grant;
- Programme Studio reports the canonical failure code and does not attempt to
  soften or repair invalid content;
- shared cases prove partial and identical overlap fail, while disjoint scopes,
  one attachment spanning several steps, and repeated execution of one scoped
  work step remain valid; and
- unchanged valid canonical documents retain their existing bytes and hashes.

This record does not authorise hosted migration apply, programme publication,
or programme-content adoption. The preceding proposal text is retained as the
dated rationale and pre-implementation state.
