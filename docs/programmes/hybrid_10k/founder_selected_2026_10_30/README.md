# Hybrid 10K — clarified strength doses; D8 review pending

Read **[TEN_WEEK_REVIEW.md](TEN_WEEK_REVIEW.md)** for the one self-contained
programme review: all seventy days, exact working doses/rests/targets, preparation,
progression, phased strength reductions, running totals and quality minutes.

[FOUNDER_SELECTIONS.md](FOUNDER_SELECTIONS.md) retains D1–D7.
[DOSE_CLARIFICATIONS.md](DOSE_CLARIFICATIONS.md) supersedes its earlier RDL note
and resolves every prior dose/membership hold, including the explicit W7 follow-up.
RDL is selected template work. W4 consolidates; W5–7 build with standard W7
strength; W8 controls lower-body effort; W9–10 reduce workload. Running prescriptions
are unchanged. Surviving older phase wording/patterns are grouped in the review.
**D8/full programme approval, publication, eligibility and assignment remain pending.**

[SOURCE.json](SOURCE.json), [AUDIT.json](AUDIT.json) and the twenty
[review graphs](STRENGTH_REVIEW_GRAPHS.json) regenerate exact selected doses.
Preparation stays separate from working sets. The graphs use unpublished local
`DRAFT-R4` review revisions; no published version/event is manufactured. The final
test stays distance-ended. Prior source versions remain at their original Git
commits/checkouts and in verified bundles.

The authorised [six-record lookup](../../../checkpoints/m11_trusted_catalogue_lookup/HANDOFF.md)
confirmed Field Manual ACTIVE_HEALTHY and retained three exact published legacy
rows: initial bodyweight pull-up `EX-053`, DB lateral raise `EX-044` and bench-supported
single-arm DB row `EX-038`. Raw rows, target/time/query provenance and SHA-256 checks
are retained; no canonical ExerciseDefinition version/event or global seed is created.

[EXACT_IDENTITY_ACTIONS.md](EXACT_IDENTITY_ACTIONS.md) now names only three remaining
setup/identity gaps and their separate owner/producer action. The exact
[setup proposals](../../../checkpoints/m11_trusted_catalogue_lookup/SETUP_PROPOSALS.json)
are unapproved and unapplied. The executed bounded query is retained in the lookup
checkpoint; the earlier prepared request remains historical. No hosted write,
project restoration, programme publication or athlete mutation occurred.

Reproduce locally without SQL/network/accounts/athlete operations:

```sh
python3 tool/programmes/hybrid_10k/apply_strength_selections.py --check
python3 tool/programmes/hybrid_10k/render_selected_review.py --check
python3 tool/programmes/hybrid_10k/trusted_catalogue_snapshot_test.py -v
flutter test --no-pub tool/programmes/hybrid_10k/selected_admission_probe_test.dart
```

[Actual admission](../../../checkpoints/m11_trusted_catalogue_lookup/ADMISSION.json)
and [handoff](../../../checkpoints/m11_trusted_catalogue_lookup/HANDOFF.md):
v1/v2 schedules compile; known-identity partial graph/codec checks pass; full
strength admission remains blocked by the three exact setup/identity records. No genuine
programme is published, acquired, started, logged, completed or restored for an
athlete. Only the authorised status/catalogue reads occurred; no Garmin/device work or hosted mutation.
