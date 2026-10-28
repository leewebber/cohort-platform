# M2.5 — Garmin round-trip access and feasibility

Recorded 2026-10-28 (Asia/Makassar). **ACCESS UNKNOWN / NOT VERIFIED; INTEGRATION MISSING.**
A genuine workout-delivery/activity-return alpha cannot be demonstrated with the
access evidenced here. Public Garmin capabilities make it conditionally feasible;
Cohort portal/API entitlement, exact contracts, watch compatibility and a real round
trip remain unproved. This completes the bounded audit, not M2.5 or Gate A.

Founder actions: establish existing application/access status or request Business
Starter access for **Training + Activity**, obtain the gated contracts and actual
terms, and identify the tester watch model/firmware. No action was taken on the
founder's behalf. [Exact actions and official sources](SOURCES.md).

Smallest next implementation: a **local, network-free accepted-workout conversion
and association harness**, using documented FIT semantics and clearly synthetic
fixtures. No guessed Training JSON, OAuth endpoints or webhooks. A live build must
first close the portal contract questions. [Mapping](MAPPING.md) ·
[implementation sequence and acceptance](PLAN.md) · [audit evidence](VERIFICATION.json).

## Actual checkout and retained access evidence

Expected and actual checkout: `/private/tmp/cohort_m11_sources`, clean `main`,
`25b641a78c17fb49349729bde04c2ff54dc6db51` before edits. All 15 commits after
`1cca598ae1eb879405171114f5dced83cb04bb5a` through this base are exact ancestors,
zero merges. The pre-task cached `origin/main` is
`a331f52967e1887c4435cccc8f1ecfa192028cd6`. Its 94-commit count measures only local
objects relative to a stale cache. It does not establish remote ancestry or freshness.
Ordinary fetch fails `Could not resolve host: github.com`; no alternative route or
force push. Publication requires a fresh fetch and actual remote ancestry check.

Inspection covers tracked application/domain code, server/tooling, SQL, dependency
and release/configuration references, retained checkpoint/access claims and the
working checkout's conventional env-file variable names only. No secret values
were printed, tested or copied. No credential store, founder account, email inbox,
external application status or portal session was accessed. Therefore **no retained
access attestation found** does not mean the founder has never applied or holds no
account elsewhere. No pending/approved/rejected application is established.

| Evidence | Finding |
|---|---|
| `lib/features/app_shell/screens/athlete_profile_screen.dart:105` | Connected Devices says Wearables / Coming later. No connection control. |
| `lib/models/{interval,circuit}_data_source.dart` | `importedGarmin` is a provenance enum, not ingestion. |
| `lib/features/session/screens/quality_target_review_screen.dart:320` | Garmin threshold read manually is explicitly manual input, not connectivity. |
| `lib/core/privacy/connected_data_contracts.dart` and Connected Data policy | Allowed metrics contracts only; location/travel fields prohibited. |
| `lib/domain/running_workout/` and `lib/features/session/models/` | Neutral structured model, accepted personalised targets, phone execution; no Garmin transport. |
| `pubspec.yaml`, `.env.example`, `supabase/config.toml`, release configuration, `server/`, `tool/`, migrations | No Garmin SDK/client registration/configured transport/access attestation found in the bounded audit. General Supabase OAuth configuration is not Garmin access. |
| [M0 audit](../m0_alpha_baseline/HANDOFF.md), B1/B2/B3 checkpoints | Planned boundary; no retained Garmin connection, device export or return proof. The prior B3 device test used the Cohort phone runner. |

The running architecture is binding for authority/privacy, with provider deferral
superseded **for release priority only** by the controlling M0–M10 plan. Garmin is
not prescription or programme progression authority. Phone step timing, cloud workout
delivery and watch activity recording are three distinct capabilities; none proves
the other two. No public FIT encoder alone closes either cloud direction.

## Controlling continuity and unchanged gates

Read [AGENTS](../../../AGENTS.md), [current checkpoint](../CURRENT_CHECKPOINT.md),
[controlling release plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M0](../m0_alpha_baseline/HANDOFF.md),
[timed running](../m23_structured_timed_running/HANDOFF.md),
[Zone 2](../m23_personalised_target_admission/HANDOFF.md),
[quality targets](../m23_quality_target_admission/HANDOFF.md) and their
[approved rules](../m23_quality_target_admission/DECISIONS.md),
[M2.4 retry handoff](../m24_terminal_completion_retry/HANDOFF.md),
[running interop architecture](../../architecture/Running_Workout_and_Device_Interop_v1.md)
and [privacy](../../architecture/Connected_Data_Privacy_v1.md).

M2.4's local terminal-replay fix remains retained at `7cc471b`; no tests were rerun
or reclassified here. Preserve the inherited
`test/programme/athlete_runtime_capability_bootstrap_test.dart:124` failure:
expected AthleteAppShell absent, reproduced on immutable base `a67e69c`. It remains
an open alpha-path triage item, not a Garmin access symptom or a waived release test.

Genuine Hybrid10K/father programme source/entry/progression approval and admission,
Lee's separate adjustment, held M1.2/Zone 2/quality/M2.4 migrations and separate
producer authority, actual personalisation adoption, adaptation, movement instructions,
feedback/distribution, authenticated installed-device acceptance and blocking-defect
review remain outstanding. No all-pending schema push or hosted enablement follows.

Documentation only. No application/runtime/schema/dependency edits; no broad test
suite, browser/desktop/equivalent UI automation, account connection, credentials,
application/message submission, purchase, hosted mutation, real athlete data or watch
operation. Retained checkout/file/index/.env/.temp hashes are compared separately.
