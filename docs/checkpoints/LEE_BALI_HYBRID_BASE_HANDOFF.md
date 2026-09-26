# Lee Bali Hybrid Base — handoff

**Recorded:** 2026-09-26
**Status:** Phase 1 complete. Authoring, Studio preview, compile, and
hosted work **not started**. Awaiting founder approval of the two
blocking follow-ons.
**Branch:** `feat/lee-bali-hybrid-base-v1` (local only)
**Base / HEAD at handoff:** see git after the docs commits.
**Contract:**
[`../architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md`](../architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md)
**Audit:**
[`./LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md`](./LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_WORKOUT_B1=COMPLETE
RUNNING_PACE_FOUNDATION=B1_COMPLETE
LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Committed B1 docs may still say `IMPLEMENTED_AWAITING_FOUNDER_APPROVAL`.
Operationally B1 is on `origin/main`. Live documentary flag movement
for B1 belongs with the next authorised decision record, not a rewrite
of the B1 handoff.

---

## What shipped

Documentation only: implementation contract, Phase 1 audit, this
handoff, and live pointers. No Plan Package, protocols, tests,
Studio catalog entry, SQL, or hosted contact.

## What did not ship

Canonical Bali source files, compiled hash, Studio preview URL,
fidelity tests, assignment of Bali to Lee.

## Next approval required

1. Authorise the authored-day calendar placement change in
   `ensure_programme_schedule_projection` (same-day slots share a date;
   week 8 may have nine days on an 8-week `duration_weeks`).
2. Authorise a private exact-version enrol/replace-active transaction
   that does not set `approved_for_global` or athlete-catalogue
   visibility.
3. After those land: author Bali from the DOCX, Studio review, then a
   **separate** approval immediately before hosted private publication
   and changing Lee’s current assignment.

## Non-actions

No authoring, no push, no B2, no commercial HYROX Base, no Apollo
edits, no hosted reads or writes, no phone/preview builds.
