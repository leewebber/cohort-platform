# Structured Running B3 device validation — local handoff

**Recorded:** 2026-10-01
**Branch:** `codex/b3-device-validation`
**Base:** `1f6017d84f8de40d039df253c56dc8b339b61e82`
**Status:** Prepared locally; awaiting approval for hosted publication,
assignment transition, and development phone installation.

Binding contract:
[`../architecture/Structured_Running_B3_Device_Validation_v1.md`](../architecture/Structured_Running_B3_Device_Validation_v1.md).

```text
B3_DEVICE_VALIDATION=PREPARED_LOCAL
B3_DEVICE_VALIDATION_PRIVATE=true
B3_DEVICE_VALIDATION_HOSTED_PUBLICATION=false
B3_DEVICE_VALIDATION_ASSIGNMENT_ACTIVATED=false
B3_DEVICE_VALIDATION_PHONE_INSTALLED=false
B3_DEVICE_VALIDATION_COMMERCIAL_BANDS_APPROVED=false
HOSTED_WRITES=0
```

## Delivered locally

- A canonical private Plan Package v2 fixture with four short, same-day
  structured-running occurrences and explicit TEST ONLY labelling.
- A reviewed protocol-graph reader that binds exact canonical protocol,
  revision, stable block, workout, step, timer, and mapping identities before
  the publisher may send a payload.
- The existing private exact-version publisher now accepts that reviewed graph
  path while retaining the Bali founder-YAML path unchanged.
- An internal-tools-only authenticated screen for declaring a real completed
  5 km result. It sends exact 5,000 m, elapsed time including pauses, local
  date, timezone, and surface to the established B2 RPC.
- A development-only `--enable-internal-tools` release-build option. The build
  script rejects that option for production.
- An exact disposable database gate proving publication, four materialised
  occurrences, assignment replacement preservation, calculated target,
  identical resume snapshot, and intent-only no-eligible-evidence behavior.

## Exact reviewed artifacts

- Programme version: `b3d00000-0000-4000-8000-000000000001`
- Canonical package SHA-256:
  `fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a`
- Protocol graph SHA-256:
  `44e00cacd3e86d6c440279c58aca44f50d46d1af102020bdd6636310ca1f4a17`
- Publication artifact SHA-256:
  `c3b122f25cefeb274060399d5895eda7bd2335695a8c32fd7a3121a3c652cea8`
- Execution mapping SHA-256:
  `91dac4d3717737d84ab31c805a9b69be3c28db68500cfbd368176e587af5a421`
- Authorised start/timezone: `2026-10-01`, `Asia/Makassar`

All artifact hashes must be rechecked against the final approved commit before
hosted publication. The service-role credential and client configuration stay
outside the repository.

## Independent review closeout

The 2026-10-01 review confirmed the canonical compiler/package hash and exact
reviewed protocol graph, private/non-catalogue publication inputs, authenticated
athlete ownership for manual benchmark evidence, production rejection of the
internal-tools build switch, and assignment replacement without deletion of the
prior assignment, occurrences, or logged session evidence.

Four defects were corrected in separate follow-up commits:

- benchmark entry now uses a deterministic athlete-scoped source reference,
  preserves its command identity for a retry, and becomes terminal after a
  successful record instead of allowing an accidental second evidence row;
- the exact publisher now rejects a success response whose version, package
  hash, scope, schema version, or slot count differs from the reviewed request;
- the database fixture gate now includes an existing completed session record
  and proves its count and digest are unchanged after assignment replacement.
- internal-tools visibility now requires the app's build environment itself to
  be `development`; a raw define or manual override cannot enable the tools in
  production, loopback preview, or an unclassified build.

All four fixture slots materialise on `2026-10-01` with their authored
`session_order`. Home exposes the next actionable same-day occurrence after an
earlier occurrence completes. Each start freezes its own B2 snapshot. Slots
1-3 accept an eligible athlete-owned manual 5 km result and remain calculated
on retry. Slot 4 permits cohort evidence only; because the current athlete
evidence projection exposes trusted manual evidence and cohort ingestion
remains unavailable, it remains deterministically intent-only even after the
manual result exists. Enabling cohort ingestion would require this assumption
and fixture to be reviewed again.

The authorised local date is a hard rollout boundary. If publication or device
validation cannot occur on `2026-10-01` in `Asia/Makassar`, stop. Amend the
publication artifact to a newly approved date, recompute its hash, rerun the
gates, and obtain approval for the new commit before any hosted action. Do not
activate a past-dated fixture and treat missed occurrences as device evidence.

## Proposed hosted publication and activation plan

This plan is not yet authorised to run.

1. Reconfirm a clean approved commit, the artifact identities and hashes above,
   Cohort Field
   Manual project `otnhhdxstdnwccehacku`, health, ledger through
   `20260929120000`, and zero pending migrations in a disposable linked
   workdir.
2. Capture SELECT-only Bali/Lee baselines: active assignment identity/status,
   programme pin, occurrence/session/result counts and digests, and History
   counts/digests.
3. Run `tool/programmes/bin/publish_private_exact_version.dart` with the exact
   B3 package and publication artifacts, the authorised coach owner UUID, the
   Cohort Field Manual URL, and a separately supplied service-role key. The
   command must return `published` (or an identity-exact `already_published`)
   for version `b3d00000-0000-4000-8000-000000000001`.
4. Verify by SELECT only: private/non-catalogue ownership, package hash,
   reviewed protocol graph, one stable interval block, four exact slots,
   authored workout/step mappings, test-only policies, and no assignment or
   benchmark write.
5. On the approved development phone, Lee signs in and opens Programmes → My
   private programmes → `[TEST ONLY] B3 structured running validation`.
   Confirm the replacement warning, authorised date/timezone, and that Bali
   results will not be deleted; activate through the authenticated product
   action.
6. Verify by SELECT only that the old Bali assignment is `reassigned`, the new
   B3 assignment alone is active, four B3 occurrences exist, and every Bali
   baseline count/digest remains unchanged.

No manual hosted SQL is an approved publication, activation, benchmark, or
completion mechanism.

### Exact approved-order sequence

1. **Integrate.** Fetch `origin`; require a clean reviewed branch, the approved
   final review SHA, `origin/main` still at
   `1f6017d84f8de40d039df253c56dc8b339b61e82`, a linear no-merge range, and the
   exact artifact hashes above. Strict-fast-forward only `HEAD` to
   `refs/heads/main`, fetch again, and require `HEAD = origin/main`, divergence
   `0/0`, and a clean worktree.
2. **Hosted preflight.** In a disposable linked workdir, require Cohort Field
   Manual `otnhhdxstdnwccehacku`, healthy services, migration ledger through
   `20260929120000`, the committed B2/B3 functions, triggers, and grants, and
   `db push --linked --dry-run` with zero pending migrations. Capture SELECT-only
   Lee/Bali assignment, occurrence, session, result, outcome, and History counts
   and digests. Stop on any mismatch.
3. **Publish the exact private version.** With the service-role credential
   supplied outside the repository, run:

   ```text
   dart run tool/programmes/bin/publish_private_exact_version.dart \
     --package tool/programmes/b3_device_validation_v1.plan-package.yaml \
     --publication content/programmes/b3_device_validation/v1/b3_device_validation.publication.json \
     --owner-id <approved-coach-owner-uuid> \
     --url https://otnhhdxstdnwccehacku.supabase.co
   ```

   Require `published`, or an identity-exact `already_published`, and the exact
   response identity validation. Then verify by SELECT only: coach-private and
   non-catalogue scope, owner, version and package hash, reviewed graph, stable
   block, four slots, workout/step mappings, test-only policies, authorised
   date/timezone, and no assignment or benchmark write. A returned
   `already_published` still requires every SELECT-only object check.
4. **Build and install after separate approval.** Use an external config path
   outside Git containing the development environment, Field Manual HTTPS URL,
   and anonymous client key. From the integrated SHA run
   `./tool/release/build_app.sh --env development --target ios --config
   <absolute-external-config.json> --enable-internal-tools`. Require the exact
   commit provenance, development environment, internal tools enabled, and a
   successful signed `build/ios/iphoneos/Runner.app`. Confirm Apple signing,
   provisioning, and the approved device before installing with Xcode Devices
   and Simulators (or the equivalent approved `xcrun devicectl device install
   app` command). The repository has no separate phone-install authority.
5. **Record only real benchmark evidence.** Lee signs in on the development
   build and uses Diagnostics -> B3 device validation benchmark. Record an
   actual completed 5 km only, before starting any calculated occurrence.
   Recheck the athlete-owned row and eligibility by SELECT only; never create
   or promote activity evidence manually.
6. **Activate through the authenticated product action.** In Programmes -> My
   private programmes, open the exact TEST ONLY version, review the replacement
   warning/date/timezone, and activate. Verify by SELECT only that Bali is
   `reassigned`, the new assignment alone is active, all four occurrences share
   the authorised date, and every captured historical count/digest is unchanged.
7. **Run the founder device script below.** Complete the four occurrences in
   order, then recheck session/History authority. Return to Bali only through
   the supported private-programme activation action after separate approval.

No migration is introduced by this branch. The required hosted prerequisite is
the already-integrated migration ledger through
`20260929120000_b3_structured_running_targets_and_actuals.sql`; its current
hosted state must still be revalidated during step 2.

## Development phone build requirements

- Use an approved external defines file with the Cohort Field Manual client
  URL and anonymous key; never put or print secrets in the repository.
- Build from the exact approved commit with:
  `tool/release/build_app.sh --env development --target ios --config <external-defines.json> --enable-internal-tools`.
- Confirm the output states `ENV=development` and
  `INTERNAL_TOOLS=enabled`. Production plus internal tools must fail before a
  build.
- Normal Apple signing/provisioning and the physical device registration must
  already be available. This task did not build or install the phone app.

## Founder device script

1. In Diagnostics → B3 device validation benchmark, enter a completed 5 km
   test only if Lee actually completed it. Use elapsed time including pauses,
   the real local date, and the correct surface. If no such result exists, do
   not create one; calculated-target validation remains blocked honestly.
2. Activate the TEST ONLY programme using the approved replacement screen.
3. Occurrence 1: confirm a calculated `Advisory pace target` appears only on
   work. Pause during work, background and return, then cold-relaunch and
   confirm exact step/repeat/remaining time. Repeat during recovery, including
   the final recovery. Finish all three work repetitions, record actual pace,
   complete, inspect Review Session and History, then correct an actual and
   confirm the frozen target is unchanged.
4. Occurrence 2: mark one or more completed work repetitions `pace unavailable`;
   complete and confirm target and actual state remain distinct.
5. Occurrence 3: skip a work repetition, resolve all other pending rows, and
   confirm Review Session and History say `Partially completed`, with explicit
   block and repetition counts and no enabled Edit results action.
6. Occurrence 4: confirm `Pace target unavailable` and the approved no-eligible-
   benchmark explanation. No numeric pace may appear on work or recovery.
7. Across all occurrences, confirm timer expiry alone never completes a block
   or session and recovery never displays a numeric target.

## Returning to Bali

Use the same supported athlete action: Programmes → My private programmes →
Lee Bali Hybrid Base → review replacement → Activate. This creates a new Bali
assignment and preserves the previous Bali assignment, programme version, and
all logged evidence. It returns Lee to the immutable Bali version but does not
revive the superseded assignment's exact cursor; selecting an exact continuation
point would require a separately approved product mechanism. Do not emulate
that mechanism with SQL.

## Local verification evidence

- Focused fixture/compiler, publication/activation, internal benchmark,
  release-build, structured-runner, target/actual, and Bali compatibility
  matrix: 128 passed.
- Canonical Plan Package and private-publication suite: 59 passed.
- Exact disposable device fixture database gate: 7/7 passed after a full local
  reset, including prior completion-evidence digest preservation.
- Independent B2 benchmark-evidence database gate: 15/15 passed after a full
  local reset, including athlete ownership, cross-athlete denial, grants,
  idempotent retry, correction, and arbitrary-activity rejection.
- Changed-file Flutter analysis: no issues.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Full authoritative `flutter test`: 3,454 passed with 6 expected
  environment-gated skips.
- `git diff --check origin/main...HEAD`: passed at review closeout.

## Stop condition

Do not publish the fixture, activate Lee, enter hosted benchmark evidence,
build/install the phone app, push the branch, resume Bali, or perform any other
hosted write without the corresponding concrete approval.
