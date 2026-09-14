# Athletic circuit and EMOM capture

**Status:** Implemented on the production athlete path at `969ef5b`  
**Design history:** [`07 Documentation/39_Circuit_Execution_Engine.md`](../../07%20Documentation/39_Circuit_Execution_Engine.md) (v0.1 design; implementation now exists)

## Canonical score

For EMOM, `completedRounds` is one timed interval (usually one minute).
Athlete-facing copy is **intervals**. Example: 8 min / 60s → 8 intervals.
Station specs are prescription templates (for example two movements), not
one occurrence row per minute.

There is no competing EMOM score field and no new `capture_mode` column.

## Player behaviour

- Start timer is optional.
- Record result without timer is valid before the timer starts.
- After the timer starts, End and record result opens the result surface.
- Timer finish does **not** auto-complete the block or session.
- Cancel does not complete.
- Partial / ended-early outcomes must remain truthful.
- Timer configuration persists on the execution plan so restore cannot drop
  stations while the content text still names them.

Backfill uses the same result surface.

## Production vs preview

Production: `lib/main.dart` → `active_session_screen.dart` /
`emom_result_capture.dart`.  
Preview only: `lib/main_emom_result_preview.dart` (local convention port
4183). That entry must not be a production `-t` target.
