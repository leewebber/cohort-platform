# Exact internal source and identity authority

The founder selected the existing author-approved Apollo internal implementation
reference and, in this task, explicitly permitted **scoped local repository row snapshots**.
This grants no commercial approval, current hosted-state claim, publication or assignment.
[Launch strategy sections 7/11](../../architecture/Launch_Programme_Library_v1.md) exclude
Apollo from the commercial first library; HYROX Base stays first. The prior
[coverage matrix](../programme_studio_source_coverage/COVERAGE.md) remains binding.

## Source pin

- Approval commit: `19648d746025ff7245725c8b66af315b55695d70`, whose only file was
  [Apollo implementation source](../../../tool/programmes/apollo_build_12_week_implementation_source.md).
  Section F explicitly supersedes earlier UNRESOLVED markers; final status is
  **AUTHOR APPROVED — READY FOR COHORT IMPLEMENTATION**. Approved original bytes:
  SHA-256 `cc11f022993da70b7ab4f17fe85e21c7b6bcbdd59bc3cc4af5509b510805df5e`;
  Git blob `4685ae0ff4f8018af0064b1dc7c55b4fe75f5a32`.
- Retained source differs only through the recorded founder calendar correction
  `63ff4392e69a42e8637923ed2c156ef711f05919`: Engine/quality day 2, Base day 4
  in weeks 1–11, original weekday-coded protocol IDs retained. Its schedule notice
  explicitly names package v2. Current source SHA-256
  `72ec0f3131860c79f887e696146887f434b747ea702117f30a003466d1fe1f7c`,
  Git blob `319df02b5d67cdda04ebe4c65d7204df6ae67f91`. The selected Saturday
  prescriptions and section F10 rest/tempo guidance are unchanged by that correction.
- Existing [package](../../../tool/programmes/apollo_build_12_week_v1.plan-package.yaml)
  is **version 2** despite its retained filename. File SHA-256
  `dfd7d1faec93d236fc127b654575fcd0a290914145590d482cc7f98dd4192f43`;
  established canonical package hash
  `810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`;
  programme-version artifact `2ba018bd-7dc2-4dfd-8d8e-e35823158920`.
- Body authority is the unchanged ordered [SQL correction chain](../../../lib/features/programme_studio/projection/apollo_sql_artifact_chain.dart),
  not a new markdown-to-prescription interpreter. The Week 4 insertion was committed
  as `0076c3089d7ea24bbf3dffbaebe4a3b2a490f9a4`. All 12 inserts and five
  corrections are pinned, alongside package, publication evidence, source document
  and the existing Wave 1 row definitions: **21 exact files** in [SOURCE_PIN.json](SOURCE_PIN.json).
  All raw bytes travel with the local pilot; they are never modified or executed as SQL.

## Selected session

`APOLLO-W4-SAT-R1`, lineage `a1400006-0000-4000-8000-000000000006`, revision 1;
package session `SES-APOLLO-W04-SAT`, slot `APOLLO-W04-SAT-S1`, Week 4 Saturday
(day 6), workout 1, **Apollo Athletic**. Section F8 supplies the resolved reduced-fatigue
session. It is a small representative two-block session with five preparation and five
main movements, no conditioning, assessment, capture or timer editor requirement.
It exercises the actual coverage gap: exact/range/per-leg reps, RIR, rest ranges and
read-only distance, with fully renderable corrected preparation. No other week/session
is admitted by the pilot. Local lineage `studio.local.apollo.w4.sat` and protocol IDs
`LOCAL-APOLLO-W4-SAT-R1`, `…R2`, etc. are working-copy identities, never original
protocol revisions or publication-ready UUIDs.

## Scoped local exercise profile

`cohort.apollo-local-row-profile.v1@de0f481d86c99c6540e1c2ba26b21e535a6c1d1e`.
Each binding is **exact EX ID + repository snapshot Git revision + complete SQL row
SHA-256**, backed by the complete pinned source file. Names are display labels; source
labels such as Walking Dumbbell Lunge do not become identity mappings.

| Exact IDs | Retained definition-row evidence |
| --- | --- |
| EX-079, EX-101, EX-122 | [Founder Wave 1 SQL](../../../supabase/migrations/20260724140000_founder_exercise_library_wave1.sql), existing canonical published rows |
| EX-025, EX-059 | [Apollo Week 1 SQL](../../../supabase/migrations/20260821120000_apollo_build_week1_executable_protocols.sql), explicit existing-canonical reuse guard and deterministic row seed; matches approved [Phase 3.1F mapping identities](../../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md) |
| EX-155, EX-159, EX-162, EX-163, EX-164 | [All Apollo preparation correction](../../../supabase/migrations/20260825120000_structure_all_apollo_warmups_and_athlete_details.sql), explicit published-row definitions and ordered templates |

Complete rows, paths and individual hashes appear in SOURCE_PIN. These are historical
local SQL row snapshots, **not canonical ExerciseDefinition versions or a live catalogue**.
`exercises_v2` has no version column, as recorded in
[Phase 3.1F Part 1](../../architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md).
No canonical definitions are manufactured from default version 1, mapping versions,
text-guidance seeds, content-graph adjacency or the ignored review-only catalogue export.
No global resolver, canonical catalogue, fixed synthetic profile or trusted definition
consumer is changed. Unknown/missing/changed/ambiguous rows or source files fail closed.
Real canonical publication would still require its authoritative versioned definitions
and normal publication authority; this pilot cannot supply either.
