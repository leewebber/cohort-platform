# B4 overlapping running advisory scope authority proposal

**Status:** `REQUIRES_SEPARATE_MIGRATION_APPROVAL`

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
