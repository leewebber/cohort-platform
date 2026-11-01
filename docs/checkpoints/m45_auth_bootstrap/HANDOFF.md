# M4.5 — inherited AuthGate bootstrap diagnosis

2026-11-01 (Asia/Makassar). **FIXTURE_DEFECT_RESOLVED_LOCAL_VERIFIED;
M4.5 AND GATE A OPEN.** Base: `639d6cd8f8535986cd14fa8230ed51effd14a8c2`.
[Controlling M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[preceding verification](../m23_distance_execution/HANDOFF.md),
[M1.2 onboarding/access checkpoint](../m12_acquisition/HANDOFF.md),
[held deployment boundary](../m12_acquisition/DEPLOYMENT.md),
[authentication authority](../DAILY_JOURNEY_INTEGRITY_SPRINT_1_HANDOFF.md),
[verification receipt](VERIFICATION.json).

## Exact failure and cause

Unchanged base reproduces the recorded failure with:

```sh
flutter pub get --offline
flutter test --no-pub test/programme/athlete_runtime_capability_bootstrap_test.dart --reporter expanded
```

Nine tests pass and one fails: `authenticated athlete reaches Home without waiting
on RPC`, original line 124, expected one `AthleteAppShell`, found zero. Authentication
itself succeeds: the fake session and repository bind athlete `user-123`.

Commit `a59438554072c1413c51acb95f245ca7375675fb` introduced M1.2's required
`TrainingSetupGate` between authenticated entry and the shell. It updated the main
AuthGate widget-test fixtures to supply confirmed setup, but omitted this older
capability-bootstrap fixture. That fixture supplies neither an `AcquisitionStore`
nor an initialized Supabase client. The default `SupabaseAcquisitionStore` attempts
`read_my_training_setup`; resolving `Supabase.instance` throws its uninitialized
singleton assertion. The store translates this into `AcquisitionException(unavailable)`;
the controller and gate show setup error/Retry and correctly withhold the shell.
The runtime capability probe is downstream of this boundary and is not the cause.
More pump time, a fabricated token or a skipped assertion cannot supply setup authority.

A new regression directly demonstrates the original configuration: authenticated
controller/identity, uninitialized Supabase, visible `TrainingSetupGate` error/Retry,
no shell and no uncaught widget exception. This is a **harness/fixture defect**, with
missing task-owned setup configuration, rather than a demonstrated athlete-visible
authentication defect. No production implementation change is justified by this case.

## Smallest justified change

Only `test/programme/athlete_runtime_capability_bootstrap_test.dart` changes outside
documentation. The original shell assertion and test remain; its existing AuthGate
injection receives a fake confirmed timezone setup. Capability discovery remains
unconfigured and fail-closed, so it still cannot block the shell. The test additionally
checks initial tab 2 (Programmes). The sign-out case now also supplies confirmed
setup and proves the shell was open before logout.

Four regressions cover missing configuration, saved draft/explicit confirmation and
reopen, unavailable setup/Retry, and a delayed completed setup response after logout
and another account's login. The latter cannot open the new account's shell. No setup
write or acquisition is fabricated by a load or retry. These are in-memory widget
checks; their reopen proof does not establish OS-storage or server durability.

AuthGate, authentication/profile authority, account-switch/hydration guards, setup
persistence, generation/stale-response guards, access/ownership checks and production
configuration are byte-identical to the base. No access bypass, assertion removal,
skip, timeout workaround, suppression or fallback identity is introduced.

## Ordinary alpha journey and real-athlete relevance

| Step | Existing authority and this task's evidence |
|---|---|
| Launch | `main.dart` validates Supabase build configuration and initializes athlete persistence before `CohortPlatformApp`/AuthGate. A fake auth port does not initialize Supabase. No configuration or credential change here. |
| Registration/sign-in | Existing GoTrue/email-confirmation/account-profile and `ProductionAuthAuthority` remain mandatory. Local real-GoTrue signup/profile/session and auth regressions pass. Local email confirmation is disabled by the existing disposable fixture; real email/redirect acceptance remains open. |
| Timezone onboarding | Authenticated athlete enters `TrainingSetupGate`; incomplete/draft/unavailable setup cannot mount the shell. Confirmed timezone is read/saved through expected-athlete RPC guards. Widget confirmation/reopen and actual local RPC persistence/restart pass. |
| Programme catalogue | Confirmed setup opens Programmes (tab 2). Discovery depends on authenticated recipient, publication/readiness and server access rules; empty/unavailable/denied states remain distinct. |
| Acquisition | Explicit free acquisition uses exact version/start date and the existing no-replacement transaction. Local synthetic eligibility, concurrent/repeated acquisition, rollback and foreign-access checks pass. No genuine programme or real eligibility is created. |
| Schedule | Existing exact-assignment/calendar projection is used. Local authenticated synthetic schedule/restart checks and timezone regressions pass. |
| Session access | Existing assignment/version/occurrence/package/owner gates remain. This task changes none of them; identity/coach-only/completion-History regressions and the six safety groups pass. No installed-device session-access journey is claimed. |

There is **no demonstrated real-athlete bootstrap regression caused by this test
failure**. Separately, the M1.2 checkpoint records
`20261026110000_training_setup_private_alpha_acquisition.sql` as undeployed and warns
against distributing the new client before compatible schema is verified. A genuinely
older/missing backend will visibly hold an authenticated athlete at setup; it must not
be bypassed. Hosted state was not contacted or refreshed, so current deployment state
is not independently asserted. Fresh/reset disposable local GoTrue/PostgREST/SQL proof
confirms the required schema/configuration works under its documented fixture conditions.
This does not close that held release dependency or authorise applying anything hosted.

## Verification and limits

- Original unchanged-base reproduction: **9 pass / 1 failure**, exact case/line above.
- Repaired bootstrap file: **14 pass**, including the unchanged failing case and four
  additional guard/recovery tests.
- Relevant auth/acquisition/identity/timezone/completion-History regression command:
  **91 pass**, no skips; includes those 14, so counts must not be added together.
- Existing `./supabase/tests/run_m12_acquisition_gate.sh`: **fresh and repeat PASS**.
  Task-owned loopback-only GoTrue/SQL fixtures cover signup, setup, visibility,
  rollback, concurrency, calendar, restart, logout and security. Temporary local
  schema replay/fixture data are not hosted mutations; stack/workdir cleanup completed.
- All **six architecture safety groups pass**.
- Full `flutter analyze --no-pub`: **362 identical inherited diagnostic identities**
  versus the retained M2.3 final analysis, zero errors, zero changed-test findings;
  exit 1 remains non-green. No analysis/dependency configuration was changed.
- `git diff --check` passes. No production Dart, SQL, publication, content, eligibility,
  assignment or credential bytes change. Full default suite and installed-device
  journeys were not run; terminal proof is not M4.2 acceptance.

Exact commands, log hashes and preservation comparison are retained in VERIFICATION.json.
Initial default-sandbox Git DNS and Flutter SDK-cache permissions failed; normal
explicitly authorised Git HTTPS/Flutter execution then succeeded. No denied network
review, alternate transport, browser/desktop control or credential workaround was used.

## Git, preservation and next single point

Live ordinary Git HTTPS verified main at the exact expected `639d6cd` before work.
The supplied Developer checkout remains dirty at `a331f52`; its cached origin/main
remains `7736d60`. The existing M2.3 copy remains clean at `639d6cd`. A new independent
`/private/tmp/cohort_m45_auth_bootstrap` clone avoids changing any earlier checkout's
HEAD/index. No managed worktree creation/cleanup, prune, reset, stash or history rewrite.
All inventoried prior checkouts, branches, HEADs, indices, tracked/untracked files,
.env/.temp bytes and retained backup bundles are preserved. Main-only publication
requires another fresh ordinary remote-ancestry check and a non-force push; final
publication status belongs to the final Git receipt/report.

**Next single point: bounded M1.1 founder-authoring allocation using the EXISTING
Programme Studio.** Define a minimum usable founder workspace in which Lee authors
a genuine strength session and personalised running session, arranges them in a
programme, saves an editable draft and reviews athlete prescriptions. Reuse existing
Studio composition/revisions/editable-workspace authority. This is a route to genuine
programme admission and a foundation for future coaches; no implementation or separate
coach-management platform begins here. The three missing exercise setups still require
a legitimate catalogue write/retention path: a UI does not establish that authority.
No unchanged catalogue lookup or content review was repeated.

No newly demonstrated alpha blocker displaces that allocation. Compatible hosted
setup/acquisition schema, genuine programme admission/access, authenticated installed-
device acceptance and other M0–M10 dependencies remain open. Passing this fixture
neither closes M4.5 nor Gate A.
