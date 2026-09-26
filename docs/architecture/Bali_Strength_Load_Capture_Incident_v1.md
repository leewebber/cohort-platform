# Bali strength load-capture incident

**Status:** Open athlete-facing capture incident after private graph repair.
**Base:** `origin/main` `7385e8809d1fc1c8d0ea4f73a990ed55ca5b0679`
**Branch:** `fix/bali-strength-load-capture-v1`

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_ASSIGNMENT_CURSOR_INCIDENT=RESOLVED
BALI_PROTOCOL_GRAPH_INCIDENT=RESOLVED
BALI_STRENGTH_CAPTURE_INCIDENT=OPEN
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Week 1 Saturday Strength A compiles and lists the authored movements.
Loaded working sets expose reps only. No kg input is available. No
workout has been started.

---

## Known cause

Founder YAML records working-set effort as

`load: { type: freeText, text: "RPE 7" }`.

The private graph builder copied that object and omitted
`performance_capture`. Hosted `session_block_exercises.prescription`
matches that shape. Rest ranges such as `180-240` were not stored as
`rest_seconds`.

`StrengthActualLoadKind.fromPrescription` treats recognised load types
(`athleteSelected`, `rpe`, `fixedKg`, …) as external kg capture. A
present but unrecognised `freeText` load on a strength block becomes
`none`. Warm-up / cooldown blocks without load correctly stay
reps-or-completion only.

The Plan Package hash covers schedule and identity only. It does not
cover protocol bodies or capture metadata.

Apollo loaded strength exercises typically omit a freeText load object
on a strength block, so the same helper defaults them to external kg.

---

## Permanent invariant

Authored protocol-graph prescriptions must carry each exercise’s
required capture dimensions using existing Cohort authorities:

- loaded resistance → `performance_capture.load_unit` plus load + reps
- RPE where the source requires logging RPE
- bodyweight / reps-only → `load.type = bodyweight` or no external unit
- weighted pull-up / chin-up → external kg, not bodyweight
- unilateral work keeps the authored per-leg / per-side reps text
- carries → load + supported distance/completion
- timer/endurance capture unchanged

Runtime must not infer load from exercise names. Home’s fail-closed
compiler is not weakened.

---

## Immutability

In-place capture correction is authorised only when:

- version ID and package hash remain
  `b1a1b001-0000-4000-8000-ba11b0010001` /
  `f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b`
- hosted graph identities (protocol, block position, exercise id/order)
  still match the approved graph
- only prescription/capture metadata is updated
- no Bali session, record, or outcome exists
- assignment, pin, schedule, dates, occurrences, and Apollo are
  unchanged

---

## Authorities

- Permanent: founder YAML + `PrivateProtocolGraphBuilder` emit complete
  capture metadata; publish validates it before `published`.
- Repair: `repair_private_programme_exercise_capture(jsonb)` —
  service-role only, identity-safe, prescription-only, atomic,
  idempotent.

No ad hoc UPDATE. No re-enrolment. No catalogue exposure.
