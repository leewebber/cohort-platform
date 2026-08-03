# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 Sprints 1.3–1.5A merged; Sprint 1.6A acceptance-gated adaptation contract in progress

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
- Active sprint: **1.6A — Acceptance-Gated Adaptation Authority Contract**
- Binding contract:
  [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- General adaptation policy (still binding):
  [`../architecture/Adaptation_Policy_v1.md`](../architecture/Adaptation_Policy_v1.md)

Sprint 1.6A is documentation and architecture-contract only. Do not implement
product behaviour, UI, persistence, migrations, or Supabase changes in 1.6A.

## Approved adaptation direction (summary)

1. Reuse `SessionAdaptationPipeline` through a Plan-Package-native adapter; the
   programme journey must not depend on the legacy generative Plan Library /
   Coach Brain product path.
2. Adaptation may apply at whole-session and individual-exercise granularity.
3. Nothing changes without explicit athlete acceptance; accept mutates only the
   current prepared executable session.
4. Initial reasons: time, equipment, environment, recovery — or clear
   no-safe-adaptation when unlawful.
5. Phase 1 persistence: local prepared session only; no new server table in
   this sprint series unless later authorised.
6. Accept replaces the current prepared `SessionExecutionPlan` while retaining
   original programmed reference, decision metadata, and provenance.
7. Reject / Keep Original / cancel / dismiss / ignore are complete no-ops.
8. Post-completion adaptation remains closed for Phase 1.
9. Programme Today will eventually expose athlete-initiated Adapt Session; no
   unsolicited recommendation banners in Phase 1.
10. Sprint 1.5A atomic completion and advancement remain unchanged.

## Rescheduling boundary

Adaptation changes **what** is performed. Rescheduling changes **when** / order
and is a **separate future authority** (proposed Sprint 1.7). Scheduling
operations must not be implemented through the adaptation acceptance path.
See the binding contract for proposed 1.7 principles (final approval during
Sprint 1.7).

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

1. Complete Sprint 1.6A contract documentation on
   `phase1-acceptance-gated-adaptation` (this checkpoint).
2. After review, implement Sprint 1.6B propose/review (no durable write on
   dismiss) per the binding contract.
3. Continue 1.6C–1.6E only after each prior increment is accepted.
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
