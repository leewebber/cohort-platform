# M9 manifest authority and source binding

**Status:** Binding correction for M9 Sprint 1 (local only)  
**Does not rewrite:** Plan Package schema v1, Apollo `package_content_hash`, hosted schema.

## Authority hierarchy

1. **Authoritative source** — authored programme / session / exercise content and
   the canonical compiler inputs for that content.
2. **Derived outputs**
   - Plan Package v1 (schedule interchange; frozen schema)
   - Content-graph manifest v1 (integrity / read-model)

The graph manifest is **not** an authoring surface. Manual graph edges that
contradict compiled content are illegal unless they are separately classified
metadata with explicit ownership (none in Sprint 1).

## Binding record

Each manifest includes:

| Field | In structural graph hash? |
|-------|---------------------------|
| Graph-manifest format version | yes |
| Compiler version | yes |
| Stable programme identity | yes |
| Programme-version identity | metadata only (not hashed) |
| Source content/package schema version | composite |
| Source canonical-content SHA-256 (Plan Package v1 hash when applicable) | composite |
| Graph canonical SHA-256 | structural |
| Deterministic node / edge counts | structural (via nodes/edges) |
| Supplemental relationship-source SHA-256 | composite |
| Generation provenance | **excluded** from structural hash |

## Composite content identity

```
sha256(canonical{
  compiler_version,
  graph_format_version,
  source_package_hash,
  supplemental_relationship_hash
})
```

Same inputs ⇒ identical nodes, edges, graph hash, and composite identity.
Changing any relationship-relevant input changes the appropriate hash.

## Plan Package v1 compatibility bridge

Plan Package v1 contains **no canonical exercise IDs**. It cannot independently
prove exercise-level `used-by` edges. For Apollo v1, M9 therefore binds:

- **Source package hash** = existing Plan Package v1 SHA-256
  `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`
- **Supplemental source** = committed Apollo SQL that actually carries `EX-*`
  identities: week executable-protocol files plus structured-warmup Apollo SQL
  (`apollo-sql-relationships/v1`). Canonical JSON is sorted
  `(exercise_id, block_id, session_id)` rows plus the unique `EX-*` set (58).
- **Mismatch** = claimed package/graph/supplemental hashes that do not equal
  a fresh derivation from those files
- **No silent drift** = name similarity is never an identity; unresolved TMP /
  name-only blocks are listed, not guessed

This is a compatibility bridge, not the desired long-term package design.

## Structural vs operational

Included in graph hash: exercise → authored block → session-template revision →
programme-version placement → programme version.

Excluded: active/paused/completed assignment counts, catalogue visibility,
generation timestamps.

## Publication rejects

- Same stable programme/version identity with different graph content
- Graph/source/supplemental/composite hash mismatch
- Mutable or unpublished session revision
- Unresolved canonical exercise
- Cross-namespace edge
- Dangling nodes / illegal supersession cycles
- Identical-content republish (compared on **composite** identity, not package
  hash alone)

See also [`M9_Plan_Package_v2_Proposal_v1.md`](./M9_Plan_Package_v2_Proposal_v1.md)
(**proposal only**; not implemented).
