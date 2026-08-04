# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.6 diagnosed the B4d.5 post-Swap+Push Skip failure locally.
No staging contact under B4d.6.

**B4d.5 targeted reverification:** `bfe478a`  
**B4d.6 skip diagnosis branch:** `codex/b4d6-skip-diagnosis`

## B4d.5 observed I failure

```text
G PASS → H PASS → I FAIL ("Skip failed or unavailable") → J BLOCKED
Source selected: first uncompleted after G/H (b49af2c9…)
```

## B4d.6 causal diagnosis

| Finding | Result |
|---------|--------|
| Post-Swap+Push date geometry (2 slots) | A@D+2, B@D+1 — **no same-date collision** |
| Domain Skip after date changes | Still preview-ready when target **is** cursor |
| Domain Skip of non-current | `occurrenceNotCurrent` when cursor bound |
| B4d.5 harness snapshot | **`cursorSessionSlotId` unbound (null)** |
| B4d.5 selection | Always **first uncompleted**, not assignment cursor |
| Client vs server | Null-cursor client may preview ready; server RPC still requires current cursor (`occurrence_not_current`) |
| Reporting | All I failures collapsed to opaque string |

**Primary classification:** `HARNESS_INELIGIBLE_SELECTION`  
**Secondary:** `HARNESS_TYPED_RESULT_COLLAPSED`  
**Evidence rider:** `INSUFFICIENT_PRESERVED_EVIDENCE` (B4d.5 did not retain preview/apply codes)

**Product Skip defect proven?** No — geometry alone does not make Skip ineligible.

**Hosted mutation after I FAIL?** Uncertain if apply was reached; opaque report. Treat Athlete D Skip/undo journal as **uncertain** until an evidence-rich run.

## Local harness remediation (B4d.6)

* Resolve assignment cursor into schedule snapshot before Skip
* Select Skip source via cursor (refuse silent first-uncompleted fallback when cursor is non-uncompleted)
* Emit typed I failure detail: preview/apply reached, codes, classification
* Characterization tests for G→H geometry + cursor vs first-uncompleted

Do **not** retry staging under B4d.6.

## Next authority

```text
Harness defect (this diagnosis):
  separately authorise one fresh I→J (or G,H,I,J) staging verification
  using the cursor-aligned typed harness — no product Skip change

If that run still fails with typed EXPECTED_SKIP_INELIGIBILITY /
occurrence_not_current despite cursor alignment:
  diagnose persisted cursor vs first-uncompleted divergence

Journey D remains separate (adaptation-eligible fixture)

B4e remains blocked
```

Production remains rejected. Evidence under `/tmp/b4d5_*` retained.
