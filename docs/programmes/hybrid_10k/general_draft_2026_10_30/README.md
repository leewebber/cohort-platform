# General Hybrid 10K PB — reconciled draft

2026-10-30 (Asia/Makassar). **GENERAL SOURCE RECONCILED; NOT BLANKET APPROVED,
PUBLISHED OR ASSIGNED.** Four timed replacements are founder-selected. Other
detailed prescriptions remain draft; local compilation is not content approval.

Source authority is the [retained founder clarification](FOUNDER_CLARIFICATION.md)
over the immutable [28 October coaching draft](../lee_draft_2026_10_28/SOURCE.md).
The [current complete source](SOURCE.json), [shared guidance](GENERAL_GUIDANCE.md)
and [ordered review](ORDERED_REVIEW.md) implement that precedence. Edit neither
historical draft nor generated files to manufacture a new approval. Further source
changes need a retained decision and regeneration.

The current scope is the general ten-week PB programme for an already-fit competent
runner. Lee-specific return-to-running, travel and treadmill transition assumptions
remain separate. Retained early-week doses are still proposals for review, not an
approved general entry standard. Calendar dates are illustrative source anchors;
assignment dates and timezone require their own authority.

The schedule now contains **40 runs, 20 strength sessions, 10 rest days**, including
**39 timed runs and one distance-ended final 10K**, and 124 strength exercise
occurrences / 263 work sets. Week 10 Thursday restores two comfortable sets each
of the retained DB shoulder press and bench-supported one-arm DB row, at least
3 RIR, with no lower-body lifting. No upper RIR bound or gym duration was invented.

The four former distance workouts are explicitly replaced, not converted using an
estimated pace. Their exact totals are 42:30, 49:00, 40:00 and 28:00. Their warm-up
is 13 minutes, recoveries are between work repetitions only, and the final five
minutes permit very easy running or walking. Walking remains part of programmed
duration but not running volume. There is no in-programme 5K test; qualifying
representative 5K input remains external/manual and explicitly selected under M2.3.

Main EASY work now carries the existing confirmed-Zone-2 admission marker. Quality
work carries the existing threshold / 10K-specific marker. Approved rule versions
and behaviours are unchanged. Source RPE ranges are supporting cues; no scalar
fallback was invented, and missing input/acceptance cannot silently start a run.

[Arithmetic/provenance](AUDIT.json), [unique exact variants and evidence](IDENTITY_INTAKE.json),
[actual admission results](../../../checkpoints/m11_hybrid10k_reconciliation/ADMISSION.json)
and [remaining coverage/dependencies](../../../checkpoints/m11_hybrid10k_reconciliation/COVERAGE.md)
distinguish local repository row matches, candidates and missing identities.
The four bound movement IDs come from pinned executable repository declarations,
not the unrelated HYROX producer or name matching. The historical CSV is retained
only for candidate evidence; its Published column is not promoted into a current
runtime catalogue, version or publication event.

Reproduce without network, SQL, accounts or publication:

```sh
python3 tool/programmes/hybrid_10k/reconcile_general_source.py --check
flutter test --no-pub tool/programmes/hybrid_10k/general_admission_probe_test.dart
```

The generated schedule is an unpublished source-reference candidate for private
v1/v2. Running-body graphs can be checked independently, but 20 full strength
graphs remain incomplete; no null-ID or empty-body substitute is admitted. Exact
ExerciseDefinition versions/events are not invented or newly required by v1/v2.
The final 10K still needs distance-ending execution in the existing runner path.
