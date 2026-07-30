# Session Authority Model v1

**Phase:** 6 Sprint 4  
**Status:** Binding

---

## Concepts

| Concept | Meaning | Mutability |
|---------|---------|------------|
| **Programmed session** | Coach-authored prescription for a Plan version at a week/day (identity: `ProgrammedSessionKey`) | Immutable |
| **Prepared execution** | Athlete-facing package for today: programmed session + optional accepted adaptation + previous-performance attachments | Mutable only via explicit accept / discard before completion |
| **Accepted adaptation** | Derived execution decision referencing the programmed session | Append-only decision; does not mutate programmed source |
| **Completed session** | Durable record of what the athlete performed (`SessionCompletion` + `ExerciseExecutionResult`) | Append-only |

Existing types mapped:

| Concept | Primary types |
|---------|----------------|
| Programmed session | `ProgrammedSessionKey` + resolved `SessionExecutionPlan` structure (plan-canonical) |
| Prepared execution | `PreparedExecutionPackage` / `AthleteGeneratedProgramme` + `GeneratedSessionRecord` |
| Accepted adaptation | `AcceptedAdaptationDecision` on prepared record |
| Completed session | `SessionCompletion`, `ExerciseExecutionResult` |

### Coach authoring content metadata (programme builder)

Stored on `performance_protocols` (column `protocol_id` retained). Domain mapping:

| Conceptual field | DB column | Dart enum / field |
|------------------|-----------|-------------------|
| contentKind | `content_kind` | `TrainingContentKind` (`cohort_protocol` / `session` / `session_template`) |
| authoringScope | `authoring_scope` | `TrainingAuthoringScope` |
| endorsementStatus | `endorsement_status` | `TrainingEndorsementStatus` |
| owner | `owner_id` | `ProtocolDraft.ownerId` |
| provenance | `source_content_*` | `sourceContentId` / `sourceContentKind` / `sourceVersionId` |

Legacy / missing metadata: Dart shim classifies as `session` + `coach_private` + `unreviewed` — **never** as editable Cohort Protocol. Edit/attach permissions enforced by `TrainingContentEditPolicy`.

---

## Object ownership

| Object | Owner |
|--------|-------|
| Plan version / programmed session | Coach (Plan catalog + programmed resolve) |
| Prepared execution | Cohort (preparation) under athlete control |
| Accepted adaptation | Athlete (explicit accept) |
| Completed evidence | Athlete (what they performed) |
| Previous performance snapshot | Descriptive projection of completed evidence |

---

## Source-of-truth hierarchy

1. Plan version + `ProgrammedSessionKey` (planId @ version : week : day)  
2. Accepted adaptation decision (if any) applied only to prepared execution  
3. Completed evidence (never rewrites 1 or 2)  
4. Previous performance display (never rewrites prescription)

---

## Persistence behaviour

- `GeneratedSessionRecord` stores prepared execution for the calendar day, including `programmedSessionKey`, plan version, week/day, and optional accepted adaptation.
- Completions and typed results link to programmed session / Plan version where available.
- Sign-out policy B still clears local athlete aggregates.

---

## Reconstruction rules

Prefer terminology:

- **restore** persisted prepared execution when valid  
- **resolve / reconstruct** programmed session from the same Plan version + week + day  
- **restore accepted adaptation** when persisted  

Do **not** treat reconstruction as permission to generate materially different training.

Valid same-day restore when:

- calendar day matches  
- assignment / plan ids match  
- `programmedSessionKey` matches active cursor (when present)  
- executable blocks exist  

If restore fails: reconstruct from plan-canonical programmed resolve for the same key — not athlete-history-driven invention.
