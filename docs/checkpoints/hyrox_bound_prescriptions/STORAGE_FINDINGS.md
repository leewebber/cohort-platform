# Retained storage and exact production dependencies

2026-10-22. Repository-only inspection; no hosted contact or athlete read/write.

## Existing contracts inspected

| Existing boundary | Actual authority / reuse decision |
| --- | --- |
| [B2 evidence/revisions](../../../supabase/migrations/20260927130000_running_5k_benchmark_evidence.sql) | Owner-scoped append-only identity/revision chains, idempotent commands/fingerprints, authenticated RPC, RLS/revokes. Constraints require exactly 5,000 m, elapsed-including-pauses and completed-five-kilometre declaration. Reuse the revision/ownership design, not these tables or RPCs for 10 km/row/load |
| [B2 selection/ingestion policy](../../../supabase/migrations/20260927140000_running_pace_sql_foundation.sql) | Authenticated eligible-5km reader; exact source policy and caller-supplied civil freshness boundary. Cohort ingestion remains blocked. Do not broaden or relabel to Base evidence/consent |
| [Occurrence snapshot/start](../../../supabase/migrations/20260927150000_occurrence_running_target_snapshot.sql) | Insert-once occurrence/athlete/assignment/training-session links, strict advisory JSON shape, UTC freeze, immutability trigger, explicit role revocation and start-authority transaction locks. Reuse immutable occurrence/atomic-start principles; its v2 running-only advisory aggregate cannot be silently expanded to Base rowing/load prescription |
| [B3 targets versus actuals](../../../supabase/migrations/20260929120000_b3_structured_running_targets_and_actuals.sql) | Existing exact execution mapping and correction/read snapshots retain target/actual separation. No new Base execution mapping, erg runner or load capture authority follows |
| [C1 contracts](../../../lib/domain/performance_tracking/tracking_contracts.dart), [README](../../../lib/domain/performance_tracking/README.md) | Selection/artifact revisions are observational contracts, not production prescription consent storage. Measurements explicitly grant no prescription eligibility; manual declarations cannot fabricate assessment/programme scope |
| [Adaptation acceptance](../../../lib/application/adaptation/programme_adaptation_acceptance_service.dart) | Explicit current prepared-session acceptance with freshness/ownership checks. Cannot store a future-target benchmark selection or change later sessions |
| [Existing local Base benchmark/controller](../../../lib/domain/hyrox_base/base_personalisation.dart), [controller](../../../lib/internal_review/hyrox_base/base_review_controller.dart) | Reused typed validated benchmark and calculation values. Old controller is memory-only, with no programme/assignment binding; retained unchanged. New repository adds compiled binding scope and atomic local handoff rather than claiming those models are persistent |
| [Import payload builder](../../../packages/cohort_plan_package/lib/src/plan_package_import_payload_builder.dart), [application preview](../../../lib/features/authored_plan_package/import/plan_package_import_preview_service.dart), [trusted HTTP endpoint](../../../server/trusted_plan_package_import/lib/src/import_endpoint.dart) | v3 is now explicitly rejected before production import/read orchestration; successful local compile never authorises hosted storage or publication |

The local milestone does **not require a database change**. No migration, schema table,
RLS grant or new production RPC is added. This avoids proposing storage before complete
canonical source identities and production execution contracts exist. The in-memory queue
proves algorithmic ordering and stale-request behavior only; it is not PostgreSQL locks,
authenticated API proof, cross-process durability or production concurrency validation.

## Remaining production-storage work

Before deployment, separately implement and locally validate:

1. Strict v3 server/SQL canonicalisation, dependency resolution and retained-artifact
   admission matching the new Dart vectors; explicit schema/version compatibility at every
   import/publication/materialisation consumer. Keep import guards until these paths are
   ready. Preserve all v1/v2 bytes, hashes, published content and old athlete pins.
2. An authenticated owner-gated Base evidence boundary with exact benchmark definition
   versions, source/type, performed date, canonical units, immutable observation/revision
   identity and complete retained values/provenance. Reuse established append-only and
   idempotency conventions. Known results remain declarations; no invented test attestation
   or freshness default. Corrections need explicit before/after history and no old snapshot
   rewrite. C2/C3 observation validity remains independent of prescription admission.
3. Owner-gated append-only selection/consent revisions binding exact programme/assignment,
   immutable rule/definition/target scope, selected evidence revision/digest, equipment
   configuration version and explicit acceptance chronology. Supplied IDs/hashes or files
   cannot prove auth identity or consent. Cross-owner/replayed/foreign/stale consent must
   fail with no write. Define correction/withdrawal and unstarted-only effective scope.
4. Extend the canonical prepare/start authority with transactionally locked rechecks of
   assignment/version/occurrence/session scope, consent and equipment revisions, then an
   insert-once complete prescription snapshot. Existing snapshot wins only after exact
   owner/scope verification. Demonstrate two real DB transactions in both start/update
   orderings, replay, rollback/no partial write and concurrent duplicate start. Keep
   completed prescriptions and actual/correction audit independently immutable.
5. Authoritative canonical exercise variants/versions and retained complete session bodies;
   prove row work is dedicated intervals, running work-step mappings and squat work sets.
   Implement real prepare/runner/load/erg capture integrations against those exact sources.
   Synthetic fixture identity definitions must never be admitted as canonical exercises.
6. Deny-by-default ACL/RLS, secured-function search paths and minimal grants consistent
   with repository conventions. Prove anon denial, owner-only reads/commands, cross-athlete
   isolation and elevated-role failure cases; re-run local DB replay/compatibility and
   security/readiness gates. No permission repair or release-guard activation is included.
7. Review deployment/rollback, authenticated native/device behavior and separate hosted
   operation authority. No migration is applied or promised by this local checkpoint.

The approved eight-week run/row/squat parameters and benchmark meanings already exist in
[DECISIONS](../hyrox_base_personalisation/DECISIONS.md); do not request their re-authoring.
Genuinely absent inputs are supporting lift/carry/core doses/rest/tempo/cues/progression,
warm-up/cooldown, mixed conditioning and SkiErg/wall-ball/finisher details, exact variants
and authoritative definition versions, full session/capture sources, equipment/prerequisite/
exclusion metadata, and verified division-specific wall-ball standards. Test Week remains
separate and unauthored. These are content/source blockers, distinct from storage design.
