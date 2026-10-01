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

## Proposed hosted publication and activation plan

This plan is not yet authorised to run.

1. Reconfirm a clean approved commit, the three identities above, Cohort Field
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

## Development phone build requirements

- Use an approved external defines file with the Cohort Field Manual client
  URL and anonymous key; never put or print secrets in the repository.
- Build from the exact approved commit with:
  `tool/release/build_app.sh --env development --target ios --config <external-defines.json> --enable-internal-tools`.
- Confirm the output states `ENVIRONMENT=development` and
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
  matrix: 51 passed.
- Canonical Plan Package package suite: 37 passed.
- Exact disposable database gate: 6/6 passed after a full local reset.
- Changed-file Flutter analysis: no issues.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Full authoritative `flutter test`: 3,452 passed with 6 expected
  environment-gated skips.
- `git diff --check`: passed before local commits; rerun against the final
  branch HEAD for closeout.

## Stop condition

Do not publish the fixture, activate Lee, enter hosted benchmark evidence,
build/install the phone app, push the branch, resume Bali, or perform any other
hosted write without the corresponding concrete approval.
