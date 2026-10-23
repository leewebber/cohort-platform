# Prepared deployment/configuration instructions — not executed hosted

Follow the preceding [authoritative deployment prerequisites](../hyrox_authoritative_start/DEPLOYMENT.md).
The application milestone resolves that handoff's review/runner code dependency only.

1. Obtain separate authority for the exact hosted project and operations. Inspect its current
   ledger, server bodies/default grants, ACL/RLS and producer role graph. Do not infer its
   state from dated checkpoints or use a blind linked database push. Reconcile every required
   earlier migration from the immutable inventory before approving a target-specific apply.
2. After approved prerequisites, apply exact transactional
   `supabase/migrations/20261023130000_v3_athlete_review_state.sql`. It introduces an
   authenticated owner-only state read, immutable-target record guard, bound interval
   dose/unit guard and additive seconds/500 m result canonicalisation. It seeds no content,
   changes no default privileges and provisions no producer. Compare its SHA to MIGRATIONS.json.
3. Under separately approved SELECT-only postchecks, run the preceding metadata checks plus
   POSTCHECK.sql here. Verify no PUBLIC/anon/service EXECUTE on the state reader/guards,
   existing canonical start/B2 body equality, required triggers and immutable retention/RLS.
   Check any existing v3 performance records for exact retained packet compatibility before
   client enablement. Never backfill targets by recalculating from current benchmarks.
4. Configure and separately provision the verified publication producer/capability, actual
   approved full definition versions/events/kind approvals and Founder-authenticated v3
   facade transport. No usable membership, HTTP route or real publication was enabled locally.
5. Transfer/consolidate the partial supporting source into exact approved session bodies,
   canonical versions/bindings and coaching/capture fields. Validate every actual shape through
   server admission and existing runner. A complete 48-session package, Test Week and verified
   race mappings remain absent; do not manufacture them or adopt the synthetic fixture.
6. Approve real programme publication/assignment, matched server/client configuration and
   rollout separately. Complete founder usability and authenticated installed-device/four-phone
   checks under separate authorisation. Terminal web/macOS compilation is not distribution
   or hosted availability. Browser/computer control remains revoked in this task.

Recovery must retain canonical started packets, accepted history and actuals. Prefer a forward
restriction on new v3 starts while retaining supported owned resumes/History. If withdrawal
becomes unavailable, block future starts too. Never rewrite package/rule/benchmark/consent/
snapshot history, remove a ledger entry or silently route v3 to v1/v2. Hosted recovery actions
require their own exact-target authority. No recovery operation was executed hosted.
