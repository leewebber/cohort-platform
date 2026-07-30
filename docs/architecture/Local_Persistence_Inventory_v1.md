# Local Persistence Data Inventory v1

**Phase:** 6 Sprint 3  
**Storage:** `shared_preferences` JSON envelopes via `AthleteLocalRepository`  
**Schema:** all aggregates at `schemaVersion: 1`

---

## Aggregates

| Aggregate | Key pattern | Schema | Retention / clear |
|-----------|-------------|--------|-------------------|
| Athlete profile | `cohort.athlete.v1.{id}.profile` | 1 | Cleared on sign-out (policy B) |
| Plan assignment | `…plan_assignment` | 1 | Cleared on sign-out; cleared when no active plan |
| Generated session | `…generated_session` | 1 | Cleared on sign-out; overwritten daily |
| Session completions | `…completions` | 1 | Cleared on sign-out; chronological list |
| Capability timeline | `…capability_timeline` | 1 | Cleared on sign-out; deduped by `eventId` |
| Previous performance | `…previous_performance` | 1 | Cleared on sign-out |
| Exercise results | `…exercise_results` | 1 | Cleared on sign-out |
| Workout progress | `…workout_progress` | 1 | Cleared on complete/discard/sign-out |
| Last local athlete id | `cohort.athlete.v1.last_local_athlete_id` | n/a | Cleared when that athlete is cleared |

---

## Envelope

Every aggregate (except the last-id pointer) is wrapped as:

```json
{ "schemaVersion": 1, "savedAt": "<ISO-8601 UTC>", "payload": { } }
```

Unsupported `schemaVersion` → log + clear that key only. App continues.

---

## Sign-out policy

**B — clear local athlete training data** on sign-out via `AthletePersistence.clearForSignOut`.

Auth secrets are never stored in this layer (Supabase session owns auth).

Local storage is **not** end-to-end encrypted in MVP.
