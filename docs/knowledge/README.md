# Knowledge Layer documentation

Phase 3 design and machine-readable ontology (independent of UI and Supabase schema).

| Document | Purpose |
|----------|---------|
| [Knowledge_Blueprint_v1.md](./Knowledge_Blueprint_v1.md) | Semantic model and philosophy (Sprint 1) |
| [Vocabulary_Reconciliation_v1.md](./Vocabulary_Reconciliation_v1.md) | Blueprint ↔ platform vocabulary mapping (Sprint 2) |
| [Exercise_Curation_Playbook_v1.md](./Exercise_Curation_Playbook_v1.md) | How to curate YAML reference data |
| [Knowledge_Read_Seam_v1.md](./Knowledge_Read_Seam_v1.md) | Read-only ports and wiring guidance |
| [Capability_Ontology_v1.md](./Capability_Ontology_v1.md) | Athletic capability philosophy and hierarchy (Sprint 3) |
| [Capability_Model_Guide_v1.md](./Capability_Model_Guide_v1.md) | Curation guide for capabilities and exercise mappings |
| [Capability_Gap_Analysis_v1.md](./Capability_Gap_Analysis_v1.md) | Gap analysis evidence, scoring, and read seam (Sprint 4) |
| [Training_Intent_Ontology_v1.md](./Training_Intent_Ontology_v1.md) | Goal → capability → intent → archetype layers (Sprint 5) |
| [Training_Intent_Guide_v1.md](./Training_Intent_Guide_v1.md) | Curation and mapping guide (Sprint 5) |
| [Programme_Semantics_v1.md](./Programme_Semantics_v1.md) | Programme hierarchy and phases (Sprint 6) |
| [Programme_Semantics_Guide_v1.md](./Programme_Semantics_Guide_v1.md) | Periodisation curation guide (Sprint 6) |

## Machine-readable ontology

**Location:** [`knowledge/`](../../knowledge/) (repo root)  
**Version:** **1.3.0** (programme semantics Sprint 6)

| Path | Role |
|------|------|
| `manifest.yaml` | Version, schema paths, reference file index |
| `schemas/` | Field definitions for entities, exercises, substitutions |
| `reference/` | **Representative** curated YAML — incomplete vs full exercise library |

**Validation:** `flutter test test/knowledge/`

**Dart:** `lib/knowledge/` (models, loader, validator, in-memory reader, gap analysis)  
**Ports:** `lib/application/ports/knowledge_graph_reader.dart`, `capability_gap_analysis_reader.dart`, `training_intent_resolution_reader.dart`

**Gap scenarios:** `knowledge/reference/gap_analysis_scenarios.yaml`

> The reference dataset (~20 exercises) exists to prove the schema. Production coaching content remains on platform `Exercise` / Protocol records until migration.

## Phase 4 recommendation

- **Coach Brain input contract** — structured bundle: ranked gaps, training intents, active phase, recommended blocks, week type
- **Session generation adapter** — archetypes → session skeletons (still no automatic exercise library picks without policy)
- **Scheduling layer** (optional) — map semantic durations to calendar only when product requires it
- Athlete evidence persistence + fatigue budget parser for YAML fatigue strings
- CI gate on `knowledge/` PRs

## Phase 3.5 — Planning architecture

Canonical blueprint: [../architecture/Planning_Engine_v1.md](../architecture/Planning_Engine_v1.md) (ADR-023–027). Phase 4 implements contracts — no duplicate ownership of gap ranking or exercise selection.
