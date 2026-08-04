# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.4 diagnosed D/G/H/J non-passes after B4d.3 preparation success.
Another B4d dry/live retry is **not** authorised by B4d.4.

**Harness tip (B4a):** `c9bf996`  
**B4c remediation:** `f58f55c`  
**B4d.1 remediation:** `4ae9ba1`  
**B4d.2 diagnosis:** `9e175f3`  
**B4d.3 live-assignment bind:** `1607d7d`  
**B4d.4 journey diagnosis branch:** `codex/b4d4-journey-diagnosis`

## B4d.3 preparation success (accepted)

| Item | Result |
|------|--------|
| Live-assignment binding | PASS → `PROG-S15A-STAGING` |
| Stale S13 defines | superseded |
| Enrol/switch/replaceActive | skipped |
| Materialisation + prepared execution | PASS |
| Baseline | uncompleted=3 |
| Selected matrix | `C,D,F,G,H,I,J,K` |
| Observed | C/F/I/K PASS · D BLOCKED · G/H/J FAIL |

## Exact execution order (not matrix letter order)

```text
Prepare/baseline → F → G → H → I → J → K → C → D
```

F–J mutate **one shared schedule**. That is intentional for Skip→Undo (I→J) and
acceptable for sequential schedule ops, but B4d.3’s G/H probes were
**accidentally order-contaminated** by prior mutations and wrong invalid probes.

| Journey | Independence |
|---------|--------------|
| F | Shared schedule start |
| G | Accidentally order-dependent on F (same-date after Move+1) |
| H | Valid half OK; invalid half used wrong probe under NULL horizon |
| I → J | Intentionally sequential (Skip establishes undoable) |
| K → C | Intentionally sequential (completion may seed previous performance) |
| D | Independent of schedule dates; eligibility/fixture limited |

## Journey D — proposal eligibility

D BLOCKED when `propose(equipment)` returns a non-acceptable outcome
(typically `noSafeAdaptation`). That is **expected policy / fixture eligibility**,
not a silent failure and not PASS.

Harness must report the safe outcome/reason and must never classify lack of
proposal as PASS. Meaningful reject+accept coverage requires a positively
eligible reviewable proposal for the prepared S15A session (lawful equipment
substitute metadata). Do not weaken `AdaptationPolicyGate` to force a proposal.

## Journey G — invalid vs valid halves

| Half | B4d.3 | Cause |
|------|-------|--------|
| Invalid swap (A,A) | rejected | Product correct |
| Valid swap (first two uncompleted) | FAIL | After F Move+1, first two share a date; product rejects same-date swap (`noChange`) |

Classification: **harness defect / accidental order-dependency**, not a swap RPC
defect. Remediation: refresh occurrences and select a **distinct-date** pair;
require both-side date postconditions + revision change. If no distinct-date pair
exists → BLOCKED with contamination detail.

## Journey H — valid vs horizon-invalid halves

| Half | B4d.3 | Cause |
|------|-------|--------|
| Valid push (+1) | applied | Product correct |
| Invalid `dayDelta:10000` | `invalid_rejected=false` | `scheduling_horizon_end` is **NULL = unbounded**; large delta is allowed |

Horizon contract: non-null end is **inclusive** (`isAfter` rejects). NULL means
unbounded. B4d.3 did **not** prove a product horizon defect.

Harness remediation: use `dayDelta<=0` for always-invalid atomic rejection;
only probe `horizonExceeded` when a non-null horizon makes the target truly
out of range. Distinguish `UNBOUNDED_NULL_HORIZON` from accepted invalid push.

## Journey I → J — Skip → Undo

I PASS proves Skip applied. J must undo **that Skip**, not an earlier F/G/H
operation. `latestUndoableOperation` is assignment-scoped by revision.

J FAIL with I PASS is usually: incomplete Skip inverse snapshot, preview
ineligibility, or postcondition/revision mismatch — report typed detail. If
latest operation type ≠ `skip`, classify as undo-stack contamination (BLOCKED).

## Prohibition on retry

B4d.4 does **not** authorise another dry or live B4d run, preparation,
materialisation, or Athlete D mutation. Preserve evidence. Product patches are
separately authorised.

## Evidence retention

Retain Athlete D private config, B4b–B4d.3 artifacts under `/tmp/b4*`, B3a
backup (do not open/restore/delete), and diagnosis worktrees. Production remains
rejected.

## Separately authorised next actions (by classification)

| Classification | Next step |
|----------------|-----------|
| Harness defect (G selection, H invalid probe, D reason capture, J target check) | Authorise harness-only verification after B4d.4 local commit |
| Fixture/eligibility (D noSafe) | Authorise deterministic adaptation-eligible fixture / precondition |
| Incomplete Skip inverse (if proven on staging read) | Product/RPC remediation with characterization test |
| True horizon defect (only if non-null horizon accepted out-of-range) | Product policy remediation |
| B4e | Only after selected journeys PASS under a separately authorised run |
