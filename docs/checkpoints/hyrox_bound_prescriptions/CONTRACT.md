# Plan Package v3 personalisation binding — implemented local contract

2026-10-22 · base `b9fa429d96b9a4a43485aaa9e815a2f28472f0dd`.
[Scope](SCOPE.md) · [approved Base decisions](../hyrox_base_personalisation/DECISIONS.md).
The prior [additive plan](../hyrox_base_personalisation/ARCHITECTURE.md) proposed v3;
inspection confirms only v1/v2 were supported. **v3 is now the explicit new compile/review
capability**, rather than adding prescription fields to an existing schema. It is not a
production storage/publication capability. `tracking_profile_binding` remains reserved
and explicitly refused in every version; prescription binding never confers observational
profile/test attribution or prescription eligibility on C1/C2/C3.

## Authored shape and dependencies

Optional root `personalisation_binding`, permitted only in package v3:

| Field | Implemented meaning |
| --- | --- |
| `binding_schema_version` | Exactly 1; distinct from package, rule, definition and session versions |
| `freshness` | Exactly `none`; no invented age cutoff |
| `replacement_policy` | `explicit_consent_future_unstarted_only` |
| `missing_input_policy` | `unavailable_with_authored_effort_only`; only existing approved effort guidance |
| `targets` | Nonempty bounded ordered list, maximum 512; authored review order is retained and hashed |

Each typed target contains an exact unique `id`; `week_number`, `slot_key`, `session_key`,
`protocol_id` and `protocol_revision`; `session_body_sha256`; `block_id`; exact work
`step_ids`; `identity_namespace`; exercise, benchmark and rule references (`id`, positive
`version`, lowercase content `digest`); `kind`; input/output units; and explicit authored
parameters. Unknown/missing fields, wrong types, null binding, duplicate identities/scopes,
wrong week/session/revision/slot, unknown enum or unsupported policy refuse. A target
cannot coexist with B2 authored-running authority on the same slot.

| Kind | Input | Output | Required authored parameters |
| --- | --- | --- | --- |
| `runningIntervals` | `milliseconds` of 10 km completion | `millisecondsPerKilometre` exact faster/slower bounds | repetitions, work seconds, recovery seconds |
| `dedicatedRowIntervals` | `milliseconds` of 2 km row completion | `millisecondsPer500Metres` exact faster/slower bounds | repetitions, work seconds, recovery seconds |
| `backSquat` | `microgramsTotalExternalLoad` of back squat 5RM | `gramsTotalExternalLoad` after configured rounding | sets, reps, five_rm_basis_points, RIR |

This contract has no WOD row target or unrelated-lift derivation. Interval step lists bind
work repetitions exactly; recovery is structured in calculated prescriptions and never
inherits work pace. No recovery follows the last repetition. The retained rule artifacts
pin the approved brief digest, exact formula/unit/rounding meaning and all eight approved
week parameter rows. Benchmark definitions independently pin exact test meaning, input
unit, date/source requirements and explicit no freshness limit. No arbitrary formula or
rule selected by a user-supplied name/digest is executable.

The shared compiler requires a `PersonalisationDependencyResolver` whenever a binding is
present. Default legacy compilers refuse unresolved dependencies. The local adapter's
resolver checks complete repository-owned immutable rule/benchmark content, definition
references, units, identity namespace and exact authored parameters against the approved
Base rules. Supplying two equal untrusted hashes is not dependency resolution.

`synthetic_fixture` identities are explicit software fixture definitions such as
`fixture-backSquat`; they are **not** canonical `EX-*` ExerciseDefinitions or published
versions. The syntax can name a `canonical_exercise` namespace, but the current local
resolver refuses it as unresolved. No global/canonical exercise identity is created.
A production resolver needs authoritative published definitions, variants and version
bindings that do not yet exist for the complete Base source.

## Compiler, source resolution and hashes

The compiler validates exact package schedule/session links, closed binding syntax,
dependency references and approved rule parameters. It can only prove structural/dependency
consistency, not athlete ownership, content publication or actual source-body existence.
`BoundProgramme.compile` additionally resolves the exact session body and block from the
repository-owned synthetic source registry and verifies source digest, protocol revision,
block kind, exercise definition, step IDs and authored parameters. A recomputed package
hash with an invented body/block still refuses at source admission. There is no arbitrary
file-import path that can register trusted source bodies or consent.

v3 canonical bytes include every present programme-owned binding field and dependency
reference. Target order is authored order; nested map keys sort deterministically. Athlete
IDs, selections, consent, measured inputs, equipment configuration, calculated targets,
actuals and review time are absent from package hashes. Optional absent binding remains
valid; absence never grants targets. Every existing v1/v2 canonical shape and golden is
retained; malformed declared fields never silently drop or become an absent binding.
Old clients must refuse v3. No binding is attached to an existing immutable programme pin.

All v3 import payload building, application import preview/apply and trusted HTTP import
are explicitly refused. Application preview refuses before session/version reads, and the
HTTP endpoint returns structured 422 before its import RPC. This guard is necessary because
merely accepting v3 in the shared compiler must not imply server schema/admission support.
No SQL validator/canonicaliser/materialisation/storage/publication for v3 is delivered.

## Bound review, consent and local execution handoff

The dedicated Programme Studio bound review entry compiles the source fixture first,
then enumerates its actual bound slots and targets. It displays authored parameters,
selected evidence/revision, calculated target or explicit missing/unavailable reason, and
separate actuals. The older independent Base demo and all existing Studio entries are
unchanged; the new flow calculates from resolved compiled targets, not a separate week
selector or invented prescriptions. Both flows reuse the approved Base calculator.

`LocalBoundRepository` fixes one of two synthetic owners at construction. It accepts
validated `BaseBenchmark` values only for the three exact definitions, records append-only
local revision sequences/predecessor digests, and never selects an entry automatically.
Consent proposals are opaque repository-issued objects, tied to its current generation,
exact definition/evidence revision and compiled package. Explicit acceptance records a
local consent ID; cancellation or stale/foreign proposals cannot change selections. The
package hash transitively binds every rule/target scope covered by that selection.

All entry/configuration/selection/start/complete operations serialise through one local
transaction queue. Review captures selection/configuration generation and rejects late
or out-of-order replies. Start checks the exact current repository-issued receipt and
recomputes its reviewed prescription under the transaction lock. Start before update
freezes the old target; update before start invalidates the old receipt. Only a receipt
issued by that repository can replay an existing start; matching imported hashes cannot.

A started snapshot freezes the complete original source and its text SHA-256, canonical
package bytes/hash, target bindings/digests, exact session source, complete rule/benchmark/
synthetic-exercise dependencies, selected benchmark values/provenance/revisions and consent,
equipment configuration/generation, calculated structured prescriptions, review digest and
UTC start time. Snapshot JSON is immutable; completion/actual load is a separate record.
Changing benchmarks, configuration or completing a session never rewrites started/completed
prescriptions or automatically progresses targets. Local actual squat load is accepted
only on a slot with a bound squat target.

## Explicit limits and source completeness

The fixture contains eight weeks of **partial synthetic target sessions**, 16 local
session references / 24 run, dedicated-row and squat targets. It omits other day/session
content; sparse day keys are source addresses, while `day_order` orders only these local
fixture entries. It is not a new approved weekly schedule or a 48-session commercial
programme. Only already approved doses are encoded. Source bodies are software fixtures,
not production sessions. The provided callable repository and full frozen handoff are an
in-memory integration/test double; there is no durable save/reload/authentication/SQL layer.
No genuine athlete starts, programme assignments, hosted calls, native browser checks,
Garmin export, phone checks or broader Stage 2/Sprint C closure are implied.
