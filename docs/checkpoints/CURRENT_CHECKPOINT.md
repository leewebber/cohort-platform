# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 3.1F Part 1 **STOPPED** — authoritative complete local
`EX-*` catalogue unavailable. No identity mappings proposed or published.

```text
PHASE_2_CLOSED=true
CANONICAL_ARCHITECTURE_FROZEN=true
PHASE_3_STARTED=true
PHASE_3_1E_RELATIONSHIP_GRAPH_COMPLETE=true
PHASE_3_1F_PART1_REVIEW_COMPLETE=true
PHASE_3_1F_PART1_STOPPED_CATALOGUE_UNAVAILABLE=true
PROPOSED_MAPPINGS_PUBLISHED=false
PROPOSED_MAPPINGS_OPERATIONAL=false
HEURISTIC_IDENTITY_MATCHING_USED=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

| Milestone | Commit |
|-----------|--------|
| Phase 3.1A | `5d05e66d6616090afe7408a2eb7ed14e6db94e2b` |
| Phase 3.1B | `b9952b69340d3150e6b62e06951aa2c5d90a1e38` |
| Phase 3.1C | `957a63d9809e8291b8715e3743feccb93a798eee` |
| Phase 3.1D | `38f27ca478779903fc1d93bca5368daed87388f2` |
| Phase 3.1E | `b03faa9d656d2a4fc3005d79205796f0abe07f56` |

**Binding:** [`Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md`](../architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md)

**Unblock:** Authorise read-only export of published `exercises_v2` (see Part 1 §4),
then complete Sections E–H (Part 1b) before Part 2 implementation.

**Safety gate:** `./tool/testing/run_phase2_consolidation_safety_gate.sh`

Next: **Phase 3.1F Part 1b** (catalogue snapshot + complete review matrix) **or**
founder-authorised export, then **Part 2** for approved mappings only.
