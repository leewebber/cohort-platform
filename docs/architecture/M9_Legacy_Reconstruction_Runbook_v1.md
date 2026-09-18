# M9 legacy reconstruction runbook (local)

**Hosted reconstruction is not authorised.** This path is for disposable local
databases and fixture reports only.

## Contract

- Dry-run first
- Resumable and idempotent (`content_graph_reconstruction_jobs.job_key`)
- No authored-content rewrite
- No assignment repin
- No Plan Package mutation
- Unresolved identities are reported, never guessed
- Source fingerprint change during resume → `source_changed_during_resume`
- Second apply with the same fingerprint writes zero rows

## Classification

1. Fully resolvable — `EX-*` present on authored `session_block_exercises`
2. Resolvable through approved supplemental relationship source (Apollo SQL)
3. Explicitly unresolved — name-only / legacy tokens
4. Invalid/conflicting — malformed identifiers

## Local procedure

1. Compile Plan Package v1 (hash must remain frozen for Apollo).
2. Hash the supplemental SQL relationship source separately.
3. `ContentGraphReconstructionService.run(dryRun: true)`.
4. Review unresolved IDs.
5. `run(dryRun: false, apply: true)` against a **local** database only, via
   `content_graph_record_reconstruction`.
6. Repeat step 5; expect `rows_written = 0`.

## Rollback

Delete `content_graph_reconstruction_jobs` rows and unpublished (there are no
unpublished) reconstruction artefacts. Published manifests are immutable;
rollback is a founder-approved DROP of Sprint 2 objects, not an in-place
rewrite.

## Apollo local expectation

58 unique `EX-*` from week executable protocols **plus** structured warmup
SQL. W12 name-only blocks remain class 3. Package hash
`810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`.
