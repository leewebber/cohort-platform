# M1.2 — normal onboarding and private-free programme acquisition

2026-10-27 (Asia/Makassar). Started at published main
`2a0957fe48c738b048e273c852bb1a4359829be0`.
**ACQUISITION_IMPLEMENTATION_COMPLETE_LOCAL_VERIFIED. HOSTED_NOT_DEPLOYED.
DEVICE_USABILITY_NOT_VERIFIED. M1.2 product gate remains partial.**
Controlling [M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[M0 baseline](../m0_alpha_baseline/HANDOFF.md), [bounded scope](SCOPE.md),
[verification](VERIFICATION.json), [deployment handoff](DEPLOYMENT.md),
[exact migration](MIGRATIONS.json).

## Athlete workflow delivered

Normal signup/email verification/account profile → authenticated training setup →
Programmes/catalogue → private offer details → explicit start-date choice →
**Get programme — free** → exact-assignment schedule in the existing Programme
Athlete spine. No payment or billing consent, automatic enrolment, generated plan,
synthetic coach relationship, ownership transfer or tester-specific runtime.

Training setup asks only for the IANA training timezone required by existing calendar
and enrolment contracts. Display name/roles remain account-profile responsibility.
“Save and continue” persists the draft; “Finish setup” confirms it. A restarted
client resumes the saved draft/review or completed state. Completion is idempotent;
a draft write cannot uncomplete setup or change a confirmed timezone. No benchmark
is compulsory for everyone. This is not the old Coach Brain generation wizard.
An interrupted unsaved picker choice is not a committed setup step.

Authenticated athlete entry is gated by server setup, including the founder's athlete
entry from the existing workspace. After setup the normal shell initially opens
Programmes. The current programme and global catalogue remain available, with private
free offers also shown in normal programme discovery. Details show authoritative
summary, duration, frequency, equipment/level when provided, training timezone and
publication/executable readiness. Missing metadata is not invented. Readiness is a
source/execution check, not a clinical or fitness suitability claim.

No assignments are created by discovery or setup. A new exact-recipient eligibility
row is operator-managed; eligibility is not enrolment. Only an explicit athlete action
acquires the version. An existing active programme blocks acquisition of a different
version, with an explanatory unchanged-training message. The new RPC has no replacement
parameter. Same-version retries return the same assignment and original schedule anchor,
even if a later request supplies a different date. A previously acquired offer opens its
schedule. All schedule navigation uses AthleteProgrammeScheduleScreen and the established
assignment/calendar authority, with ordinary Home/Calendar refresh afterwards.

Loading, empty offers, unavailable backend/schema, expired session, denied access and
not-ready programme states are explicit. A failed list request is not called empty.
Controllers suppress duplicate actions and late responses after account changes/disposal;
RPCs compare expected account identity with auth.uid() to reject token/account races.
Auth entry clears stale hydration on identity change, removes old routes on logout,
and rejects delayed bootstrap/provision responses from another account. Profile creation
recovers a committed/concurrent duplicate without overwriting the existing name/roles.

## Server authority and compatibility

One additive migration creates two RLS-enabled, closed tables and six new functions;
two existing private-visibility/eligibility helpers are replaced within that migration.
No original migration is edited. No old table policy, function ACL, role membership or
broad grant changes. All existing function owner/ACL records are compared by the local
witness; both new tables deny direct table/column access to anon/authenticated/service.

- `athlete_training_setup`: one authenticated athlete row, timezone/draft/completion.
- `private_programme_alpha_eligibility`: exact athlete/version key with optional
  expiry/revocation. No client writes, defaults granting access, seeds or invite platform.
- Four authenticated-only RPCs read/save setup, read private catalogue/detail and acquire.
  Two internal helpers are denied to client/service roles. Expected-athlete parameters are
  equality guards, never authority to act for another person.
- Existing owner/coach-relationship access remains. New alpha eligibility requires
  completed setup and published non-archived private v1/v2. Details for guessed/foreign
  identifiers are uniformly denied. The new path also requires an exact retained
  publication artifact/hash and executable physical graph; it cannot publish content.
- The existing private enrolment helper recognises a new recipient grant only under an
  exact actor/version transaction-local guard set by the no-replacement wrapper. Direct
  legacy replacement-capable RPC attempts by new recipients are denied, including with a
  valid grant. No public set_config RPC exists to establish that internal guard.
- Acquire locks the athlete and version/eligibility inputs, then delegates to the existing
  exact private transaction with `replace_active=false`. Assignment creation, materialisation
  and schedule projection roll back together on failure. New alpha pins use the existing
  `non_commercial_test` source value; no fake `coach_assigned` provenance is retained.
- Expiry/revocation stops future discovery/acquisition; it does not delete a previously
  acquired assignment, training evidence or History. No old programme is repinned.

Canonical v1/v2 source, validation/hash, published graph, running policies, completion,
actuals, correction, adaptation and scheduling contracts remain authority. v3 commercial
HYROX/producer work stays deferred. The local replay deliberately omits the unchanged
pending producer migration, proving this feature does not depend on it.

## Verification and practical limits

`supabase/tests/run_m12_acquisition_gate.sh` builds a task-owned local-only stack from
the deployed 130-file prefix plus the new M1.2 file and test-only baseline/witness. It
uses the existing compiler-generated synthetic v1/v2 retained-publication fixture;
no real Hybrid10K or father programme is created. Local signup uses real GoTrue-issued
sessions and the actual AuthController, profile repository and acquisition stores. Local
fixture email confirmation is disabled; real email delivery/confirmation/redirect handling
remains a hosted/device gate.

Fresh and reset/replay proof covers signup, profile retry/concurrency, setup draft and
complete recovery in a new client, invalid timezone, incomplete setup, eligible facts
and guessed detail, foreign account/expected-identity mismatch, direct table/API denial,
expiry/revocation, old activation bypass denial, materialisation failure rollback,
six concurrent free acquisitions, stable repeated assignment/date, existing-active
refusal, exact v1 schedule, successful v2 acquisition/schedule, restored session,
logout/account separation, effective role/table/column/RLS/RPC matrix and preservation
of existing function ACLs/owners. The scoped guard and idempotency are SQL-owned.

95 affected Flutter tests pass across new controller/widget/auth-race coverage and
existing auth, catalogue decision, timezone, private activation and shell regressions.
All six architecture safety groups pass. Prepared full analysis is **362 inherited
findings before and after**, with identical diagnostic identities, zero errors and zero
changed/new-file diagnostics. The first unprepared scan included missing nested-package
dependencies and was not adopted as a baseline. No suppressions, exclusions or analysis
configuration changes. Broader unchanged runtime tests are not represented as freshly run.

The first local auth harness omitted PKCE async storage; it was corrected to supply it
without changing production auth. One replay timed out without a stage diagnosis;
subsequent fresh/replay runs are the definitive results. A focused auth test exposed
same-account bootstrap re-reading after the race guard; deduplication was restored and
the affected set rerun. No failed attempt is counted as a pass.

Terminal tests and authenticated transport proof are not installed-device interaction,
visual usability approval, real publication, hosted verification or founder acceptance.
No browser/app control, hosted contact/mutation, real account/athlete write, paid-account
change or device distribution occurred. Task-owned containers/configs are removed by
the gate. Older checkout files/indices/HEADs/.temp are independently preserved.

## M1.2 status, next point and Gate A

Implementation for this bounded **normal setup/private-free acquisition** task is
complete and locally verified. Hosted migration/recipient setup and installed-device
acceptance are open. The complete M1.2 plan point also includes actual programme
schedule/benchmark/personalisation adoption; that cannot be accepted without the genuine
programme and its approved target/evidence rules. No generic five-benchmark step or
B3 TEST ONLY policy is promoted to production content.

**Next exact point: M1.1 — real alpha programme source approval and admission** through
the supported retained private v1/v2 path. Obtain/approve Hybrid10K (ten weeks, four runs
and two strength sessions weekly) and the father's tailored gym programme, then prepare
exact source/graphs/metadata and target/evidence policy admission. Those sources remain
missing; no prescriptions are invented. Publication/eligibility/deployment remain later
separately authorised operations, not implied by this source task.

**M1.3 remains:** selection/progress/draft continuity with those genuine versions on the
release candidate/device. This task proves synthetic setup/assignment/schedule restart,
not complete real training progress continuity. M2.1–2.4 execution/whiteboard/running and
recovery proof, M2.5 Garmin delivery AND activity return, M3.1–3.4 governed adaptation,
and M4.1–4.5 distribution/device/instructions/feedback/blocking-defect acceptance remain
as recorded by M0. No broader phase or Gate A is marked complete. Founder content,
Apple/Garmin access, tester/platform/watch confirmation and feedback ownership remain
parallel actions. No next implementation starts automatically after publication here.
