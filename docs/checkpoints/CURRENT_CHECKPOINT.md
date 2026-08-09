# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 3 — Exercise Database in progress (3.1A–3.1D committed; 3.1E
relationship graph complete pending review; Phase 3.1 not complete).

```text
PHASE_1_CLOSED=true
PHASE_2_CLOSED=true
CANONICAL_ARCHITECTURE_FROZEN=true
PHASE_3_STARTED=true
PHASE_3_1A_ACCEPTED=true
PHASE_3_1B_ACCEPTED=true
PHASE_3_1C_ACCEPTED=true
PHASE_3_1D_ACCEPTED=true
PHASE_3_1D_IDENTITY_BRIDGE_COMPLETE=true
PHASE_3_1E_RELATIONSHIP_GRAPH_COMPLETE=true
PHASE_3_1_COMPLETE=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=deferred
RELATIONSHIPS_SELECT_SUBSTITUTIONS=false
RELATIONSHIP_IMPLIES_COMPARABILITY=false
```

Phase 2 closed at `71b5a54623e584fb667b96617178fe1af591b787`.  
Phase 3.1A: `5d05e66d6616090afe7408a2eb7ed14e6db94e2b`  
Phase 3.1B: `b9952b69340d3150e6b62e06951aa2c5d90a1e38`  
Phase 3.1C: `957a63d9809e8291b8715e3743feccb93a798eee`  
Phase 3.1D: `38f27ca478779903fc1d93bca5368daed87388f2`  
Phase 3.1E adds `ExerciseRelationshipGraph` (derived read model), eligibility
evaluation, and comparability firewall — no live consumer migration.

**Binding authority:** Phase 3.1B–3.1E architecture docs + canonical freeze.

**Safety gate:** `./tool/testing/run_phase2_consolidation_safety_gate.sh`

Next: **Phase 3.1F — Founder Canonical Catalogue and Identity-Mapping Review**
(after 3.1E review/commit).

## Delivery sequence

| Stage | Status |
|-------|--------|
| 3.1A–3.1D | **COMPLETE** (committed) |
| 3.1E — Relationship graph | **COMPLETE** (pending review commit) |
| 3.1F — Founder catalogue / mapping review | Next |
| Phase 3.1 complete | **NO** |

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
```
