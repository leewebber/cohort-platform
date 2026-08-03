# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 Sprints 1.3–1.5A merged; Sprint 1.6A–1.6E complete;
Sprint 1.7A–1.7C scheduling (contract, compute-only preview, durable projection
foundation) complete on dedicated branch (not pushed)

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
- Sprint 1.7C: durable projection via
  `ensure_programme_schedule_projection` +
  `ProgrammeScheduleRestoreService` (baseline init/restore only; no apply)
- Next sprint: **1.7D — Move + Swap apply paths + UI confirm**
- Binding scheduling contract:
  [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)
- Adaptation contract (complete):
  [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- Milestone status: acceptance-gated adaptation (1.6A–1.6E) complete.
  Scheduling authority: 1.7A–1.7C (contract + preview + durable baseline);
  Move/Swap/Push/Skip apply and athlete UI remain later increments.

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

1. After review of Sprint 1.7C, implement Sprint 1.7D Move/Swap apply only.
2. Push/Skip apply remain 1.7E; Undo/UI/hardening remain 1.7F. No athlete-facing
   scheduling behaviour before those increments.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
```
