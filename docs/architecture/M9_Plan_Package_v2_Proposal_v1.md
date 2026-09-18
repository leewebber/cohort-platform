# Plan Package v2 proposal (not implemented)

**Status:** Proposal only. Do not implement in M9 Sprint 1.  
**Does not rewrite:** published Plan Package v1 assignments or Apollo’s v1 hash.

## Why v1 is insufficient for graph identity

Plan Package schema v1 is a frozen schedule interchange. It has no canonical
`EX-*` identities, so exercise-level graph edges cannot be proven from the
package bytes alone. M9 Sprint 1 uses a separately versioned relationship
source (Apollo week SQL) as a compatibility bridge.

## Proposed v2 contents

- Canonical exercise IDs inside package session/block content
- Session-template-version lineage (`session_lineage_id` + revision) already
  present, retained as the session revision pin
- Relationship manifest or embedded graph references (format versioned)
- Deterministic compatibility with v1 readers: v2 packages carry
  `package_schema_version: 2` and never reinterpret a v1 hash
- Migration/adoption: new versions opt in; existing published v1 assignments
  stay pinned to their v1 package hash
- No forced rewrite of existing published v1 assignments (including Lee / Apollo)

v1 readers must continue to load v1 packages without requiring v2.
