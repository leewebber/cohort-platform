# Sprint C audit — programme performance-metrics profiles

**Recorded:** 2026-10-05
**Status:** Revised audit complete; founder product clarification recorded;
revised foundation design awaiting approval. C1 implementation PAUSED.
**Revision base:** `8347480c11cfb2b29cb90983f731f87bc251ece0`, clean worktree on
`codex/sprint-c-metrics-profile-audit`. No fetch in this revision;
`origin/main` remains the cached `031edc5da5d0b9961fb5030e0762f15e978e3f32`.
Original fetched-state evidence below belongs to the initial audit.
**Proposal:** [Sprint C foundation architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
**Binding parent:** [Programme_Performance_Metrics_Profile_v1.md](../architecture/Programme_Performance_Metrics_Profile_v1.md)

## Repository and authority evidence

Inspected repository `/Users/leewebber/Developer/cohort_platform`, origin
`https://github.com/leewebber/cohort-platform.git`. Initial branch was
`codex/b4-programme-studio-structured-running`; initial tracked/untracked
worktree status was empty. Initial HEAD and cached `origin/main` both matched
the requested `031edc5da5d0b9961fb5030e0762f15e978e3f32`.
Authorised `git fetch origin main` succeeded; HEAD, fetched `origin/main` and
`FETCH_HEAD` all remained exactly that SHA. No merge or local main change.
The documentation branch is `codex/sprint-c-metrics-profile-audit`, based on
that exact commit. Other listed disposable worktrees were not modified.

Read repository [AGENTS.md](../../AGENTS.md),
[CURRENT_CHECKPOINT.md](./CURRENT_CHECKPOINT.md), metrics parent,
[launch-library architecture and infrastructure sequence](../architecture/Launch_Programme_Library_v1.md),
[product sequence](../planning/Athlete_Product_Completion_Plan_v1.md),
[roadmap](../planning/Delivery_Roadmap_v1.md),
[canonical freeze](../architecture/Canonical_Programme_Architecture_Freeze_v1.md),
[Plan Package authority](../architecture/Authored_Plan_Package_v1.md),
[Studio contract](../architecture/Programme_Studio_v1.md),
[running contract](../architecture/Running_Workout_and_Device_Interop_v1.md),
and relevant CAE identity/history rules. No nested repository AGENTS files
were found. Runtime and committed SQL were inspected locally only.

Current checkpoint and the final sections of the following handoffs take
precedence over their earlier dated implementation/deployment-pending text:

- [B2](./RUNNING_PACE_FOUNDATION_B2_HANDOFF.md): exact canonical v2 running authority, manual benchmark revisions, deterministic arithmetic and immutable occurrence freeze. Cohort-test ingestion explicitly blocked.
- [B3 slice 1](./STRUCTURED_RUNNING_B3_SLICE_1_HANDOFF.md): exact authored-step/executable-block mapping and launch provenance.
- [B3 slice 2](./STRUCTURED_RUNNING_B3_SLICE_2_HANDOFF.md): time-only runner, durable cursor; expiry does not complete a session.
- [B3 slice 3](./STRUCTURED_RUNNING_B3_SLICE_3_HANDOFF.md): per-repetition actual states, target/actual separation and corrections.
- [B3 device closeout](./STRUCTURED_RUNNING_B3_DEVICE_VALIDATION_HANDOFF.md): private TEST ONLY validation; commercial adoption absent; changed-correction audit creation not device-validated.
- [B4](./PROGRAMME_STUDIO_STRUCTURED_RUNNING_B4_HANDOFF.md): visually approved derived review, exact artifact/hash validation and bounded overlap rejection; hosted apply recorded through `20261005120000`.

B2–B4 integration/hosted status above is attributed to committed evidence;
no hosted service was contacted or reverified by this audit. Only Git origin
was contacted for the requested fetch. Commercial content, programme adoption,
benchmark ingestion, distance/manual-lap execution, device integration and
further hosted operations remain outside authority.

## Source trace: reuse versus missing foundation

| Existing source / authority | Reuse | Missing or unsafe assumption |
|---|---|---|
| [Package manifest](../../packages/cohort_plan_package/lib/src/plan_package_manifest.dart), [validator](../../packages/cohort_plan_package/lib/src/plan_package_validator.dart), [canonicaliser](../../packages/cohort_plan_package/lib/src/plan_package_canonicaliser.dart) | Assessments, evidence requirements and comparison identities already participate in canonical hashing; IDs/slot/lineage references are validated | String metric/evidence requirements do not define typed units, method versions, capture scopes, source eligibility, coverage or comparison rules. Assessment evidence text is not a typed evidence-key relationship |
| [Authored import SQL](../../supabase/migrations/20260731120000_authored_plan_package_import.sql) | Version-owned assessment/evidence/comparison rows, service-role import and immutability guards; published/archive forward fixes | No canonical profile or profile-aware publication gate; new profile field must be guarded explicitly, not assumed protected by existing column list |
| [V2 publication SQL](../../supabase/migrations/20260927120000_plan_package_v2_authored_running.sql) | Canonical-byte SHA-256 attestation, payload parity, atomic persisted slot documents | Proven private v2 route does not establish global v3 import/approval compatibility |
| [Backfill/result SQL](../../supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql), [record model](../../lib/features/performance/models/training_session_record.dart), [snapshot model](../../lib/features/performance/models/performance_snapshot.dart) | Stable record/block/exercise/set IDs, athlete/assignment/slot links, actuals and snapshots, live/backfill chronology; occurrence/session version/hash authority | General History DTO is not a complete exact-version/hash/occurrence metrics envelope. Need validated joins through assignment/occurrence/session; older insufficient links cannot be guessed |
| [Correction SQL](../../supabase/migrations/20260904120000_correct_completed_performance_record.sql), [interval correction extension](../../supabase/migrations/20260905121000_correct_interval_performance_record.sql), [correction service](../../lib/features/performance/services/performance_correction_service.dart) | Narrow correction command; append-only before/after audit, stable result identity and completion chronology, authoritative response validation | Current values are mutable; `lastCorrectedAt` is not an immutable input revision. Coherent evaluation and proven as-of reconstruction still needed; no parallel actuals ledger |
| [B3 target/actual SQL](../../supabase/migrations/20260929120000_b3_structured_running_targets_and_actuals.sql) | Server validation of exact repetition identity and occurrence snapshot; actual-only corrections | Frozen target is prescription/advisory evidence, never measured performance; pace unavailable/skipped/partial must stay distinct. Running actuals do not enable Cohort-test ingestion |
| [Programme progress service](../../lib/features/programme/services/programme_progress_summary_service.dart) | Pinned tree and slot-outcome progress counts | Counts terminal required slots, not test completeness or physiological outcomes. Do not use completion label as metric eligibility |
| [Progress builder](../../lib/features/progress/services/athlete_progress_summary_builder.dart), [evidence projection](../../lib/features/progress/services/athlete_progress_evidence_projection.dart) | Programme authority resolution, athlete History facts and existing result comparisons | General athlete evidence is merged; not pinned profile evaluation. Partial sessions are included, history item completion ratio is fixed at 1, and some programme/calendar errors yield placeholders/null. New metric query needs explicit failure/quality states rather than copying these shortcuts |
| [History detail](../../lib/features/performance/screens/training_history_detail_screen.dart) | Actuals, immutable snapshot presentation and correction route | No profile-owned baseline/checkpoint/final projection or derivation provenance |
| [Studio projector](../../lib/features/programme_studio/projection/programme_review_projector.dart), [review JSON](../../lib/features/programme_studio/projection/programme_review_json.dart) | Deterministic read projection, package/artifact/graph verification, coach/technical separation | Assessment contracts can be displayed but no complete profile validation/review; derived JSON cannot author canonical definitions |

No profile implementation was found in the inspected compiler/runtime sources.
Apollo's empty assessment arrays are already documented by the binding parent;
empty arrays are not permission to select real tests or populate metrics.
Existing comparison helpers may supply extraction/validation mechanics after
contract review; session lineage or canonical exercise identity alone does not
prove like-for-like test conditions. Prescription, measured actuals, derived
metrics and coaching interpretation remain separate authorities.

## Founder clarification and revised recommendation

The founder's subsequent instruction supersedes the initial programme-only
proposal at `8347480`: programme profiles are optional; independently selectable
curated profiles and athlete custom compositions use supported metric
definitions; athlete-owned history is reusable across profiles/programmes.
Tracking is observational. Selecting a profile or entering a result cannot
modify programming, insert tests or calculate training targets. Programme test
weeks remain authored; standalone assessment attempts cannot silently change
an active programme. Prescription policy and evidence eligibility remain
separate from tracking eligibility.

The [revised proposal](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
now separates metric definitions, curated profile versions, optional programme
bindings, athlete custom composition/selection revisions, measurement/source
revisions and authored assessment procedures. A single observation can be shown
in several profiles; that does not multiply attempts or imply programme
attribution. Existing recorded results remain authoritative in History and its
correction audit, read through exact source references; future manually entered
results need athlete ownership, provenance and append-only correction revisions.
No duplicate writable actuals ledger is recommended.

Metric identity moves from programme-local ownership to a shared supported
definition registry. Shared identity means a common measurement contract, not a
global fitness score. Profile composition cannot override units, comparability,
source trust or calculation semantics. Cross-profile/programme history reuse
is allowed; comparison still requires compatible exact definitions/procedures
and context. Profile views may narrow eligibility. Older unprovable programme
links prevent programme test claims, not all independent observational display.

Existing-result entry is distinct from actually performing a pinned authored
assessment. Missing provenance, missing/partial/skipped values, unsupported
sources and incomparable conditions remain honest states. Curated profile
examples Longevity/Tactical/Hybrid have no authored membership in this task.
No real HYROX/Bali metrics, weights, bands, profile content or tests are selected.

The source trace above is retained from the initial audit. Its foundations
remain reusable, but a fixed-occurrence-only evaluator and mandatory v3 profile
would unnecessarily exclude independent tracking. No common supported metric
registry, curated/custom composition revision contract or independent reusable
measurement projection was established by that trace; these remain proposed.
The [product plan's deferred Performance Portfolio](../planning/Athlete_Product_Completion_Plan_v1.md)
provides context, not implementation permission. The legacy
[assessment vision](../product/Plan_Assessments_Vision.md) is historical planning,
not test content or a reason to use PlanDefinition runtime.

## Reassessed package/hash and smallest C1

Schema v3 is **not required for C1** or independently selected profiles. Keep
v1/v2 bytes, hashes, published pins and execution unchanged. Definitions and
curated profiles have independent immutable versioned digests. Athlete-owned
custom composition, selection and measurement revisions never affect package
identity. No published profile backfill or companion attachment to old pins.

If later programme-authoring explicitly binds tracking, recommend an optional
v3 binding pinning the profile/definition versions and digests plus exact
authored tests/scopes/windows and programme-owned view rules. Only those authored
bindings and their immutable dependencies participate in the package hash;
athlete selections, evidence, evaluation time and independent curated profiles
are excluded. Programme profiles are optional even for future packages; a
malformed declared binding fails closed. Mandatory profiles and the former
`no_performance_claim` publication rule are withdrawn. Honest programme promise
review remains separately required.

Revised C1 is pure tracking contracts/validation/canonical artifact digests with
synthetic supplied definitions: profile composition/selection, measurement
source/revision and assessment/programme-scope reference values. No compiler
schema change, persistence, production source adapters, derivation engine, UI,
real profiles/tests, formulas or scoring. Acceptance requirements are specified
in proposal §8; no implementation gates were run in this revision. The old
C1–C4 allocation is superseded; future slices must be separately scoped.

Remaining material choices are immutable definition/profile pins versus latest
content, no package change now with optional future v3 binding versus companion
binding, and existing-result references versus duplicate writable measurement
storage. The founder's product direction is already settled. Design approval
and a later explicit resume/implementation instruction are still required;
this documentation revision does not resume C1 or any broader Portfolio work.

B2 safeguards remain unchanged: no promotion of tracking values into benchmark
evidence, no Cohort 5 km ingestion enablement, no automatic training targets,
no changes to manual benchmark eligibility/revisions or frozen occurrence
snapshots. Standalone tests are not programme completion. The strategic pause
before content creation remains; Sprint D/hosted/publication/assignment actions
are unauthorised.

## Documentation verification and stop boundary

Local relative Markdown file links in the changed documentation were checked
for existing targets. `git diff --check` passed. The initial audit and this revision are Markdown
only, committed locally on the documentation branch; final clean worktree and
unchanged `origin/main` are verified after commit in the task response.

No implementation, migrations, programme/profile selection, assignment changes,
builds, Flutter suite, local DB gates, hosted contact or push. Future acceptance
tests in the proposal are requirements, not current passes. Existing historic
test/hosted evidence was not rerun. Repository `.env`, `supabase/.temp` and
private athlete state were untouched.
