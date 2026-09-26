# Bali strength load-capture — handoff

**Recorded:** 2026-09-26
**Branch:** `fix/bali-strength-load-capture-v1`
**Base:** `origin/main` `7385e8809d1fc1c8d0ea4f73a990ed55ca5b0679`
**Contract:**
[`../architecture/Bali_Strength_Load_Capture_Incident_v1.md`](../architecture/Bali_Strength_Load_Capture_Incident_v1.md)

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_STRENGTH_CAPTURE_INCIDENT=IMPLEMENTATION_COMPLETE
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## Cause

Hosted working-set prescriptions were `load: {type: freeText, text: RPE 7}`
with no `performance_capture`. `fromPrescription` treated that as
non-external, so Daily Journey showed reps only. Rest ranges were not
stored. The Plan Package hash does not cover protocol bodies.

## Fix

Founder YAML now carries explicit capture metadata from
`emit_bali_hybrid_base.py`. The private graph builder persists
`performance_capture`, rest-range minima, and recognised load types.
Strength `freeText` effort no longer hides kg. Capture widgets show
load / distance / RPE from authored dimensions, not from exercise names.

Repair: `repair_private_programme_exercise_capture(jsonb)` service-role
only. CLI: `tool/programmes/bin/repair_private_exercise_capture.dart`.

Migration:
`supabase/migrations/20260926170000_private_exercise_capture_repair.sql`

Do not re-enrol Bali. Do not start Strength A automatically.
