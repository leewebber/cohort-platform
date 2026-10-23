# Athlete v3 review, consent and frozen runner wiring

2026-10-23. **LOCAL ATHLETE FLOW INTEGRATED; HOSTED AVAILABILITY AND DEVICE VALIDATION UNPROVED.**
Base published main `6fff850807a18d025004f5f16b74d5b58a4f2182`; implementation `70f7c72d0828b4043208dbea41ec4ab6fe6b85f3`.
The subsequent checkpoint commit records this result; obtain its published SHA from normal main history.

[Verification](VERIFICATION.json), [scope and runner support](SCOPE.md),
[deployment prerequisites](DEPLOYMENT.md), [preservation exception](PRESERVATION.json),
[local-only postcheck](POSTCHECK.sql), [migration inventory](MIGRATIONS.json).
Preceding [authoritative server contract](../hyrox_authoritative_start/CONTRACT.md)
and [approved partial Base content](../hyrox_base_personalisation/DECISIONS.md) remain binding.

## Delivered

- Existing Home/canonical launcher and Programmes overview mount authenticated programme
  target review, including rest-day management. Shows programme name/version, benchmark
  values/dates/declaration sources, work/recovery doses, calculated run pace, row split and
  squat load, or explicit numerical unavailability. No internal tuples/hashes are displayed.
  Benchmark entry uses the existing append-only declared-evidence repository; saving does
  not select a result. Recording a new result never silently replaces an accepted choice.
- Explicit programme/assignment/version consent replaces future-unstarted consent under
  existing server CAS; withdrawal blocks new starts and leaves started/completed history.
  Existing accepted consent is reused for later eligible starts, not reaccepted every time.
  Edits invalidate review; corrected selections require fresh review; unavailable sources,
  unsupported shapes/backend, stale replies and account changes cannot enable acceptance.
- Existing fixed-occurrence canonical start remains the sole creator/resumer. A v3 start
  cannot fall back to legacy/synthetic execution. Frozen retries bypass benchmark/consent
  changes. Exact returned immutable targets are validated against the actual loaded blocks
  and projected into the existing Active Session/timer/performance paths.
- Flat positive time-based run/row intervals use existing typed timers and interval actuals.
  Pace windows are shown during work, no work pace is applied to recovery, and v3 has no
  recovery after its final repetition. Explicit seconds/500 m rowing actuals retain their
  unit through save/correction/History; set-distance round trips account for that dimension.
  Squat reuses structured sets/reps/load and separate actual load capture with authored RIR.
  Unsupported modalities, durations, timers, scope/step mismatches and capture modes refuse;
  accepted adaptation cannot replace this v3 source. Generic interval restore retains the
  timer cursor safely paused; malformed bound phases/durations refuse.
- The exact server packet persists separately from actual results in session snapshots;
  runner restore verifies it against canonical start. Finish review and History display it
  without profile reads or historical recalculation. Additive server guards reject target
  replacement, wrong bound interval doses/units and forged snapshots on ordinary save,
  canonical completion and subsequent actual corrections. No B2 or C1/C2/C3 authority changed.

## Verification and limits

991 affected Flutter tests pass; the separate local authenticated E2E test is deliberately
skipped in the ordinary suite and passes on each full fresh/repeat disposable migration
replay. The latter exercises actual Supabase JWT authentication, production assignment/
version/source/benchmark/consent/start repositories, runner projection/capture, persisted
save/reload, canonical completion, result correction and owned History. Two athletes produce
different run/row/squat targets. Frozen duplicate/resume behaviour, withdrawn/replaced/stale
consent, missing inputs, source/owner refusals and client target/unit overrides are exercised.
Existing 129 loopback API/security/concurrency assertions and 136 Dart–SQL vectors pass per
replay, including deterministic benchmark/consent/source/version races and legacy Q/BK.
Six required safety groups pass. Six focused UI/timer/restore checks pass after final restore
hardening. Production web and macOS release artifacts compile in the terminal; neither was
opened, installed or distributed. See exact evidence/reuse qualifications in VERIFICATION.json.

Analysis is **not green**: 364 inherited findings, 110 warnings/254 info, zero errors or
new findings, versus fresh 365. One existing constructor initializing-formal lint was removed
in the touched authored-slot resolver. All 36 changed/new Dart files have zero diagnostics.
The final cursor hardening was covered by focused checks and final analysis/builds; the
991-test/six-group evidence predates that isolated check but its protected source is unchanged.

Original main stays `a331f52967e1887c4435cccc8f1ecfa192028cd6`, including 95 outstanding paths.
Sixteen measured older checkout inventories match exactly. During managed-worktree creation,
automatic cleanup removed four other older clean checkout directories. Their retained exact
Git snapshot/branch commits were restored at the original paths and locked against pruning.
Every previously recorded tracked/outstanding file, branch/HEAD, git pointer and .temp state
matches, with no staged changes. **Their four index files were regenerated, not preserved
byte-for-byte.** This is an explicit preservation exception, not an all-indices-preserved claim.

No hosted inspection/apply, producer provisioning, real publication/assignment/athlete write,
app/browser control, payment, device distribution, Garmin integration or content invention.
The fixture is partial synthetic source, not a transferred 48-session Base programme.
Supporting content remains not yet transferred/consolidated; Test Week and race mappings
remain incomplete. Founder usability acceptance, installed-device proof, production readiness
and broader Stage 2/Sprint C closure are not claimed.

## Exact remaining dependencies

1. Separate hosted target inspection/deployment authority: verify current prerequisite ledger,
   function bodies/ACLs/default grants and approved migration inventory, apply only authorised
   exact files including `20261023130000_v3_athlete_review_state.sql`, and postcheck. Hosted
   migration/capability state was not inspected; no pending/applied claim is inferred.
2. Provision/configure the separately reviewed verified publication producer and dedicated
   capability; supply exact approved ExerciseDefinition artifacts, publication events and
   explicit exercise-to-rule-kind approvals. No usable real producer or artifacts are created.
3. Configure the existing Founder-authenticated trusted v3 publication facade/transport and
   approve actual private programme publication/assignment and the matching client rollout.
   Transfer/consolidate supporting session prescriptions, canonical versions/bindings and
   capture/coaching fields; validate each actual source against the supported runner profile.
   No full 48-session package, Test Week or authoritative race-standard mapping is supplied.
4. Separately authorise authenticated installed-device/native/browser checks, four-phone
   validation, founder usability review and any distribution. Computer/browser control stays
   revoked; terminal builds and local model/widget/server tests do not replace those checks.
