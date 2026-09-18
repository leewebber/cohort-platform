# Content relationship type registry v1

Binding companion to [`Content_Relationship_Graph_and_Versioning_v1.md`](./Content_Relationship_Graph_and_Versioning_v1.md).

| Type | Source | Target | Cardinality | Order | Version semantics | Retirement | Ownership | Authored/derived | Audit |
|------|--------|--------|-------------|-------|-------------------|------------|-----------|------------------|-------|
| `exerciseUsedByBlock` | Exercise `EX-*` | Authored block | 1..n / 1 | block position | pinned at session revision publish | retain | session owner | authored | yes |
| `blockBelongsToSessionTemplateVersion` | Block | Session revision | n:1 | position | revision-scoped | cascade with draft only | session owner | authored | yes |
| `sessionTemplateVersionUsedByPlacement` | Session revision | Placement | 1:n | week/day/slot | programme version snapshot + source id | retain | same namespace | authored | yes |
| `placementBelongsToProgrammeVersion` | Placement | Programme version | n:1 | week/day/slot | version-scoped | with version | programme owner | authored | yes |
| `programmeVersionBelongsToProgramme` | Version | Lineage | n:1 | `version_number` | monotonic | retain lineage | programme owner | authored | yes |
| `programmeVersionSupersedes` | Newer version | Prior version | 0..1 | monotonic | auditable | retain | same lineage | authored | yes |
| `programmeVersionRequiresEquipment` | Version | Equipment token | n:n | n/a | snapshot | retain | owner | authored | optional |
| `targetsCapability` | Session/programme version | Capability tag | n:n | n/a | snapshot | retain | owner | authored | optional |
| `authoredBy` | Content version | Publisher | n:1 | n/a | attribution immutable | retain | namespace | authored | yes |
| `assignmentPinnedToProgrammeVersion` | Assignment | Programme version | n:1 | n/a | pin at enrolment | never rewrite | athlete | derived | yes |
| `occurrenceDerivedFromPlacement` | Occurrence | Placement | n:1 | schedule | assigned version | retain | assignment | derived | yes |
| `executionPlanDerivedFromAssignedContent` | Prepared plan | Assigned version | n:1 | n/a | hash-checked | retain | assignment | derived | yes |
| `evidenceReferencesExerciseAndSlot` | Set/exercise result | `EX-*` + slot | n:1 | n/a | historical | retain | athlete | derived | yes |

Display names are never keys.
