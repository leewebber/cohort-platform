# Programme Studio structured running B4 handoff

**Status:** `VISUALLY_APPROVED_INTEGRATED; OVERLAP_AUTHORITY_HOSTED_APPLIED_VERIFIED`

**Base:** `f7297751e9fa5b047a2c9e5e279366de27b12f5c`

**Branch:** `codex/b4-programme-studio-structured-running`

## Contract delivered

- Canonical Plan Package v2 `authored_running_v1` is retained in deterministic
  Studio review JSON.
- A publication artifact must attest the exact compiled package hash, reviewed
  graph path, and graph SHA-256 before the shared publisher graph validator is
  allowed to provide executable review data.
- Coach Review shows ordered one-level repeats, work/recovery roles, time
  durations, authored guidance, exact advisory target scope, authored policy,
  intent-only/no-evidence behaviour, and current execution status.
- IDs, binding UUIDs, package/mapping/graph hashes, and policy identities remain
  under Technical Integrity.
- Hypothetical pace calculation starts blank, accepts only explicit coach input,
  uses existing B2 exact arithmetic plus authored rounding, is not persisted,
  and is labelled as not an athlete target or occurrence snapshot.
- Invalid/missing reviewed evidence fails closed. Unattached v2 remains visible
  as authored but not executable. Apollo, Bali, Spartan, and v1 retain their
  existing derived paths.
- The B3 device-validation package is available only as a developer fixture;
  it is excluded from real inventory and production entrypoints.

## Founder visual approval

Founder visually approved the B4 Coach Review at
`993e51649c2e6c82a740b97062456407a2f84a59`, including the scrollable
policy/hypothetical-calculation layout correction. The isolated preview was
stopped before final full-suite verification and remains stopped.

## Overlap authority implementation

The separately approved bounded authority correction is implemented locally at
`fb8b6b65a668869d638c64043c3b3f87b94cc81d`. The concrete proposal and dated
rationale remain at
[`B4_Overlapping_Running_Advisory_Scope_Authority_Proposal.md`](../architecture/B4_Overlapping_Running_Advisory_Scope_Authority_Proposal.md).

- Canonical Dart compilation, SQL publication validation, and Studio use the
  same `overlapping_advisory_step_scope` rule: an authored step may be claimed
  by at most one advisory attachment.
- Valid disjoint scopes and one attachment spanning multiple steps remain
  valid. A repeated work step remains one authored identity and may execute
  several repetitions under that one attachment.
- Existing B3 snapshot/runtime overlap checks remain defence in depth.
- Additive migration:
  `20261005120000_reject_overlapping_running_advisory_scope.sql`.
- Migration SHA-256:
  `7e277ee064a2bff05eaea9056527754d476528ca7be35c21efceebc62c498643`.
- The migration retains PostgreSQL ownership, immutable volatility, fixed
  `search_path`, service-role-only execution, B2 unattached validity, and B3
  execution-mapping validation.
- The six-commit B4 range was integrated by strict fast-forward on `origin/main`
  through `d6cea8bc702c2ebd6441261fa9a5baba87a4fb34`.

## Hosted deployment — 2026-10-05

Founder authorised only the migration above on Cohort Field Manual
`otnhhdxstdnwccehacku`. A fresh disposable linked workdir verified the clean
integrated checkout, approved file hash, `ACTIVE_HEALTHY` target in `eu-west-1`,
ledger `113 / 20260929120000`, prerequisite definitions/grants, and an exact
one-file dry-run before apply. The CLI reported:

```text
Applying migration 20261005120000_reject_overlapping_running_advisory_scope.sql...
Finished supabase db push.
```

Apply exited successfully. A catalog-cache warning reported a missing pg-delta
certificate; it did not prevent the migration transaction. SELECT-only
postchecks independently confirmed:

- ledger `114 / 20261005120000`;
- replacement validator owned by `postgres`, immutable, non-security-definer,
  `search_path=public, extensions, pg_temp`, execute only for `service_role`;
- validator definition SHA-256
  `f870bafd92231115b6fe4e949d7d0ca7275583e886ae7a034709599f7592fdb2`;
- the other three prerequisite definitions/grants unchanged;
- authored-running CHECK still validated and mapping trigger unchanged/enabled;
- 11 programme versions, 188 slots, 184 unstructured slots, four mapped
  authored-running documents, zero invalid documents and zero overlaps;
- unchanged authored-document digest
  `408950b7bf90333d6dd97e056dca75b9b8a9c5754502202450b8610e17a13874`;
- final dry-run: `Remote database is up to date.`

Disposable files were removed. Repository `supabase/.temp` was unchanged.
No programme or athlete data writes, publication, assignment change, build, or
test run formed part of deployment. The verification above preserves the
previously recorded local test evidence.

## Founder visual walkthrough

Use the isolated Programme Studio preview and select **B4 structured run
review**:

1. Confirm the primary surface shows `Repeat 3 times`, Work 20 seconds,
   Recovery 15 seconds, final recovery, and authored developer-only guidance.
2. Confirm only Work step 1 carries `Advisory pace policy`; Recovery has no
   numeric scope.
3. Confirm the 90%–100% values are explicitly TEST ONLY authored fixture data,
   not approved commercial bands.
4. Expand **Hypothetical preview — not an athlete target**. It must be empty.
   Enter `22:00`; the ephemeral result is `4:24/km–4:53/km`.
5. Confirm the no-evidence message says Cohort does not estimate a pace.
6. Open Technical Integrity and expand Structured running evidence to review
   exact workout, block, step, policy, mapping, and graph identities.

## Verification

- Founder visual review: approved at `993e51649c2e6c82a740b97062456407a2f84a59`.
- Focused Studio/runtime/Bali/Apollo/B3 compatibility tests: **65 passed**.
- Canonical Plan Package v2 authored-running package tests: **9 passed**;
  existing golden hash remained
  `0a71ff90239eddd9e00fecf77a39f580394fbe6c5e766d7bf1088407e9a2f806`.
- Disposable Plan Package v2 publication gate: **19 checks passed on each of
  two reset/replay passes**, including shared Dart/SQL scope cases, grants,
  publication rollback, v1 compatibility, and unchanged canonical hash.
- Disposable B3 device-validation fixture gate: **7 checks passed**; compiler
  and mapping hashes remained unchanged.
- Changed-file root Flutter analysis and canonical-package Dart analysis: no
  issues.
- Phase 2 consolidation safety gate: **6 groups passed, 0 failed**.
- One uncontended full `flutter test` at the final code HEAD: **3,476 passed,
  6 skipped, 0 failed**.
- `git diff --check origin/main...HEAD`: passed at the final documentation
  commit.

## Boundaries

B4 remains a read-only derived review surface and never becomes canonical
authoring authority. Its approved validator migration is applied; programme
publication, assignments, athlete snapshots, phone builds, metrics profiles,
Garmin, commercial content, and production entrypoints remain unchanged.
Further implementation or deployment requires separate authority. Plan Package v2
does not carry reviewed protocol-graph roles, so the package-level uniqueness
rule is deliberately fail closed for every declared authored step; the graph
and runtime continue to enforce that numeric targets attach only to work roles.
