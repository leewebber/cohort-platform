# Architecture review artifacts

## Phase 3.1F Part 1b — exercises_v2 published export

| Artifact | Commit? | Role |
|----------|---------|------|
| `exercises_v2_published_export_phase_3_1f_part1b.json` | **No** (gitignored) | Raw SELECT result — REVIEW_ONLY, not a runtime seed |
| `exercises_v2_published_export_phase_3_1f_part1b.meta.json` | Yes | Provenance: table, scope, row count, ID range |

Derived findings and the founder matrix live in
[`../Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md`](../Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md).

Do not load the raw export into the identity bridge or catalogue seed path.
