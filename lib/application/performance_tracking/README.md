# Read-only History tracking adapter (C2)

`history_tracking_adapter.dart` is an unwired application projection. It imports
only core Dart, existing crypto and the C1 domain. It has no Supabase client,
runtime consumer, storage, result writes, ingestion or prescription adapter.
All new test definitions and source rows are synthetic.

The caller supplies an exact metric reference and its supported immutable
definition/method closure. Only field extraction is supported. Difference
signatures are not evaluated. The authenticated read port supplies raw History
rows before existing permissive parsers can default units, numbers or states.

## Read authority and coherence

The port must certify **one database statement snapshot** containing the exact
record, complete block/exercise/set tree and complete correction audit set.
`singleStatementSnapshot` and completeness flags are producer obligations, not
proof that a client can create by labelling an arbitrary map. Unproven/multi-read
hydration or truncation yields `coherent_read_required`, never a successful
missing result. The [strict RPC reader](coherent_history_rpc_reader.dart) and
[Supabase transport](../../infrastructure/performance_tracking/supabase_history_tracking_rpc_client.dart)
are locally implemented and unwired. Neither is registered with a production consumer.
See the [concrete read-boundary proposal](../../../docs/architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md).

The adapter denies a different/missing authenticated athlete before reading,
rechecks identity after the await, and verifies the returned record owner,
stable row IDs, parents and source-block snapshot identity. Duplicate IDs,
orphaned rows, mismatched audit ownership/session/scope and malformed source
fields are typed failures. Transport failures expose no exception details.

Optional programme claims require both matching raw History origin links and a
coherent verified witness from the future existing-authority join. That reader
must verify assignment/version/hash/occurrence/outcome/session and immutable
slot/protocol/block/running scope. C2 checks the witness exactly but does not
implement the join or accept matching labels as proof. The concrete RPC refuses
all supplied programme claims: retained History contradictions and missing links
are distinguished, while the required actual-session SELECT is unavailable. No
canonical package artifact or verified programme witness is admitted. Missing witnesses fail
closed; the adapter does not silently drop a claim and return independent data.
An independent observation makes no programme/test attribution claim.

## Supported raw field scopes

| Row/scope | Exact `fieldPath` | Canonical source unit |
|---|---|---|
| Block result type duration/distance/endurance | `result_data.durationSeconds` | seconds; integral numeric input |
| Block result type distance/endurance | `result_data.distance` | explicitly stored `m` or `km` |
| Set, with exact exercise/set IDs | `reps` | count; integral numeric input |
| Set, with exact exercise/set IDs | `load` | explicitly stored `kg` |
| Set, with exact exercise/set IDs | `distance` | explicitly stored `m` or `km` |
| Set, with exact exercise/set IDs | `duration_seconds` | seconds; integral numeric input |
| Structured running interval, exact workout/block/step/repeat | `result_data.intervals.paceSecondsPerKm` | explicitly stored `sec_per_km` |

Array ordinals, names and positions are never identities. Running pace must
match the retained structured-running snapshot and exact actual repetition.
No planned work duration, timer expiry, frozen pace target, implied distance,
whole-test score or other calculated field is admitted. Other field families,
legacy unit aliases and implicit conversions are not supported in this slice.

Native numeric actuals must be finite, nonnegative and representable as canonical
decimal strings; numeric strings, fractional counts/durations and exponent
representations are rejected. A real recorded zero stays zero. A missing field
does not become zero or a default unit. Known source units incompatible with
the metric remain incomparable with the original unit/value visible.

## Evidence and reference semantics

Successful no-visible-record or missing result rows is `missing`; read/identity
errors remain failures. A retained skipped scope is `skipped`, unstarted scope
is `missing`, incomplete scope is `partial` with selected-field coverage 0/1,
and completed work lacking the actual is `unavailable`. Coverage describes only
the selected single-field scope, never a full authored test. A complete selected
scope inside a partial session can remain available without claiming full-session
or test completion. Partial values are withheld unless the metric allows them;
partial evidence does not grant `trackingEligible`.

Comparison context comes only from the retained source snapshot's explicit
`comparisonFamily`. Required missing context, unsupported History source policy,
assessment requirements and unevaluated freshness make observations ineligible.
Explicit incompatible comparison conditions keep individual facts incomparable,
without calculating deltas. No assessment was proven merely by a programme link.

Selected-input SHA-256 covers format discriminator, exact metric ID/version/
digest, stable History field identity, canonical actual/unit, source capture
state, exact running capture-window/mapping/package inputs where used, explicit
context and original performed chronology. Object keys are sorted.
Audit membership is separately hashed in sorted identity order, including the
supplied raw audit data. Neither digest is a database revision or trust credential.
Optional view/programme claims and query timestamps do not change field identity.
No automatic profile upgrade, duplicate writable measurement or result cache.

A first current read does not need a guessed input digest. A selection created
from an existing C1 source reference pins its digest and optional audit ID;
changed inputs fail with `source_inputs_changed`. A new current read must be
explicit. Audit IDs are validated against the same coherent frame. Where audit
after-inputs cover an entire affected block or selected set input, contradictory
current inputs are rejected. Incomplete older set audits cannot prove omitted
duration/distance inputs; their omissions are not inferred or filled in.

Audit IDs are an unordered provenance set. `source.correctionId` is only a
verified requested audit reference, not a claim that this ID is the latest
field revision. Timestamp ties, transaction-start time and unrelated corrections
cannot establish commit order. C2 never synthesizes a result revision.
Historical reads always fail with `historical_inputs_unavailable`; all result
types report `canReconstructHistoricalInputs == false`.

Performed timestamps/dates remain original History facts. Civil dates retain
unknown timezone, not an invented zone or audit date. No freshness/zone evaluation
or new manual-entry chronology is implemented. `grantsPrescriptionEligibility`
is always false, including for available observations. Existing B2 policies,
frozen targets and blocked Cohort benchmark ingestion are unchanged.

## Local RPC verification boundary

`read_performance_tracking_history_v1(uuid,jsonb)` is a single STABLE SECURITY
INVOKER statement over owner-filtered existing RLS reads. It never calls the
legacy hydration, inserts results, locks for writes or falls back on a claim.
Limits are 10,000 aggregate child/audit rows, 4 MiB response and 16 KiB claim.
Counts, flags and markers are producer guarantees, not client-made certificates.
The bridge validates the closed envelope, parent identities and typed failures.
The Supabase transport makes exactly one RPC request and supplies no athlete ID.
No UI, application wiring, cache, ledger, ingestion or prescription path exists.

The [disposable gate](../../../supabase/tests/run_c2_coherent_history_read_gate.sh)
replays unchanged migrations, compares existing ACL/RLS/function fingerprints,
checks synthetic ownership/completeness/bounds and runs three two-session races
with a statement-snapshot barrier. Existing correction transactions and permissions
are preserved. This does not attest hosted permissions or privileged corruption.
See the [handoff](../../../docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md)
for stopped programme authority and canonical artifact gaps.
