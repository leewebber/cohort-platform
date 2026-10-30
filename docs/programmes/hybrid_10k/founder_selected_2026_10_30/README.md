# Founder-selected Hybrid 10K source — D8 review pending

Read **[TEN_WEEK_REVIEW.md](TEN_WEEK_REVIEW.md)** for the single self-contained,
human-readable ten-week programme: all seventy days, exact strength reference/
selected/proposed doses, ordered run steps, preparation, targets, progression,
consolidation/taper, weekly running totals and quality minutes, source corrections
and the one remaining content/identity list. A held dose is not an invented final
prescription. D1–D7 are selected; D8/full programme/publication remain unapproved.

[FOUNDER_SELECTIONS.md](FOUNDER_SELECTIONS.md) retains the actual human selections,
SHA-256 `dd7e08cc1b026b46307b42c491216543899879e202c3f665ce837f486bc0d6d8`.
[SOURCE.json](SOURCE.json) is the regenerated genuine general source.
[AUDIT.json](AUDIT.json) records exact totals and carryover provenance.
[IDENTITY_INTAKE.json](IDENTITY_INTAKE.json) and
[TRUSTED_INTAKE_REQUESTS.json](TRUSTED_INTAKE_REQUESTS.json) distinguish five exact
local legacy row bindings, six unresolved selected variants and conditional
weighted/assisted branches. No candidate ID is automatically a match, and no
published row/version/event is invented. Prior flat/unilateral-calf/reverse-crunch
proposals and standing-press suggestions are historical, superseded alternatives.

[STRENGTH_REVIEW_GRAPHS.json](STRENGTH_REVIEW_GRAPHS.json) has all twenty ordered
review bodies. It is **not an admissible publication artifact**: unknown identities
remain null; C1–C4 holds keep unknown effective prescriptions null while retaining
exact reference/proposal doses. The local `DRAFT-R2` protocol references are new
unpublished review revisions, not claimed published programme/exercise versions.
Source-specific preflight refuses any graph not exactly regenerated from pinned
inputs; the ordinary private graph decoder is not a catalogue identity validator.

The [running bodies](RUNNING_BODIES.json) preserve every executable step, target,
duration, distance and identity from `398a7fe`/the prior reconciliation. Only the
demonstrably misplaced personal W2 travel option is removed from general notes;
the 40-minute run is unchanged. Running-time bounds now explicitly distinguish
inherited optional walking recoveries from workout-clock minutes. No Garmin or
running harness verification is repeated. The final test stays distance-ended.

Reproduce without SQL, network, accounts or athlete operations:

```sh
python3 tool/programmes/hybrid_10k/apply_strength_selections.py --check
python3 tool/programmes/hybrid_10k/render_selected_review.py --check
python3 tool/programmes/hybrid_10k/selected_source_test.py -v
flutter test --no-pub tool/programmes/hybrid_10k/selected_admission_probe_test.dart test/programmes/private_protocol_graph_builder_test.dart
```

[Actual admission](../../../checkpoints/m11_hybrid10k_selected_strength/ADMISSION.json)
and [handoff](../../../checkpoints/m11_hybrid10k_selected_strength/HANDOFF.md)
retain the limits: schedules compile; 47 known-identity reference links pass
partial contracts; 59 identity occurrences/C1–C4 prevent complete admission.
The full genuine programme has not been acquired, started, logged, completed or
restored. Existing private v1/v2 is sufficient for this intake; no v3 producer or
hosted operation is added.
