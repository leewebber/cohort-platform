# Private protocol-graph publication — incident contract

**Status:** Active athlete-facing compile incident after private Bali
activation.
**Base:** `origin/main` `cd5258949b0528715f3275dd8ba8e0783ef25cd2`
**Branch:** `fix/private-protocol-graph-publication-v1`
**Cursor incident (read path):**
[`Assignment_Cursor_Canonical_Day_Incident_v1.md`](./Assignment_Cursor_Canonical_Day_Incident_v1.md)

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_ASSIGNMENT_CURSOR_INCIDENT=HOSTED_READ_FIXED
BALI_PROTOCOL_GRAPH_INCIDENT=OPEN
NEXT_IMPLEMENTATION_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
```

Home now resolves the assignment cursor and pinned schedule. Preparation
fails closed with `empty_execution_plan` / “Authored session could not be
compiled.” No workout has been started. Retry has not been tapped.

---

## Known cause

Private publication wrote published protocol **headers** and the 71-slot
schedule. It did not write `session_blocks`, `session_block_exercises`,
or `protocol_steps`.

Plan Package v1 carries session identities only. Executable bodies live
in the founder YAML. The payload builder omitted those bodies. The RPC
never inserted them. Gates pre-seeded protocol headers, so header-only
publication looked successful.

---

## Permanent invariant

A private programme version cannot become `published` or enrolment-eligible
unless every scheduled non-rest protocol resolves to a complete,
executable authored graph — or an already-supported non-block execution
authority (`protocol_steps`). “Header exists” is not executable.

Home’s fail-closed compiler is not weakened.

---

## Immutability decision (Phase 3)

In-place completion of the missing child graph is authorised **only**
when hosted evidence shows:

- repository source already contains the exact graph
- hosted protocol headers match the intended identities/revisions
- expected child rows are completely absent, not conflicting
- no Bali session has started
- no Bali session record or outcome exists
- the operation inserts only missing immutable child rows
- version ID, hash, lineage, assignment pin, schedule, dates, and
  protocol header identity are unchanged

If any hosted child row conflicts with the approved graph, stop.

---

## Authorities

- Permanent: `publish_private_exact_programme_version(jsonb)` writes the
  draft protocol graph, validates executability, then publishes.
- Repair: `repair_incomplete_private_programme_graph(jsonb)` —
  service-role only, assignment-safe, insert-missing-only, atomic,
  idempotent.

No ad hoc INSERT. No Lee UUID. No catalogue exposure. No Apollo change.
No re-enrolment.
