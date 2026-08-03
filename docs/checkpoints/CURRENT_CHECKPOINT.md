# Current repository checkpoint

**Recorded:** 2026-08-03
**Status:** Phase 1 product Sprints 1.1–1.7 implemented locally. Local
integration closeout documentation reconciled and full local verification green
on `phase1-integration-closeout` (not pushed). Authorised local fast-forward of
`main` is the remaining closeout step. Staging verification for 1.6 and 1.7
remains separately authorised and outstanding. No Sprint 1.8 or next product
phase has been allocated.

## Merged main checkpoint (pre-closeout)

- Branch: `main` / `origin/main` (before this closeout’s authorised local FF)
- Merge commit: `fdae6dd37330980c3e775da8e651a51f86f5b99c`
- Source feature tip included: `df2f0951fca219925c815b9970cdee9a0cfdc3dc`
- Staging-verified Sprint 1.5A implementation checkpoint included:
  `4365568ea33555b9cf50130a6df6965d0abb2b53`

## Phase 1 stacked tip (integration candidate)

- Frozen scheduling tip (pre-closeout docs commit):
  `d0d8bf0f0afbf53a88f6bcd72711a8b2531b6c22`
- Sprint 1.7F feature: `5555920e09351435bd340a9024449604d931618c`
- Adaptation tip (ancestor; do not rewrite):
  `phase1-acceptance-gated-adaptation` @ `30ec8b0a945b2dc9ad5acd43006addb8477edaea`
- Ancestry:
  `fdae6dd ⊂ 30ec8b0 ⊂ 5555920 ⊂ d0d8bf0`
- Active closeout branch: `phase1-integration-closeout`
- Preserved scheduling branch tip:
  `phase1-athlete-controlled-scheduling` @ `d0d8bf0`

## Completed Phase 1 product scope

| Sprint band | Scope | Local status |
|-------------|--------|--------------|
| **1.1–1.2** | Authored Plan Package compile/import/catalogue | On `main` @ `fdae6dd` |
| **1.3** | Athlete catalogue enrolment | On `main` @ `fdae6dd` |
| **1.4A–1.4B** | Materialisation, cursor, first prepared session | On `main` @ `fdae6dd` |
| **1.5A** | Atomic completion + authored cursor advance | On `main`; staging Self-Test 2 closed @ `4365568` |
| **1.6A–1.6E** | Acceptance-gated programme adaptation | Complete on stacked tip; staging evidence deferred |
| **1.7A–1.7F** | Athlete-controlled scheduling | Complete on stacked tip (local Gates N–P) |

Scheduling at tip includes: authoritative restore; Move; Swap; Push; Skip;
contract-defined one-level Undo; durable nullable `scheduling_horizon_end`
(`NULL` = unbounded); assignment-scoped athlete calendar; authoritative retry,
cache and relaunch recovery.

Binding contracts:

- [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)

## Approved direction (summary)

1. Authored Plan Package remains sole prescription authority.
2. Scheduling changes when/placement (and skip disposition), not prescription.
3. Preview is compute-only; mutation requires explicit confirmation.
4. Completion remains Sprint 1.5A-owned; skip is not completion.
5. Adaptation remains limited to the current prepared executable session.
6. No Coach Brain, Adaptive Progression, or adaptation-pipeline scheduling.
7. Founder-approved Sprint 1.7 defaults remain binding (default-allow ops;
   past-date catch-up; durable nullable horizon; 72h undo TTL; paused blocks).
8. Historical Phase 5 MVP numbering is **not** the current delivery sequence.
9. Future package-authored bounded horizons require a separate authorised
   contract/schema change.
10. No Sprint 1.8 or next product phase is allocated yet.

## Preserved state

- Preserve Cohort Staging Athlete C and its committed Sprint 1.5A completion.
- Leave all local `supabase/.temp/*` drift untouched and uncommitted.
- Do not push `main` or feature branches without explicit authority.
- Do not contact staging or production unless explicitly authorised.

## Exact next sequence

1. Fast-forward local `main` to this closeout tip (authorised by the closeout
   task; do not push).
2. Staging verification for Sprints 1.6 and 1.7 remains **separately
   authorised** and outstanding.
3. Production rollout and remote migration application remain separately
   controlled.
4. Do not begin Sprint 1.8 or another product phase without explicit allocation.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
git rev-parse main origin/main
```
