# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 Sprints 1.3–1.5A merged; Sprint 1.6B programme adaptation proposal/review in progress

## Merged main checkpoint

- Branch: `main` / `origin/main`
- Merge commit: `fdae6dd37330980c3e775da8e651a51f86f5b99c`
- Merge subject: `merge: land Phase 1 Sprints 1.3 through 1.5A`
- Source feature tip included: `df2f0951fca219925c815b9970cdee9a0cfdc3dc`
- Staging-verified Sprint 1.5A implementation checkpoint included:
  `4365568ea33555b9cf50130a6df6965d0abb2b53`

Sprints 1.3, 1.4A, 1.4B and 1.5A are landed on main through that controlled merge.

## Current feature work

- Branch: `phase1-acceptance-gated-adaptation`
- Based on: `fdae6dd37330980c3e775da8e651a51f86f5b99c`
- Sprint 1.6A contract commit: `daa4080286697dead686da35c5cbcd19c7c25385`
- Active sprint: **1.6B — Programme Adaptation Proposal and Review**
- Binding contract:
  [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- ADR-020 clarification: programme path uses Plan-Package-native adapter →
  `SessionAdaptationPipeline` directly; Coach Brain must not reauthor programmes.

Sprint 1.6B implements athlete-initiated propose/review only. It must **not**
accept, persist accepted decisions, mutate prepared sessions, change completion,
cursor, scheduling, or invoke Adaptive Progression / generative Plan Library
authoring.

## Approved adaptation direction (summary)

1. Authored Plan Package is the sole prescription authority.
2. Reuse `SessionAdaptationPipeline` through a Plan-Package-native adapter.
3. Adaptation may apply at whole-session and individual-exercise granularity.
4. Nothing changes without explicit athlete acceptance (1.6C+).
5. Non-acceptance outcomes are complete no-ops.
6. Post-completion adaptation remains closed for Phase 1.
7. Rescheduling is a separate proposed Sprint 1.7 authority.

## Rescheduling boundary

Adaptation changes **what** is performed. Rescheduling changes **when** / order
and must not be implemented through the adaptation acceptance path.

## Preserved state

- Preserve the Cohort Staging Athlete C fixture and its committed Sprint 1.5A
  completion. Do not reset, recreate, replay, or mutate it without a separately
  authorised staging operation.
- Leave all local `supabase/.temp/*` drift untouched and uncommitted. Its local
  drift is not a cleanup task.
- Do not modify or push `main` / `origin/main` without explicit task authority.
- Do not contact staging or production unless the task explicitly authorises
  that environment and operation.

## Exact next sequence

1. Complete Sprint 1.6B propose/review on
   `phase1-acceptance-gated-adaptation`.
2. After review, implement Sprint 1.6C explicit acceptance + local prepared
   mutation per the binding contract.
3. Continue 1.6D–1.6E only after each prior increment is accepted.
4. Do not begin Sprint 1.7 scheduling until separately approved.

## Resume checks

Before continuing work, confirm:

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
```

Do not infer remote equality from a local remote-tracking ref when live remote
access has not been checked. Do not contact a remote unless the task authorises
it.
