# HYROX Base personalisation — continuation

2026-10-22. Fresh remote baseline `fa5186fab8c1038fdb1972aea75a3880935c2d2f`.
Decisions commit `6f38a3f073586bda4cfaf89822915cd2b1dfa8f8`; implementation
`99f5bd51d9be546a36313621d26c7ac97d2eb1ec`. This evidence commit is the intended
normal main publication tip; exact remote postflight is reported separately.

[Approved decisions](DECISIONS.md) · [exact founder brief](FOUNDER_BRIEF.txt) ·
[architecture findings / additive production plan](ARCHITECTURE.md) ·
[verification](VERIFICATION.json) · [example summary](EXAMPLE_SUMMARY.json) ·
[preservation](PRESERVATION.json).

## Delivered milestone

A separate local synthetic review flow accepts the five shared benchmark types with
exact units, test date, explicit source declaration/reference and immutable identity.
Zero strict pull-ups is valid. Entries do not select themselves. Explicit selection
and replacement consent authorise only future local previews; no automatic latest/best
choice or inferred assessment completion. All eight approved weeks calculate running,
dedicated-rowing and squat targets with exact rule/source/input traceability.

The preview keeps authored doses/effort, calculated targets and absent actuals distinct.
Missing/invalid metrics or missing equipment increment never fabricate numerical targets.
Running work/recovery seconds and exact pace windows remain structured, recovery is easy
and unpaced, and no final extra recovery is appended. Started local snapshots retain
prescription objects across benchmark changes; local completion can record separate actual
squat grams through the controller without progression, benchmark replacement or history
rewrite. The review UI demonstrates freezing/completing examples; it does not provide a
production workout player or persistent actual-load entry screen. Synthetic state is memory
only and clears on reload/scenario switch. Production history/persistence is not delivered.

| Synthetic example, Week 1 | 10 km | Quality pace /km | 2 km row | Dedicated split /500 m | Squat 5RM | Configured increment | Prescribed squat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A | 40 min | 4:00–4:12 | 7 min | 1:55–2:00 | 100 kg | 2.5 kg total | 80 kg total |
| B | 60 min | 6:00–6:18 | 9 min | 2:25–2:30 | 75 kg | 1 kg total | 60 kg total |

Week 2 A is 82.5 kg, B rounds 61.875 kg to 62 kg with its explicitly supplied 1 kg
increment. Week 7 run windows are 4:07.2–4:19.2 and 6:10.8–6:28.8; squat loads 95 kg
and 71 kg respectively. These are authored starting windows, not measured thresholds.
The executable produces all 16 athlete/week previews and includes the unused press and
zero-pull-up benchmark examples in its explicit input flow, without deriving other lifts.

From the isolated repository root, terminal-only examples:

```sh
dart run tool/hyrox_base/review_examples.dart
dart compile exe tool/hyrox_base/review_examples.dart -o /private/tmp/hyrox-base-review-examples
flutter test --no-pub test/hyrox_base
flutter build web --target lib/main_hyrox_base_review_preview.dart --no-pub
```

The compiled Flutter entry exists for later authorised review. No app/browser was opened,
controlled or observed; a web build and widget tests are not native-browser evidence.
No running preview/server is left by this task.

## Validation and technical review

- **22 new tests pass:** all eight authored tables and formula boundaries, 40/60-minute
  athletes, different row/load examples, finite/invalid/missing inputs, exact typed units,
  pounds conversion, precision/technical bounds, invalid dates/provenance, zero pull-ups,
  equipment rounding/ties, no unrelated benchmark reuse, source-brief digest, consent,
  immutable IDs/owners, snapshot/actual separation, stale requests/out-of-order success
  and late failure, disposal, retry, complete UI entry/selection/review and narrow large text.
- **333 affected regressions pass:** existing running domain/policy/snapshots/goldens,
  tracking contracts/C2/C3, authored Plan Package/compiler/import authority, structured
  execution and target-versus-actual behavior.
- **All six mandatory safety groups pass.** No hosted or local database operation is
  introduced; full default suite and DB replay were not run.
- **Zero diagnostics in all seven new Dart files.** Full analysis remains **non-green**:
  exactly the same 367 diagnostic identities as the prepared immutable remote-base archive,
  110 warnings / 257 info / zero errors. An initial unprepared-worktree count of 989
  reflected missing nested package configs; offline cached preparation restored the real
  comparison. No suppression, analysis config, package source or lockfile was changed.
- Native terminal executable and Flutter web build pass. Interpreted and compiled terminal
  examples match byte-for-byte. Web build has inherited dependency Wasm-dry-run warnings;
  JavaScript web compilation succeeded; no Wasm/provider/browser validation is claimed.

Self-review fixed precise load conversion, narrow dropdown overflow and worker retry.
One test API setup issue was corrected. A concurrent Flutter generated-file collision
was resolved by running final verification serially. Final code, scoped analysis, focused
suite and builds passed; no confirmed unresolved defect is known. No independent-agent
review or founder usability approval is claimed.

## Compatibility and preservation

No existing app/Studio entry imports this slice. No canonical parser/schema/hash/golden,
C1/C2/C3 source/assessment/admission contract, B2 evidence/policy/snapshot, running runner,
SQL, production source, published content, dependency or workspace/TAR profile is changed.
Only this new independent code/decision/evidence set and three dated checkpoint/roadmap
notices are added. The old readiness tool still reports its registered planned family's
absent complete source; it does not ingest the newly retained partial brief as sessions.

All **16 older checkout inventories match exactly**, including original dirty main
`a331f52967e1887c4435cccc8f1ecfa192028cd6` and its **95 outstanding paths**. Indices,
HEADs/branches/Git pointers, tracked/nonignored/outstanding bytes and explicit `.temp`
presence/absence are retained; ignored build caches excluded. All **2,754 present protected
base blobs** outside the three intentional documentation notices match; nine already absent
`.temp` blobs retain their Git identities. Four prunable registrations are untouched.
Raw inventories/build/test/analysis evidence and the immutable baseline archive are under
`/private/tmp/cohort-hyrox-personalisation`; durable evidence records their hashes.

Publication is three linear commits from the freshly verified base, no merges, through a
clean isolated `codex/hyrox-base-personalisation` worktree. Final remote-base/range checks,
normal main-only push, fetched equality and clean worktree are required. Original local
main and older checkout HEADs must never be advanced/staged. No force, feature-branch or
tag publication. This task's founder explicitly authorises that normal publication.

## Exact next integration work and blockers

The [production contract plan](ARCHITECTURE.md) specifies a future additive schema-v3
tracking binding plus a **separate** personalisation binding, immutable rule/metric
artifacts, exact protocol/block/step/exercise version scope, canonical hashing, independent
owner-gated evidence/acceptance records and atomic occurrence freezing. It is a prepared
contract/compatibility design, not implemented v3 admission. C1/C2/C3 remain observational;
B2's eligible 5 km speed policy cannot be relabelled into this Base 10 km pace policy.
Production evidence selection, persistence, authenticated ownership, concurrency/replay,
prepare/start/execution, actual capture and release review remain to implement and prove.

Complete content still needs the explicit missing source inputs in [DECISIONS](DECISIONS.md#remaining-exact-source-inputs):
supporting strength dose/rest/tempo/cues/progression; warm-ups/cooldowns; carries/core;
mixed conditioning/SkiErg/wall-ball/finisher details; exact variants and authoritative
published definition versions; complete immutable sources for all 48 sessions and truthful
equipment/prerequisite/exclusion metadata. Exact current division wall-ball mappings and
any new substitution rules require verified authority; none were guessed. Test Week's
separate sessions/protocols need their own authoring/approval. No complete package is
claimed from this partial approved brief.

After source and production contracts exist: prove each prescription representation,
complete coaching/editorial review and production-path/device/security/release gates,
then obtain separate hosted publication/assignment/distribution authority. No hosted
mutation/migration, athlete-data write, real programme publication/assignment, payment,
computer/browser control or device distribution occurred. Broader Stage 2/Sprint C,
prior native browser gaps and four genuine-record-dependent phone checks remain open.
Continue with the explicit contract/content blockers above; no routine allocation-only
or founder walkthrough pause is introduced by this local milestone.
