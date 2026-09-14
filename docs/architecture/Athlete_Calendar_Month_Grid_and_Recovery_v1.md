# Athlete Calendar month grid and incomplete-session recovery

**Status:** Authoritative for post–Sprint 1.7 dogfood Calendar  
**Extends:** [Athlete_Controlled_Programme_Scheduling_v1.md](./Athlete_Controlled_Programme_Scheduling_v1.md)  
**Does not replace** occurrence identity, move/swap/skip/undo, or cursor rules
from Sprint 1.7.

## Calendar

- Default surface is the **month grid**.
- Each occurrence shows date, authored session name, and explicit status.
- Athlete-facing unfinished past work is **Incomplete**. Internal wire values
  may still say `OVERDUE` / `MISSED`; those must not be athlete copy.
- Multiple sessions may share a date.
- Occurrences are schedule authority. Assignment cursor does not pick Today
  for `fixed_schedule`.

## Incomplete past sessions

Eligible unfinished past occurrences may offer:

1. **Train today** — lawful late start or bounded future swap (seven-day
   horizon; ignore already-closed sessions).
2. **Backfill results** — historical capture without pretending it was live
   today. See [Backfill_Fixed_Programme_Session_Results_v1.md](./Backfill_Fixed_Programme_Session_Results_v1.md).
3. **Reschedule** — explicit placement / skip. Not adaptation and not
   automatic cascade.

Rules:

- No automatic skip.
- No automatic cascade onto later sessions.
- Incomplete work does not block today or future sessions.
- Late training uses the **original occurrence**.
- Explicit terminal skip remains distinct from Incomplete.

## Home relationship

Home shows **today only**. Week agenda and month grid live on Calendar, not
Home. Completed today may remain visible on Home.
