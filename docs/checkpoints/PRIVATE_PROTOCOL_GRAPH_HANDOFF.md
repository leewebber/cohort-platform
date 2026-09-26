# Private protocol-graph incident — handoff

**Recorded:** 2026-09-26
**Branch:** `fix/private-protocol-graph-publication-v1`
**Base:** `origin/main` `cd5258949b0528715f3275dd8ba8e0783ef25cd2`
**Contract:**
[`../architecture/Private_Protocol_Graph_Publication_Incident_v1.md`](../architecture/Private_Protocol_Graph_Publication_Incident_v1.md)

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_ASSIGNMENT_CURSOR_INCIDENT=HOSTED_READ_FIXED
BALI_PROTOCOL_GRAPH_INCIDENT=IMPLEMENTATION_COMPLETE
NEXT_IMPLEMENTATION_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
```

## Root cause

`publish_private_exact_programme_version` wrote protocol headers and the
71-slot schedule. Plan Package v1 has no executable bodies. Founder YAML
does. The payload builder omitted them. Tests pre-seeded headers via
`sprint12_ensure_published_session`, so header-only publication passed.

## Immutability

In-place completion is authorised: hosted child rows are expected to be
absent, headers match the pinned identities, and no Bali session has
started. Repair inserts missing child rows only.

## Authorities

- Permanent: payload `protocol_graphs` from founder YAML + Plan Package
  identities. Publish validates executability before `published`.
- Repair: `repair_incomplete_private_programme_graph(jsonb)` service-role
  only. CLI: `tool/programmes/bin/repair_incomplete_private_graph.dart`.

Migration:
`supabase/migrations/20260926160000_private_protocol_graph_publication.sql`

Gate: `./supabase/tests/run_private_protocol_graph_gate.sh`

Do not re-enrol Bali. Do not start Strength A automatically.
