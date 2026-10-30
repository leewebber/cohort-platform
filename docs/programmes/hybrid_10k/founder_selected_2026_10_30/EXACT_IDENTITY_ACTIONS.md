# Trusted catalogue lookup — retained matches and three remaining actions

Founder-authorised read-only lookup, 2026-10-30. Field Manual
`otnhhdxstdnwccehacku` was ACTIVE_HEALTHY; one bounded SELECT through the dedicated
read-only Management API returned six relevant rows. No hosted data was changed.
[Receipt and raw evidence](../../../checkpoints/m11_trusted_catalogue_lookup/LOOKUP_RECEIPT.json)
retain source, time, query and response digests. These are observed legacy catalogue
rows, not newly created canonical ExerciseDefinition versions or publication events.

## Retained exact matches

| Selected movement | Actual retained identity and supporting evidence |
|---|---|
| Strict initial bodyweight pull-up | Published `EX-053`, slug `pull-up`, Pull-up Bar, Vertical Pull; dead-hang/control cues. Existing founder-approved bridge identifies strict/bodyweight pull-up separately from weighted/chin-up identities. The selected grip/effort remains authored source, not an invented published setup field. |
| Dumbbell lateral raise | Published `EX-044`, slug `lateral-raise`, One Dumbbell/Two Dumbbells, controlled shoulder-height raise/lower cues. The two-DB source uses a supported equipment branch. |
| Bench-supported single-arm DB row | Published `EX-038`, slug `single-arm-dumbbell-row`, Bench + One Dumbbell, Horizontal Pull, controlled elbow-to-hip cues. Source free-hand support/per-side prescription remains unchanged. |

NULL `setup`, `execution`, `unilateral` and `loading_options` values remain NULL in
the evidence. No published field is filled from a display label or programme cue.
The exact published rows plus explicit compatible source/approved bridge support
these three v1/v2 matches; nothing is seeded globally or mapped by name similarity.

## Three precise remaining records / separate approval

| Selected movement | Actual lookup result | Missing evidence and smallest action |
|---|---|---|
| Bilateral chest-supported **DB** row | `EX-090` is published; equipment says “Chest Supported Row Machine or Bench”; setup/execution/cues are NULL. | Catalogue owner must confirm/publish explicit two-DB bench-branch coverage, or return the actual distinct DB identity. A bench label alone does not establish the DB implement. |
| Seated supported neutral-grip two-DB strict press | `EX-037` is published with One/Two Dumbbells; setup/execution are NULL; no seated/back-support candidate was returned. | Owner must confirm/publish seated, near-upright back support, neutral two-DB, no-leg-drive coverage under the legitimate identity, or provide the actual distinct exact record. |
| Loaded two-DB reverse lunge | `EX-026` is published but equipment, setup, execution and loading options are NULL; no exact loaded two-DB candidate was returned. | Owner must establish actual loaded side-held neutral-grip coverage or author the exact record through normal deduplication. Historical CSV “None” is not current hosted equipment; NULL is neither bodyweight proof nor loaded approval. |

The three exact proposals are [SETUP_PROPOSALS.json](../../../checkpoints/m11_trusted_catalogue_lookup/SETUP_PROPOSALS.json).
Required approval is a **separate, bounded catalogue-owner/producer setup/identity
publication action** for those selected variants. This task does not perform it.
Approval alone creates no published evidence: actual producer-backed records must
be retained and verified afterward. No invented ID/version/event, new coaching dose,
programme publication, migration or deferred v3 producer is required here.

Discovery was bounded to the named leads and relevant reverse-lunge/seated-DB-press
candidates, with a 20-row cap that was not reached. “Not returned” is not a claim
that every possible unpublished alias anywhere in the catalogue was audited.
Assisted pull-ups remain separate unresolved branches; weighted `EX-095` is not
the initial bodyweight identity. D8/full-programme approval remains pending.
