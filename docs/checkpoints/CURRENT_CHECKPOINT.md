# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 Sprints 1.3–1.5A merged; Sprint 1.6A–1.6E complete;
Sprint 1.7A scheduling binding contract complete on dedicated branch

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
- Next sprint: **1.7B — scheduling domain model, identity, preview and policy**
- Binding scheduling contract:
  [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)
- Adaptation contract (complete):
  [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- Milestone status: acceptance-gated adaptation (1.6A–1.6E) complete.
  Scheduling is a separate authority beginning at 1.7A (contract only).

## Approved direction (summary)

1. Authored Plan Package remains sole prescription authority.
2. Scheduling changes when/placement (and skip disposition), not prescription.
3. Preview is compute-only; mutation requires explicit confirmation.
4. Completion remains Sprint 1.5A-owned; skip is not completion.
5. Adaptation remains limited to the current prepared executable session.
6. No Coach Brain, Adaptive Progression, or adaptation-pipeline scheduling.

## Preserved state

- Preserve Cohort Staging Athlete C and its committed Sprint 1.5A completion.
- Leave all local `supabase/.temp/*` drift untouched and uncommitted.
- Do not modify or push `main` / `origin/main` without explicit authority.
- Do not contact staging or production unless explicitly authorised.

## Exact next sequence

1. After review of Sprint 1.7A, implement Sprint 1.7B preview/domain model only.
2. Do not implement durable mutate RPCs or athlete scheduling UI before their
   assigned increments (1.7C+).

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
```
