# Cohort Platform repository guidance

This file applies to the entire repository. A more deeply nested `AGENTS.md`
or `AGENTS.override.md`, if one is added later, governs only its subtree.

## Start-of-task continuity

Before changing the repository:

1. Read [`docs/checkpoints/CURRENT_CHECKPOINT.md`](docs/checkpoints/CURRENT_CHECKPOINT.md).
2. Read the architecture and product documents it identifies as binding.
3. Inspect the current branch, `HEAD`, worktree, and relevant verification
   commands.
4. Treat existing uncommitted changes as user-owned. Do not discard, clean,
   stage, or rewrite them unless explicitly authorised.

The current Sprint 1.5A staging-verified implementation checkpoint is
`4365568ea33555b9cf50130a6df6965d0abb2b53`. Sprint 1.5A and Self-Test 2 are
closed, but their feature branch is not yet merged.

## Authority and product invariants

- Authored programme prescription remains the prescription authority.
- Adaptation is a proposal, not a second prescription authority.
- An adaptation must be shown for review and requires explicit athlete
  acceptance before it may alter prepared execution state.
- Dismissal or keeping the planned session makes no durable adaptation change.
- Do not automatically rewrite the programme, advance an athlete, change later
  sessions, or apply post-completion progression.
- Do not invent coaching content. Reuse representative protocol and exercise
  data where it exists; otherwise use neutral labels and request direction.

Binding detail lives in
[`docs/architecture/Adaptation_Policy_v1.md`](docs/architecture/Adaptation_Policy_v1.md)
and the authority documents linked by the current checkpoint.

## Repository safety

- Never print or commit credentials, tokens, passwords, connection strings, or
  generated staging secret values.
- Keep `.env` and all environment-specific secrets out of Git.
- Leave `supabase/.temp/*` untouched and uncommitted. Its local drift is not a
  cleanup task.
- Preserve the Cohort Staging Athlete C fixture and its committed Sprint 1.5A
  completion. Do not reset, recreate, replay, or mutate it without a separately
  authorised staging operation.
- Do not contact staging or production unless the task explicitly authorises
  that environment and operation.
- Do not run migrations, merge, fetch, push, commit, or modify `origin/main`
  without explicit task authority.
- Verify the exact target before any remote or destructive operation.

## Verification

Use the narrowest relevant checks first, then broaden in proportion to the
change. Existing repository verification entry points include:

```bash
flutter test
flutter analyze
flutter test test/architecture/ test/planning/ test/knowledge/
flutter test test/programme/athlete_programme_completion_self_test_2_test.dart
./supabase/tests/run_local_db_gate.sh
```

The Supabase gate is local and Docker-backed. Staging scripts under
`tool/staging/` are guarded remote operations, not routine local verification.
Do not run them merely because they exist.

Never claim a check passed unless it was actually run successfully in the
current task or is clearly attributed to an immutable, committed checkpoint
record.

## Current delivery sequence

The exact next sequence is:

1. controlled merge checkpoint for the closed Sprint 1.5A feature branch;
2. create a new feature branch for acceptance-gated adaptation architecture.

Do not combine adaptation work into the merge checkpoint, and do not begin it
on the Sprint 1.5A feature branch.
