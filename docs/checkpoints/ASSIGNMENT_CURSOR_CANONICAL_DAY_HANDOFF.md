# Assignment cursor incident — handoff

**Recorded:** 2026-09-26
**Branch:** `fix/assignment-cursor-canonical-day-v1`
**Base:** `0ce94f4df88f46b49536963c898817f848c82c53`
**Contract:**
[`../architecture/Assignment_Cursor_Canonical_Day_Incident_v1.md`](../architecture/Assignment_Cursor_Canonical_Day_Incident_v1.md)

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_ASSIGNMENT_CURSOR_INCIDENT=OPEN
BALI_HOSTED_PRIVATE_PUBLICATION=true
PRIVATE_PROGRAMME_INFRASTRUCTURE=COMPLETE
NEXT_IMPLEMENTATION_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
```

Home failed because assigned athletes could load private weeks and not
days. The Bali cursor already stores canonical `day_1`. No assignment
repair is authorised.

Migration:
`supabase/migrations/20260926150000_assigned_programme_graph_read.sql`

Gate: `./supabase/tests/run_assigned_programme_graph_read_gate.sh`

Do not re-enrol Bali. Do not UPDATE the cursor. Affected repair rows: 0.
