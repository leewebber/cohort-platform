# HYROX Base — source decision brief

2026-10-21 · repository inspection base `e78ce7e25e1de50fb60d67a932105d8b587d98e8`.
**Ready for a founder source/brief decision; not ready for content approval or publication.**
No complete or partial commercial HYROX Base prescription candidate was identified in
retained tracked repository evidence. Source path, source version and source SHA-256
are **absent**, not guessed. The brief below contains established requirements and
explicit gaps, not newly authored commercial prescriptions.

## Established direction

The founder-resolved [launch strategy §7](../../architecture/Launch_Programme_Library_v1.md#7-founder-resolved-launch-catalogue-2026-09-25)
is the current family/build-order authority. [Roadmap](../../planning/Delivery_Roadmap_v1.md)
and [product plan §4](../../planning/Athlete_Product_Completion_Plan_v1.md#4-launch-programme-library)
retain the launch-library milestone and quality requirements.

| Item | Established requirement | Missing family-specific detail |
| --- | --- | --- |
| Priority | HYROX Base is first; Pro Performance, First Race, Performance follow sequentially | No resequencing decision needed |
| Duration | **8 weeks** | Exact phases, authored progression/recovery and assessment placement |
| Goal | Physical preparation **before race-specific training**: aerobic development, running durability, foundational strength, tissue resilience, movement quality, erg technique, controlled race-specific introduction | Session prescriptions, progression, honest outcomes and boundaries |
| Audience | The general launch user is an individual hybrid athlete combining strength/endurance, without a required assigned coach | Base-specific entry level, prerequisites, exclusions and suitability; do not assume sedentary/beginner or Pro eligibility |
| Schedule | Fixed authored programme; product-level schedule flexibility does not rewrite its prescriptions | Training days/sessions per week, day/slot ordering, rest, doubles/optionality, weekly time commitment |
| Equipment | Truthful authored equipment/prerequisites are required by launch metadata contract §6 | Base kit and any authored alternatives; the product's general full/limited/home intent is not an approved Base variant |
| Content authority | Programme prescriptions need their own explicit founder approval | No Base source, editorial review or content-authoring approval is supplied by this engineering task |

The old product-plan proposed families (Hybrid Foundation 12w/4d, HYROX Foundation
12w/4–5d, Intermediate, Advanced) are **planning**, not an eight-week Base source.
Strategy §7 explicitly supersedes the old audit's Hybrid Foundation-first/Apollo-commercial
recommendation. None of those durations, frequencies or prescriptions is carried into Base.

## Retained candidates and exclusions

[Exact evidence pins/search inventory](SOURCE_INVENTORY.json) records 18 evidence-file
hashes, Git blobs and last-change commits at the inspection base, 107 tracked HYROX text
matches and zero HYROX filename matches. Searches include docs, tool sources, content,
lib, SQL, packages, tests and retained `07 Documentation`. Filename/text matching is
only discovery; it cannot establish identity, content authority or completeness. This is
not an external-document or hosted survey. Original untracked files remain protected
and are not silently admitted as content authority.

| Retained material | Classification and reason |
| --- | --- |
| Launch strategy §7; Studio planned-family registry `hyrox-base` | Approved **requirements/planned family**; registry explicitly has no authored sessions, weeks or metrics |
| Product plan §4 tables and early launch audit | Proposed/superseded planning, not a candidate prescription source; keep historical records intact |
| `TMP-006` HYROX Mixed Conditioning in [template seed](../../../supabase/migrations/20260730150000_seed_cohort_session_templates.sql) | Generic session template with prose station circuit, no complete eight-week programme or exact station dose/bindings; [M9 identity review](../../architecture/M9_Exercise_Identity_Review_v1.md) records unresolved template identities. Not promoted to Base approval |
| Apollo v2 source/package/SQL and published internal pilot | Internal implementation authority only. Neither personal prescriptions nor the pilot's local edits are commercial Base content approval |
| Bali Hybrid Base | Private, Lee-specific content with separate authority; not commercial Base; personal history is not used to fill any gap |
| Spartan; Plan Library/Coach Brain; examples/tests/preview catalogue facts | Legacy withheld, quarantined generative paths or software fixtures; no Base prescription authority |

**No candidate was rewritten, converted, relabelled, assigned or published.** No full
commercial programme, session doses or metrics selections were generated.

## Complete missing-input inventory

Because no candidate exists, the session/movement counts and detailed construct mix are
unknown. Empty machine findings mean **not assessed**, never zero missing prescriptions.

| Layer | Input needed for a complete candidate |
| --- | --- |
| Source/provenance | Retained complete file(s), author, explicit revision/version, exact bytes/digest and documented authority/scope; distinguish permission to draft/review from approval of final content |
| Programme facts | Audience/level/prerequisites/exclusions; truthful goal/description, 8-week duration, frequency/time, equipment and any variants |
| Schedule | Every week/day/slot/session, training/rest/optional/double semantics, phases and intentional omissions; exact immutable session references |
| Every session body | Ordered warm-up/main/cooldown blocks; exact exercise choices/bindings; sets, rep forms/ranges/per-side work, load/effort, rest/tempo/cues and any deliberate unspecified fields |
| Running/erg/mixed work | Authored duration/distance/units, work/recovery/repeats, effort/target semantics, capture/scoring and station standards where used; supported structured encoding rather than ambiguous prose |
| Across weeks | Authored progression, recovery/deload and transitions; no software-derived progression, target inference or automatic recalculation |
| Policies | Explicit substitution/equipment and adaptation/missed-session policies, or an authored decision that a policy is not offered; acceptance affects only the current prepared session |
| Assessment/evidence | Explicit tests/assessment placement, retained measurement/comparability contracts and honest Progress/History claims if offered; no inferred metrics or prescription eligibility |
| Launch quality | Editorial/coaching review, exercise demonstration rights/coverage, support material, actual production-path/device evidence and forward-fix/rollback plan under strategy §10; this package does not close these gates |

## Exercise identity evidence: resolved history versus remaining gap

[Founder-approved mapping decisions](../../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md)
and the [accepted bridge seed](../../../lib/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart)
resolve all 21 transitional references exactly once. The current checkpoint records
Phase 3.1 complete, the 132-row catalogue seed applied and the first consumer accepted;
older Part 1 missing-row/Part 2 predeployment flags are historical. No current hosted
state is claimed here.

Relevant existing identities include Running `EX-129`, Row Erg `EX-049`, Ski Erg `EX-050`,
Burpee Broad Jump `EX-130`, Sled Push `EX-131`, Sled Pull `EX-132`, Farmer Carry `EX-101`,
Walking Lunge `EX-025` and Wall Ball `EX-052`. These are **available identity decisions,
not a selected Base exercise list**. Do not re-request already resolved sled/BBJ identity
creation. SkiErg device/protocol, wall-ball load/height/category/scoring, running intensity
and lunge/carry variants still require exact source prescription/context; a shared ID
does not establish substitution or comparison authority.

Still absent: Base's actual exercise roster, exact source references, intended variants,
authoritative published definitions and any required version bindings for the chosen
canonical authoring boundary. The operational SQL catalogue has no definition-version
column. Neither its review export, a mapping's version nor Apollo's row snapshot creates
a canonical ExerciseDefinition version. New/ambiguous source references must fail closed
through the existing identity path; no names, adjacency or similarity may fill them.

## Readable review and publication compatibility

No Base source means package/body/identity/renderability **not assessed**, rather than
failed compilation or proven unsupported content. The [coverage matrix](../programme_studio_source_coverage/COVERAGE.md)
remains the technical starting point, not evidence that all Base constructs are supported.

- Existing PlanPackageCompiler validates schedule/contracts and stable canonical identity;
  Plan Package v1 carries no exercise IDs or session doses. Keep schema/hash contracts frozen.
- Executable prescriptions belong in existing protocol/Founder authoring sources. The
  [accepted first-consumer path](../../architecture/Phase_3_1_First_Consumer_Founder_Programme_Import_v1.md)
  resolves explicit transitional IDs via the repository bridge to caller-supplied published
  canonical definitions before any write. This check performs no import or publication.
- Existing readable movement review retains ranges, RIR, duration/distance, rest, loads
  and limitations. Generic Founder mapping can still lose unsupported compact fields;
  prove source-preserving representation and every distinct block/timer/capture type on
  the actual candidate. Never flatten into synthetic straight sets to obtain a pass.
- Apollo's pilot envelope and row-snapshot profile remain explicitly local. Synthetic
  workspace/TAR profiles remain fixed. Neither is a canonical Base publication input.
- After a source is selected, assess exact representability without rewriting doses;
  list unsupported constructs before allocating a specific extension. Publication remains
  separate compile/import/review/explicit lifecycle operations, with immutable corrections
  and unchanged existing athlete pins. No publication compatibility pass is available now.

## Smallest founder decisions

1. **Choose the prescription-source route.** Supply an existing complete eight-week Base
   candidate (exact file(s)/revision and owner), if it exists outside this repository, for
   read-only review. If no candidate exists, name the author and separately authorise a
   bounded content-drafting brief; no commercial programme has been drafted here. A new
   content-authoring decision must explicitly address the roadmap's still-open A/B/C
   founder-acceptance prerequisites; this engineering report does not waive them.
2. **Complete the brief for that source/author:** Base-specific audience, prerequisites/
   exclusions, sessions/days per week and intended equipment/variants. Preserve the already
   approved eight-week preparation goal and first-library priority unless explicitly changed.

**Later, against actual bytes:** review the completed prescriptions and exact identity/
representation exceptions, then explicitly approve/reject that version for the named
operation. An absent candidate cannot receive a concrete content approval. Hosted
publication, assignment and device work remain separate decisions and are not requested
by this package. Broader Stage 2/Sprint C, founder usability and browser/phone checks stay open.
