# M1.1 — genuine alpha programme sources and admission

2026-10-27 (Asia/Makassar). Inspected base:
`1cca598ae1eb879405171114f5dced83cb04bb5a`.
**M1.1 PARTIAL: supported v1/v2 path confirmed; real source admission blocked
pending founder material and approval. Gate A remains open.**

Controlling [M0–M10 release plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M0 baseline](../m0_alpha_baseline/HANDOFF.md),
[M1.2 acquisition](../m12_acquisition/HANDOFF.md).
[Remaining founder inputs](FOUNDER_INPUTS.md) · [hosted proposal](DEPLOYMENT_PROPOSAL.md) ·
[current verification](VERIFICATION.json).

## Decisions and confirmed content brief

Founder will supply both programmes' prescriptions. Hybrid 10K is mostly built
externally; no complete source was supplied in this conversation or found in the
bounded repository inventory. Its agreed shape is ten weeks, four runs and two
strength sessions weekly. That implies 40 run and 20 strength occurrences across
ten weeks at the stated frequency; actual placement and all doses must come from
the source, including any explicit exceptions. No sessions are generated to fill gaps.

Father: founder reports good strength-training experience, home dumbbells/barbells/
bands, three strength days and three spinning classes weekly; intended emphasis is
maintaining strength/muscle and, if possible, building muscle. Founder will build
the plan. This brief establishes neither prescriptions nor clinical suitability.
No exact age, equipment capacities, restrictions, accounts or current assignments
are inferred. Spinning is scheduling context; do not invent or prescribe its classes.

Select existing **retained private v2** for Lee's structured runs, and **v1** for
father's gym programme if its actual content is fully representable. Reassess only
on a specific unsupported source requirement. There is no demonstrated need for
HYROX v3, the deferred approval producer, a new authoring platform or another runtime.
No content-independent runtime change is justified at this point. This deliverable
adds admission/decision evidence only; no Dart, SQL, schema or programme changes.

## Shortest end-to-end paths

| Stage | Lee — Hybrid 10K | Father — home strength | Evidence and exact gap |
|---|---|---|---|
| Source | Founder supplies all ten weeks, run work/recovery/termination and target rules plus two strength sessions weekly. | Founder supplies full initial programme duration, three strength days, doses and authored week-to-week changes. | Current bounded inventory has neither genuine source. Founder authors; software does not fill missing training. |
| Review/admission | Compile v2 schedule, inspect every run's reviewed physical graph, timer, exact block/workout/step mapping and policy. Review strength bodies too. | Compile v1 schedule and complete executable bodies; review every exercise variant, load/reps/rest/unit/group and instruction. Use reviewed graph route if founder-body conversion loses meaning. | Existing compiler and graph reader are reusable. Hash/shape validity is technical admission, not content/suitability approval. Founder must approve exact source and rendered prescription. |
| Publication | Retained private publisher dispatches v2. | Same retained publisher dispatches v1. | Existing SQL/CLI, previously proved on other content. New immutable version, canonical hash and body/scope evidence required; no real publication attempted here. |
| Private access | Exact normal account/version eligibility after authorised M1.2 schema deployment. | Same; no fake coach relationship or ownership transfer. | New table/RPCs locally proved, undeployed. No accounts/recipient rows were inspected or provisioned here. |
| Acquisition/schedule | Normal signup/confirmation/profile → saved timezone setup → Programmes → detail → start date → Get programme — free. Founder uses actual authenticated athlete shell. | Same ordinary journey. | Existing M1.2 implementation. No replacement; another active programme causes refusal. Resolve any real conflict separately without deleting/reassigning training here. |
| Execute | Exact assignment/occurrence → Home/Calendar → atomic create/resume → Workout Player; v2 mapped run steps and frozen target snapshot. | Same spine with block-native strength prescription/capture and owned previous actuals. | Current phone structured runner supports positive time-ended steps only. Distance/manual-lap endings require a demonstrated source-specific implementation; never convert the plan silently. Real benchmark entry/policy adoption remains below. |
| Persist/advance | Draft/restore, atomic completion, authored next slot, corrections and History. | Same; previous results use completed/partially completed owned exercise evidence, never planned loads. | Existing implementation and bounded earlier local proofs. Current focused component checks pass; real sources, failure recovery and efficient use on intended devices remain unproved. |
| Restart | Restore same account, immutable assignment, schedule, run snapshot/cursor/draft and progress. | Restore same selection, strength draft/sets and progress. | M1.2 has earlier synthetic authenticated restart proof. Full joined genuine-programme process-death/logout/second-account matrix is M1.3/device work; not closed here. |

Implementation anchors: [compiler](../../../packages/cohort_plan_package/lib/src/plan_package_compiler.dart),
[private publisher CLI](../../../tool/programmes/bin/publish_private_exact_version.dart),
[graph inspector](../../../lib/features/private_programme/reviewed_protocol_graph_artifact.dart),
[founder-body builder](../../../lib/features/private_programme/private_protocol_graph_builder.dart),
[retained SQL](../../../supabase/migrations/20261005140000_tracking_publication_artifact_retention.sql),
[acquisition SQL](../../../supabase/migrations/20261026110000_training_setup_private_alpha_acquisition.sql),
[phone runner](../../../lib/features/session/services/structured_running_controller.dart),
[previous strength selector](../../../lib/features/performance/services/previous_strength_performance_selector.dart).

## Personalised running: the precise decision boundary

The existing B2/v2 path separates authored intent, versioned calculation policy,
athlete benchmark evidence, immutable per-occurrence frozen targets and actuals.
It can calculate explicit pace bands from eligible completed **exact 5 km** test
evidence. This is percentage-of-benchmark-speed arithmetic, not automatic threshold
or physiological-zone inference. Every numerical attachment needs approved scope,
method and band; existing test-only B3 percentages are not Hybrid 10K approval.
Review source intent and the existing [B2 contract](../../architecture/Running_Pace_Foundation_B2_Implementation_v1.md)
before choosing policy. Retained rules do not imply adoption for this programme.

Server manual completed-5 km evidence recording exists. The retained B3 entry is
development/internal-tools only, with B3 provenance; it is not ordinary production
onboarding. The separate Base/v3 benchmark review screen does not establish a v2
entry path. M1.2 currently asks only for timezone, not relevant running evidence.
If the supplied plan requires calculated v2 pace, the smallest likely follow-up is
normal athlete-owned entry/selection of that approved evidence using existing B2
authority, with restart/error/account tests. Do not add it before knowing whether
the actual source uses this method, fixed paces, effort, HR or another prescription.

Cohort completion ingestion is fail-closed; arbitrary logged distance or a Garmin
activity is not automatically eligible B2 evidence. Missing/stale evidence freezes
an explicit intent-only snapshot; later evidence does not silently change that
started occurrence. Decide required pre-start behaviour in the actual review.
Personalised targets and all-run execution remain open until those requirements
are admitted and tested. The neutral running model's ability to encode distance
does not prove phone distance execution or Garmin export.

## Retained material and authoring tools

Bounded search covered all tracked files under `tool/programmes`,
`content/programmes`, `docs/programmes`, the Studio source registry/coverage and
the actual importer/publisher/graph tools. It is not a search of private external
documents or hosted athlete data. Exact inventory/hashes are in VERIFICATION.json.

| Material/tool | Reusable part | Admission limit |
|---|---|---|
| Bali package + Founder YAML | Paired schedule/body layout, strength capture/groups, private publication artifact example. | Eight weeks/71 sessions, endurance-led and explicitly no running; different purpose/frequency. No automatic reuse for either athlete. Founder-body builder emits `timer_config: null` and maps only selected prescription fields; technical success does not guarantee full source fidelity. |
| Apollo package/implementation source + SQL | Authored schedule, detailed strength and conditioning review examples. | Different 12-week programme, prior scoped approvals only. Existing review findings remain; no relabelling as Hybrid 10K or father programme. |
| Spartan Week 1 YAML/package | Import schema, strength/set examples and dry-run tests. | Partial/different programme, legacy withheld status; not a suitable approved father plan by inference. |
| B3 device v2 package + reviewed JSON graph | Exact compiler/graph/mapping/target plumbing and time-based test precedent. | Four short TEST ONLY occurrences, not training or approved numerical policy. |
| HYROX Base retained source | Separate reviewed source/decision packet and 48 sessions. | Different programme and authority; no downgrade, copied policy or v3 producer prerequisite. |
| Shared compiler/importer + reviewed graph reader | Local parsing/validation, canonical schedule hash, complete graph and stable identity checks; existing tests exercise these without network. | Direct importer CLI constructs a hosted client even for its dry-run path; use pure parser/compiler/in-memory tests for local admission. The publisher is a real write command, not an offline checker. |
| Studio review/composition/editable/canonical intake | Read-only inspection of retained sources; bounded synthetic editing and strict source transport. | Fixed synthetic profiles/lineages and supported straight-set shapes. Cannot admit arbitrary real plans by renaming fixtures. TAR/workspace validity supplies no founder approval or publication authority. |

For a real source, prepare exact canonical YAML, complete executable graph and
human-readable session review using existing tools; retain raw source and its digest.
Compare every source field with what will display/execute/capture. Any omitted or
lossy field is an admission finding, not permission to simplify it. Approve exact
versions and body digests separately from compiler hashes, which exclude bodies
under fixed references. Do not run repair utilities against old published graphs.

## What can proceed and what is still open

Completed independently: implementation trace, retained source/tool inventory,
103 focused existing tests, M1.2 manifest/hash comparison, hosted proposal and
preservation checks. Earlier M1.2 fresh/replay GoTrue/SQL proof, six safety groups
and 362 inherited analysis findings are attributed to that immutable checkpoint;
they were not rerun here. No fresh full analysis or DB/architecture suite is claimed
for this documentation-only change. See VERIFICATION.json for exact checks/limits.

Next independently possible work is local source transcription/admission **once
the founder supplies it**, listing unresolved content without inventing answers.
No completed athlete-ready source, suitability approval, real benchmark, current
hosted availability, real account/eligibility, publication, assignment, installation
or device acceptance is claimed. No browser, desktop, AppleScript or equivalent
control was used; no hosted application system was contacted.

Original dirty checkout, registered worktrees, M1.2 clone, raw indices and `.temp`
were hashed before/after and preserved. A separate task-owned local clone at
`/private/tmp/cohort_m11_sources` holds this evidence on local `main`; no managed
worktree was created/archived/pruned and no global settings changed. Initial ordinary
GitHub main check failed DNS resolution. No network workaround/escalation/retry was
attempted; remote freshness/publication remains unverified and this commit is local.

**Next single milestone point: finish M1.1 real-source admission.** Founder supplies
the mostly built Hybrid 10K source first; produce its exact gap list and reviewable
v2 candidate while founder builds the father's source. Neither programme is usable
until source/approval, any demonstrated runtime gap, separately approved hosted
schema/publication/recipient operations, ordinary acquisition and real-device proof
are complete. Then M1.2 benchmark adoption/M1.3 continuity follow on those versions.
Gate A still includes M2.5 Garmin delivery **and activity return**, M3 equipment/time/
recovery/individual-swap adaptation, and M4 distribution, authenticated device acceptance,
movement guidance, feedback and blocking-defect sign-off. No later milestone starts here.
