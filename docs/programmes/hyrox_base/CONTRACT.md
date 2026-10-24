# Local content source and export contract

This milestone adds offline authoring/review tooling under `tool/hyrox_base` and
review documents under this directory. It changes no app, SQL, runtime compiler,
canonical package serialization or publication service. The existing
[authoritative contract](../../checkpoints/hyrox_authoritative_start/CONTRACT.md)
and [HTTP boundary](../../checkpoints/hyrox_v3_http/CONTRACT.md) remain binding.

`PROGRESSION.json` plus the exact retained transfer and existing approved brief
compile deterministically to 48 independently addressed review source objects in
`SESSIONS.json`, a 56-entry schedule (eight Sundays without slots), `MASTER.md`,
`COVERAGE.md`, `AUDIT.json`, and `REVIEW_EXPORT.json`. `MANIFEST.json` pins those
outputs and original inputs. No generated file claims a canonical protocol UUID,
revision, retained definition version, approved event or programme hash. Source
addresses such as BASE-W01-GYM_A are local review addresses only.

The generator compares all eight approved run/row/squat rows against the actual
`BaseWeekRule` table before rendering. Each interval source expands work/recovery
steps with recovery between repetitions only. Gym B retains alternating minute
stations and recovery within each minute; Gym C retains its complete third-minute
rest, including the final round. It preserves rep/rest/RIR ranges, per-side work,
pair boundaries, optional progression, timed holds and unresolved alternatives.
Preparation budgets include the five-minute easy start, circuit and ramps; they
are not added to the budget again. No guessed rep duration is used to assert a
full gym time. Quality totals include only two recoveries between three relaxed
accelerations and exclude unknown dynamic preparation and transitions.

`REVIEW_EXPORT.json` is a deterministic JSON review transport, with a SHA-256 of
the complete decoded source representation. Import validates duplicate keys,
closed envelope fields and digest, and returns review data only. It does not
register dependencies, restore approval/history, run publication/import or mutate
a workspace. It is not the Studio canonical-source TAR format. Round-trip proof
is **review export** proof; canonical TAR/package/export remains blocked at T1.

The canonical compilation report fails closed before invoking the compiler with
invented dependencies. It reports zero canonical packages, even when all local
source objects and their review transport validate. The actual existing compiler
and bound-fixture tests remain compatibility evidence using explicit synthetic
authority, never real Base content approval.

Regenerate and verify using only local filesystem processing:

```sh
python3 tool/hyrox_base/content_sources.py --write
python3 tool/hyrox_base/content_sources.py --check
python3 -m unittest discover -s tool/hyrox_base -p 'test_content_sources.py'
flutter test test/hyrox_base/content_source_contract_test.dart
```

No Python socket/local-network permission is requested or used. No HTTP test,
hosted contact, browser/computer control or device action is performed. No prior
denial is bypassed. This tooling is an explicit local review representation, not
a new runtime contract or publication route.
