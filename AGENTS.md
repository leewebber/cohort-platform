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

Phase 1 Sprints 1.3–1.5A are merged into `main` at
`fdae6dd37330980c3e775da8e651a51f86f5b99c` (includes staging-verified Sprint
1.5A checkpoint `4365568ea33555b9cf50130a6df6965d0abb2b53`).

Current feature branch: `phase1-acceptance-gated-adaptation`. Sprint 1.6C
(explicit accept + local persist/restore) is implemented. Next: **1.6D
pre-completion revert**.

## Authority and product invariants

- Authored programme prescription remains the prescription authority.
- Adaptation is a proposal, not a second prescription authority.
- Programme-backed adaptation reuses `SessionAdaptationPipeline` through a
  Plan-Package-native adapter and must not depend on the legacy generative
  Plan Library / Coach Brain product path.
- Adaptation may apply at whole-session and individual-exercise granularity.
- An adaptation must be shown for review and requires explicit athlete
  acceptance before it may alter prepared execution state.
- Acceptance mutates only the current prepared executable session.
- Dismissal, keep original, cancel, reject, or ignore make no durable
  adaptation change.
- Do not automatically rewrite the programme, advance an athlete, change later
  sessions, or apply post-completion progression (closed for Phase 1).
- Rescheduling (when / order) is a separate future authority (proposed Sprint
  1.7) and must not be implemented through the adaptation acceptance path.
- Do not invent coaching content. Reuse representative protocol and exercise
  data where it exists; otherwise use neutral labels and request direction.

Binding detail lives in
[`docs/architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](docs/architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
and
[`docs/architecture/Adaptation_Policy_v1.md`](docs/architecture/Adaptation_Policy_v1.md).

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
flutter test test/phase6/coaching_integrity_test.dart
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

1. Implement Sprint 1.6D pre-completion revert on
   `phase1-acceptance-gated-adaptation` after 1.6C review.
2. Continue 1.6E hardening in a small verifiable increment.
4. Do not begin proposed Sprint 1.7 scheduling until separately approved.

Acceptance mutates only the current prepared executable session. Do not
implement rescheduling, Adaptive Progression reauthoring, or future-session
mutation.
