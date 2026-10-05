# Sprint C audit — programme performance-metrics profiles

**Recorded:** 2026-10-05
**Status:** Audit complete; foundation proposal awaiting founder approval.
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

## Recommendation and bounded sequence

Choose embedded schema v3 over a sibling artifact: one content hash already
flows through pins, materialisation, B3 launch and Studio. An independently
hashed sibling would add a second binding to all those consumers. V3 creates
an explicit compatibility boundary while keeping established v1/v2 goldens.
Canonical JSONB on the immutable version row is the verified storage projection.
No published profile backfill, hash rewrite or inferred default profile.

The [proposal](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
contains the complete fields, exact authored/runtime binding, evidence-state
matrix, correction/replay limits, synthetic example and acceptance checks.
Recommended slices are C1 pure contracts/compiler; C2 local persistence and
publication guards; C3 read-only evidence adapter/evaluator; C4 read-only Studio.
Each is separately authorised and accepted. Later athlete presentation is
separate. No full product score, general formula engine, commercial content or
benchmark ingestion is hidden within the foundation.

Only three material founder decisions are requested: canonical v3 storage/hash
choice, prospective profile requirement with legacy compatibility, and bounded
C1–C4 scope followed by separate C1 implementation authority. Real programme
metrics, weights, normative bands and prescriptions are deferred content
choices; there are no HYROX/Bali selections in this audit.

The strategic pause before content creation remains. A+B+C acceptance is a
prerequisite to even proposing HYROX Base authoring, not permission to author.
Sprint D and all hosted/publication/assignment actions remain unauthorised.

## Documentation verification and stop boundary

Local relative Markdown file links in the changed documentation were checked
for existing targets. `git diff --check` passed. The final change is Markdown
only, committed locally on the documentation branch; final clean worktree and
unchanged `origin/main` are verified after commit in the task response.

No implementation, migrations, programme/profile selection, assignment changes,
builds, Flutter suite, local DB gates, hosted contact or push. Future acceptance
tests in the proposal are requirements, not current passes. Existing historic
test/hosted evidence was not rerun. Repository `.env`, `supabase/.temp` and
private athlete state were untouched.
