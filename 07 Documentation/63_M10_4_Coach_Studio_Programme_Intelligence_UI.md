# M10.4 — Coach Studio Programme Intelligence UI

**Status:** Implemented  
**Depends on:** M10.1 Impact, M10.2 Comparison, M10.3 Migration Planner

---

## Purpose

When a coach opens an existing Programme Version in the editor, the **Programme Intelligence** section surfaces:

- What this version contains (overview)
- Who depends on it (impact)
- What changed versus another version (comparison)
- What would happen if athletes migrated (migration planner)

The UI is **read-only**. It consumes M10.1–M10.3 services without duplicating business logic.

| Layer | Question |
|-------|----------|
| M10.1 Impact | What depends on this version? |
| M10.2 Comparison | What changed between versions? |
| M10.3 Planner | What would happen if assignments migrated? |
| M10.4 UI | Presents the above to coaches |

---

## Architecture

```
ProgrammeEditorScreen
  └── ProgrammeIntelligenceSection
        └── ProgrammeIntelligenceController
              ├── ProgrammeVersionImpactService
              ├── ProgrammeVersionComparisonService
              ├── ProgrammeMigrationPlannerService
              └── ProgrammeVersionImpactStore (lineage version list)
```

Wiring: `ProgrammeIntelligenceServices.createController(versionId:)`

---

## Integration point

`ProgrammeIntelligenceSection` is placed in `ProgrammeEditorScreen` immediately below `ProgrammeEditorHeader`, in a scrollable region above the week editor — mirroring M9.5 `SessionGovernanceSection` placement in the Session builder.

Shown when the editor is in `ready` or `readOnly` state.

---

## Cards

| Card | Component | Service |
|------|-----------|---------|
| Version overview | `VersionOverviewCard` | Impact summary + lineage context |
| Impact | `ProgrammeImpactCard` | `ProgrammeVersionImpactService` |
| Comparison | `ProgrammeComparisonCard` | `ProgrammeVersionComparisonService` |
| Migration planner | `ProgrammeMigrationCard` | `ProgrammeMigrationPlannerService` |

Supporting widgets: `VersionComparisonPicker`, `ComparisonSummaryTile`, `MigrationSummaryRow`, `MigrationAssignmentTile`, `ProgrammeLifecycleBadge`, `ImpactDetailSheet`, `ComparisonDetailSheet`.

---

## Controller responsibilities

`ProgrammeIntelligenceController`:

1. `loadImpact()` on init — also loads lineage versions for picker
2. `selectComparisonTarget(versionId)` — loads comparison + migration in parallel
3. Independent per-card status (`ProgrammeIntelligenceCardStatus`)
4. No calculations — orchestration only

---

## Navigation

Comparison flow:

1. Current version (editor context)
2. Coach selects another version in same lineage via `VersionComparisonPicker`
3. Comparison and migration reload for source → target

Migration planner always uses current editor version as source and selected comparison target.

---

## Loading and errors

Each card loads independently. Impact failure does not block comparison UI (picker still available once impact loads lineage list). Comparison and migration require a selected target.

Friendly coach-facing copy via `ProgrammeIntelligenceCopy`. Separate error states per card with Retry.

Partial comparison/migration plans show warning badges.

---

## Privacy

Coach-facing aggregate data only:

- No assignment UUIDs in UI copy
- No athlete identifiers in migration list (rows labelled "Assignment 1", etc.)
- No raw database IDs in summary messages
- Historical detail limited to aggregate counts in cards; detail sheets show session names and positions only

---

## Visual design

Reuses M9 Governance patterns:

- `CohortCard` + `SectionTitle`
- `GovernanceCountRow` for bullet counts
- Lifecycle badge styling aligned with governance badges
- Bottom sheets with drag handle for expandable detail

No Coach Studio redesign.

---

## Out of scope (M10.4)

- Migration execution
- Publishing / assignment mutation
- AI recommendations
- Upgrade buttons
- Notifications / background jobs

---

## Future migration execution (M10.5+)

- Explicit "Migrate" action gated by action policy
- Assignment replace workflow with coach confirmation
- Post-migration audit trail

---

## Tests

`test/coach_studio/programme_intelligence_widget_test.dart` — loading, errors, impact/comparison/migration rendering, picker, privacy, widget units.

Regression baseline: pre-existing suite failures unchanged (20).
