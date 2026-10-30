# General Hybrid 10K movement review overlay

Base `a22249e`, 2026-10-30. **Draft review overlay; no source variant selected,
published, assigned or approved by producing this packet.**

Start with the single [founder packet](FOUNDER_REVIEW.md), then
[provenance](PROVENANCE.md), [unique movement ledger](UNIQUE_MOVEMENTS.md),
[exact evidence](LOCAL_IDENTITY_EVIDENCE.json) and [six conditional proposed
records](PROPOSED_IDENTITIES.json). The [current complete source](../general_draft_2026_10_30/SOURCE.json)
and its [ordered dose matrix](../general_draft_2026_10_30/ORDERED_REVIEW.md) stay
byte-identical to `a22249e`. This overlay corrects the earlier overbroad source
reconciliation status; it does not silently replace the attachment's exercises.

[STRENGTH_REVIEW_GRAPHS.json](STRENGTH_REVIEW_GRAPHS.json) rebuilds all 20 ordered
strength bodies with exact native prescriptions. It is **review-only**, with
explicit null IDs and hold references for 87 unresolved occurrences. Never pass
it to the publisher/decoder as an admissible graph or fill nulls by label. The
source-specific builder verifies [pinned files](SOURCE_PINS.json) and refuses
source/identity/dose/approval substitutions. Existing private graph validation
does not itself establish catalogue identity; no runtime contract was weakened.

Reproduce the bounded local evidence (no network/SQL/account operation):

```sh
python3 tool/programmes/hybrid_10k/build_movement_review.py --check
python3 tool/programmes/hybrid_10k/movement_review_test.py -v
flutter test --no-pub tool/programmes/hybrid_10k/movement_admission_probe_test.dart test/programmes/private_protocol_graph_builder_test.dart
```

The [current handoff](../../../checkpoints/m11_hybrid10k_movement_review/HANDOFF.md)
and [actual admission result](../../../checkpoints/m11_hybrid10k_movement_review/ADMISSION.json)
separate full schedule compilation, withheld full graphs, extracted partial
contracts and the unchanged final-10K execution gap. Previous running/Garmin
evidence is attributed to immutable checkpoints and was not rerun.
