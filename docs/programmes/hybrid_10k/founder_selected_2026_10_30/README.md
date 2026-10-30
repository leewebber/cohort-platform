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
`DRAFT-R3` review revisions; no published version/event is manufactured. The final
test stays distance-ended. Prior source versions remain at their original Git
commits/checkouts and in verified bundles.

The six technical dependencies are specific records, not further founder movement
choices: [EXACT_IDENTITY_ACTIONS.md](EXACT_IDENTITY_ACTIONS.md) names each missing
row/setup binding, authority and action. The bounded
[SELECT request](EXACT_ROW_RETENTION_REQUEST.sql) is **unexecuted**.
[Identity evidence](IDENTITY_INTAKE.json) distinguishes legitimate retained rows
from candidates and separate conditional assisted/weighted pull-up branches.
There is no demonstrated need for deferred v3 producer infrastructure.

Reproduce locally without SQL/network/accounts/athlete operations:

```sh
python3 tool/programmes/hybrid_10k/apply_strength_selections.py --check
python3 tool/programmes/hybrid_10k/render_selected_review.py --check
python3 tool/programmes/hybrid_10k/selected_source_test.py -v
flutter test --no-pub tool/programmes/hybrid_10k/selected_admission_probe_test.dart test/programmes/private_protocol_graph_builder_test.dart
```

[Actual admission](../../../checkpoints/m11_hybrid10k_dose_reconciliation/ADMISSION.json)
and [handoff](../../../checkpoints/m11_hybrid10k_dose_reconciliation/HANDOFF.md):
v1/v2 schedules compile; known-identity partial graph/codec checks pass; full
strength admission remains blocked by the six exact identity records. No genuine
programme is published, acquired, started, logged, completed or restored for an
athlete. No hosted, Garmin or device work occurred.
