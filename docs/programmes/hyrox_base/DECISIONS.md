# Provenance and consolidated decision register

2026-10-24. [MASTER.md](MASTER.md) is the consolidated readable specification;
[PROGRESSION.json](PROGRESSION.json) is the editable local review input. This is a
source consolidation checkpoint, not final commercial publication or Stage 2 closure.

## Evidence and status

| Evidence | Status and permitted use |
|---|---|
| [2026-10-22 founder brief](../../checkpoints/hyrox_base_personalisation/FOUNDER_BRIEF.txt), SHA-256 `5ae2ebcc020883ce2f496b457296d349ee1793c513818501d616238341d32056` | Explicitly approved eight-week purpose, schedule, running/rowing/squat rules and benchmark policy; retain unchanged. |
| [Existing decisions](../../checkpoints/hyrox_base_personalisation/DECISIONS.md) | Historical approved decisions and then-missing inputs; supporting inputs now transferred here, without rewriting historical evidence. |
| [Exact current transfer](TRANSFER_BRIEF.txt) | Direct founder instruction authorising consolidation/local representation. Supporting prescriptions are accepted direction for review, not blanket final content approval. No original supporting conversation was supplied for independent approval reconstruction. |
| Transfer: wall balls at selected race weight and race-standard target | Explicit founder requirement. Actual division/load/height values are unresolved; no defaults supplied. |
| Transfer: W6/W7 long runs both 65–80 min | Latest explicit correction/reaffirmation. The retained 2026-10-22 brief and calculator already agree. No older contradictory numerical value is supplied here; do not invent one or overwrite that evidence. |
| Transfer: original W1 cable row 3×10/side vs later 3×10–12/side | Both retained; session source selects neither pending D1. The transfer reports the earlier value; this task has no original earlier conversation to assert its approval status. |
| Transfer: original W1 plank 20–30 s vs later 20 s | Both retained; session source selects neither pending D2. Same provenance limit applies. |
| Compiler/model/identity observations | Technical findings only. A software representation, matching hash, catalogue row or fixture cannot confer content/publication approval. |

The transfer's optional load/leverage progression remains optional and athlete accepted.
Its finisher loads are selected by effort/technique; no fixed kilograms are added. Only
back squat uses approved percentage loading; the OHP benchmark creates no new load rule.

## Remaining content decisions — one consolidated list

| ID | Exact decision | Affected sources |
|---|---|---|
| D1 | Select W1 split-stance single-arm cable row **3×10/side** or **3×10–12/side**. Later range is not silently approved. | W1 Gym C |
| D2 | Select W1 long-lever plank **3×20–30 s** or **3×20 s**. | W1 Gym B |
| D3 | Resolve full-duration policy for an 80-min main long run + 10-min preparation + 5-min walk = **95 min**, while preserving current source until decided. Does “generally/about 90” admit this, or must a separately approved component/window change? | W3/W5/W6/W7 long runs; W6/W7 stay 65–80 min main |
| D4 | Supply authoritative race-division mapping and selected-division dependency for wall-ball load and target height. Requirement itself is explicit; values are not. | All eight Gym C finishers |
| D5 | Review/approve the transferred supporting doses, variants, preparation and finishers as a consolidated commercial source, including equipment/prerequisites/exclusion copy and actuals/scoring requirements. The current task authorises local representation only. | All supporting content; final programme approval remains open |
| D6 | Supply squat working-set rest and, where exact execution/timing is required, ramp-up quantities/loads/rest and quality-run dynamic-preparation movements/duration. Core rest is 45–60 s “as needed”; side/set placement and transitions remain unspecified rather than guessed. | Eight Gym A and eight quality sources explicitly flagged; all gym timing remains partial |

D5 is programme-wide review status and is not counted as 48 independent dose conflicts.
The audit's primary status highlights D1/D2/D3/D4/D6; it retains technical blockers in
parallel. Short sessions receive no filler merely to reach 60 minutes.

## Technical dependencies, separate from content decisions

- **T1 — exact identity/version/source resolution (all 48):** no real authoritative
  published ExerciseDefinition/version/event bundle or approved source-to-definition
  variant bindings was supplied. [AUDIT.json](AUDIT.json) enumerates every authored
  movement label, including preparation, with null exact ID/version/event/digest.
  Existing accepted transitional mappings establish identities only (e.g. running
  `EX-129`, row `EX-049`, squat `EX-073`, strict press `EX-088`, pull-up `EX-053`,
  RDL `EX-078`, SkiErg `EX-050`, wall ball `EX-052`). They do not accept a particular
  Base variant or supply immutable definition versions. A long-lever plank is not
  automatically mapped to generic plank; suitcase carry is not farmer carry, and
  reverse lunge is not walking lunge. No names/adjacency are used for resolution.
- **T2 — gym source lowering:** `StrengthExercisePrescription` already preserves rep
  ranges, per-side and grouping, but has scalar `restSeconds` and scalar RIR load.
  The Founder YAML mapper additionally does not pass `per_side` into that model.
  Do not collapse ranges or lose laterality through that importer. TimerConfiguration
  supports EMOM totals/intervals and station specs, but these exact mixed timed/rep/
  rest station sources and scaling need end-to-end graph/capture proof after T1.
  Dedicated bound row/squat source admission is strict; mixed finishers cannot be
  relabelled as dedicated intervals. No unsupported runtime lowering is attempted.
- **T3 — continuous running windows:** the existing time runner executes a selected
  duration, not this source's unselected min/max choice. A lossless athlete-choice
  handoff and exact source identity must be established; do not pick a midpoint,
  minimum, maximum or different B2 policy automatically.

Exact physical protocol/revision/block/step/slot IDs, complete immutable bodies and their
hashes must be obtained through the established source/compiler path after resolution.
The 24 rule intents (8 each quality/row/squat) are validated against existing code but
are **not** executable v3 target bindings. No caller-crafted definition/version/history
or synthetic EX-900xxx fixture fills T1. Real trusted producer integration, capability
provisioning and hosted deployment remain separate blockers under the existing
[HTTP handoff](../../checkpoints/hyrox_v3_http/HANDOFF.md).
