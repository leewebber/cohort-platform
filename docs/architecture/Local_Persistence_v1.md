# Local Persistence v1

**Phase:** 6 Sprint 3  
**Status:** Implemented

---

## Technology decision

**Choice:** `shared_preferences` storing JSON **schema envelopes**.

### Why

| Criterion | Fit |
|-----------|-----|
| Typed structured data | JSON payloads inside envelopes |
| Schema versioning | Explicit `schemaVersion` on every envelope |
| Flutter web | Supported |
| Mobile | Supported |
| Deterministic tests | `InMemoryKvStore` + injectable prefs |
| Future cloud migration | Repository contracts; swap impl without feature changes |
| Project convention | No prior local disk layer; Supabase remains for cloud M8 paths |

### Trade-offs

- Not encrypted at rest (documented; MVP limitation)
- Not ideal for very large blobs — acceptable for athlete MVP aggregates
- Single storage system — no Hive/SQLite dual stack

### Rejected for this sprint

| Option | Why not now |
|--------|-------------|
| Hive / Isar | Extra dependency; overkill for small envelopes |
| SQLite / Drift | Heavier migration story; no relational need yet |
| Raw files via path_provider | Weaker web story; more I/O boilerplate |

---

## Dependency direction

```
UI / shells
  → AthleteStateHydrator / AthletePersistence / feature services
    → AthleteLocalRepository (contracts in lib/core/persistence/)
      → LocalKvStore (SharedPreferences or InMemoryKvStore)
```

Widgets must **not** import `shared_preferences` or platform storage APIs.

Cloud Supabase repositories under `lib/data/repositories/` remain separate. Local athlete memory does not call them.

See also: [Local_Persistence_Inventory_v1.md](./Local_Persistence_Inventory_v1.md).

---

## Envelope format

```json
{
  "schemaVersion": 1,
  "savedAt": "2026-07-30T03:00:00.000Z",
  "payload": { }
}
```

Unknown / unsupported `schemaVersion` → fail safely (log + clear affected aggregate). Never silent parse of incompatible data.

---

## App hydration flow

```
main: AthletePersistence.initialize()
  ↓
AuthGate bootstrap (single loading state)
  ↓
Authenticate / resolve local identity
  ↓
Hydrate AthleteProfile
  ↓
Hydrate active PlanAssignment → resolve PlanDefinition from PlanCatalog
  ↓
Hydrate generated session (restore policy) or regenerate
  ↓
Hydrate completions + capability timeline + previous performance
  ↓
Resolve application experience
  ↓
Render AthleteAppShell (optional resume/discard prompt)
```

Widgets must not independently load persisted state.

---

## Restore / reconstruct policy

`GeneratedSessionRestorePolicy.shouldRestore`:

**Restore** persisted prepared execution when:

1. A `GeneratedSessionRecord` exists
2. `intendedTrainingDate` is the same local calendar day
3. Plan has executable blocks
4. If an active plan/assignment exists: `planId` and `assignmentId` match
5. When present, `programmedSessionKey` matches the active Plan version + week + day
6. If no active plan: record is a profile-only session (`planId`/`assignmentId` null)

**Reconstruct** prepared execution from the same coach-authored programmed session key (plan-canonical resolve) when restore fails and an active plan + assignment exist.

Do **not** treat reconstruction as permission to invent materially different training from athlete history or previous performance.

Accepted adaptations restore with the prepared record when persisted; otherwise the original programmed session is reconstructed.

Never invent or silently substitute a different Plan when `PlanDefinition` is missing — show athlete-safe recovery and Browse Plans.

See also: [Session_Authority_Model_v1.md](./Session_Authority_Model_v1.md), [Coaching_Constitution_v1.md](./Coaching_Constitution_v1.md).

---

## Compliance / discipline (deterministic)

`ProgressSummaryService.computeCompliance`:

- **Completed** = count of persisted `SessionCompletion` rows for the athlete
- **Planned-to-date** = `(currentWeek - 1) * recommendedDaysPerWeek + (currentDay - 1)` from the active PlanAssignment cursor
- Does **not** invent future sessions; the cursor already excludes unreached days
- Rest days are not stored as completions; they are not counted as completed
- Sessions before assignment start are not in the completion list for a new assignment
- Partially completed sessions that were finished through Workout Complete count as one completion (using `exercisesCompleted` / `totalExercises` for ratio, not for planned count)
- Abandoned in-progress workouts that are discarded do **not** create completions
- Percentage = `round(completed / max(planned, completed) * 100)` clamped 0–100
- Discipline radar axis uses this percentage when completions exist; otherwise unavailable

Coaching engine logic is unchanged.

---

## In-progress workout restoration

- Snapshot: `WorkoutProgressSnapshot` (session id, exercise/set indexes, completed indexes, timestamps)
- Written on meaningful progress (throttled ~2s) and on app pause
- On reopen: calm dialog — **Resume Training** / **Discard In-Progress Session**
- Safe subset for Sprint 3: discard clears snapshot; resume acknowledges and returns Home so the athlete can relaunch today's session (cursor retained in snapshot for later full player restore)
- Never auto-marks incomplete work complete

---

## Sign-out policy (MVP)

**Option B — clear local athlete training data on sign-out.**

Rationale: safest alignment with current auth architecture; avoids leaving another user's training history on a shared device.

Authentication secrets are never written to this store (Supabase session owns auth).

---

## Encryption

Local storage is **not** end-to-end encrypted in MVP. Do not log full private payloads.
