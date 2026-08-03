# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 Sprints 1.3–1.5A merged; Sprint 1.6A–1.6E complete;
Sprint 1.7A–1.7E scheduling (contract, preview, durable projection,
Move/Swap/Push/Skip exact-preview apply) complete on dedicated branch
(not pushed)

## Merged main checkpoint

- Branch: `main` / `origin/main`
- Merge commit: `fdae6dd37330980c3e775da8e651a51f86f5b99c`
- Source feature tip included: `df2f0951fca219925c815b9970cdee9a0cfdc3dc`
- Staging-verified Sprint 1.5A implementation checkpoint included:
  `4365568ea33555b9cf50130a6df6965d0abb2b53`

## Current feature work

- Active branch: `phase1-athlete-controlled-scheduling`
- Branched from adaptation tip:
  `30ec8b0a945b2dc9ad5acd43006addb8477edaea`
- Preserved adaptation branch (do not rewrite):
  `phase1-acceptance-gated-adaptation` @ `30ec8b0`
- Sprint 1.6E tip: `bcc4b36a7f0849440bf7716f0c4bca7304ee559f`
- Sprint 1.7A tip: `c95c5e2f6594858918ea754eac16c428f66fef4a`
- Sprint 1.7B feature: `a11fe73353e337c77b482b03bcbb59e071f83bf5`
  (`lib/domain/programme_scheduling/`, owner
  `ProgrammeSchedulingPreviewEngine`)
- Sprint 1.7C feature: `17a12ce4fcfe05bbf9ca7ea3158edc0b46f15693`
  durable projection via `ensure_programme_schedule_projection` +
  `ProgrammeScheduleRestoreService` (baseline init/restore only; no apply)
- Sprint 1.7D feature: `596f36ad5c27ca9bc4157d55367f7c24dbdea1ab`
  exact-preview Move/Swap apply via
  `apply_programme_schedule_operation`, `ProgrammeScheduleApplyService`,
  and `AthleteProgrammeScheduleScreen`
- Sprint 1.7E feature: `0a2b51b2af7eb793c4ffbc3358e18f5d80f7d5d2`
  exact-preview Push/Skip apply on the same RPC/service path; Skip atomically
  writes skipped disposition/outcome and advances programme cursor; Gate O
- Next sprint: **1.7F — Undo + broader UI / hardening**
- Binding scheduling contract:
  [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)
- Adaptation contract (complete):
  [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- Milestone status: acceptance-gated adaptation (1.6A–1.6E) complete.
  Scheduling authority: 1.7A–1.7E (through Push/Skip exact-preview apply);
  Undo/broader UI remain 1.7F.

## Approved direction (summary)

1. Authored Plan Package remains sole prescription authority.
2. Scheduling changes when/placement (and skip disposition), not prescription.
3. Preview is compute-only; mutation requires explicit confirmation.
4. Completion remains Sprint 1.5A-owned; skip is not completion.
5. Adaptation remains limited to the current prepared executable session.
6. No Coach Brain, Adaptive Progression, or adaptation-pipeline scheduling.
7. Founder-approved Sprint 1.7 defaults: Move/Swap/Push/Skip default-allow via
   central policy (no package permission schema fields); past-date catch-up
   allowed from `started_at` through today; push horizon fail-closed; undo TTL
   72 athlete-local hours (modelled only in 1.7B); paused assignments block
   preview/mutation.

## Preserved state

- Preserve Cohort Staging Athlete C and its committed Sprint 1.5A completion.
- Leave all local `supabase/.temp/*` drift untouched and uncommitted.
- Do not modify or push `main` / `origin/main` without explicit authority.
- Do not contact staging or production unless explicitly authorised.

## Exact next sequence

1. After review of Sprint 1.7E, implement Sprint 1.7F Undo + broader UI /
   hardening only.
2. Staging rollout remains separately authorised.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
```
