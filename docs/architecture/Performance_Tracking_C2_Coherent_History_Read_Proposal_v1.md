# Performance Tracking C2 — coherent History read boundary

**Recorded:** 2026-10-05

**Current status:** reviewed independent C2 integrated through `144ba110`;
exact RPC migration applied/SELECT-verified on Cohort Field Manual, ledger 115.
[Deployment closeout](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
records unchanged permissions/data. Programme witness remains BLOCKED; bridge/
adapter remain unwired and production wiring unauthorised. Hosted session SELECT
exists with RLS disabled; local denied-SELECT proof is not a hosted permission
claim. Complete joined witness/artifact authority is not implemented. The original
proposal and local continuation below are preserved as historical design evidence.
[Independent reader review](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md)
records the claim-absence fix, both authenticated permission paths and a concrete
separately scoped owner-gated witness/artifact proposal. No authority expansion
is implemented.
The independent [pure C2 adapter](../../lib/application/performance_tracking/history_tracking_adapter.dart)
is implemented locally with synthetic fake-port proof. The original proposal below is preserved as design context; the continuation
boundary below records what could be proven without widening permissions.

Binding: [revised Sprint C contract](./Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
and [C1 review](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_REVIEW.md).

## Existing authority inspected

- [PerformanceRecordStore](../../lib/features/performance/repositories/performance_record_store.dart)
  owns existing History reads. Its API returns hydrated records, not complete
  correction identity/input provenance or a coherence guarantee.
- [SupabasePerformanceRecordStore](../../lib/features/performance/repositories/supabase_performance_record_store.dart)
  reads header, blocks, exercises and sets separately. It then selects only
  the newest `corrected_at` timestamp. A correction may commit between these
  requests. Two equal timestamps or two equal client reads are not a revision
  fence or proof that every selected input came from one snapshot.
- [Existing History tables/FKs](../../supabase/migrations/20260719160000_add_training_session_records.sql)
  connect record → block → exercise → set. Existing authenticated read authority
  and RLS remain the source; C2 must not introduce a second results ledger.
- [Correction authority/audit table](../../supabase/migrations/20260904120000_correct_completed_performance_record.sql)
  locks the owned completed record and appends audit provenance. The
  [current correction function](../../supabase/migrations/20260905121000_correct_interval_performance_record.sql)
  updates actuals and inserts audit in one transaction. A single statement
  snapshot can see their committed state together; independent hydration cannot
  claim that guarantee.
- The current set audit payload records selected reps/load/completed fields but
  does not contain every corrected duration/distance input. Audit timestamps are
  transaction time, not an independently proven commit sequence. Complete
  historical reconstruction and an inferred latest field revision are refused.

No existing complete coherent read RPC was found. Existing FK relationships may
permit a single embedded PostgREST SELECT for the History tree; that alternative
still needs proof of statement scope, full audit/child completeness and the
programme authority joins below. C2 does not ship an unverified embedded query
or relabel the existing hydration as atomic.

## Recommended concrete boundary

Reserve a versioned read-only function:

`read_performance_tracking_history_v1(p_record_id uuid, p_programme_claim jsonb default null) returns jsonb`

Recommended implementation is one **STABLE, SECURITY INVOKER SQL statement**
over existing RLS-protected read authority, with nested JSON aggregation. It
must not call completion/correction/start/schedule functions, lock for writes,
mutate data, create a measurement table or grant new result-write permissions.
Function creation and its narrow authenticated EXECUTE grant require separate
local migration authority and proof before any deployment is proposed.

Input rules:

1. Actor comes only from the authenticated session (`auth.uid()`); there is no
   caller-controlled athlete/role argument. Exact owned record lookup; a missing
   or non-visible record has the same non-leaking response. SQL UUID/type and
   closed optional-claim checks reject malformed input.
2. Optional claim pins assignment, occurrence, training session, programme
   version/hash, package slot key, protocol ID/revision, block ID and optional
   workout/step/repeat/mapping hash. Reject partial or contradictory claims.
   Absence means independent observation, not inferred programme/test attribution.
3. No date/label/ordinal/name matching, latest-profile selection, manual import,
   as-of reconstruction or prescription-policy request parameters.

Response contract for `HistoryTrackingReadPort.readCurrentRecord`:

- Authenticated athlete ID and either explicit no-visible-record or raw owned
  `training_session_records` row.
- Complete flat raw rows from `training_block_results`,
  `training_exercise_results` and `training_set_results`, using the exact
  existing parent FKs; no permissive Flutter model defaults.
- Complete `performance_result_corrections` membership for the same record,
  including correction ID, record/athlete/session IDs, corrected timestamp and
  before/after payloads. Do not select only a timestamp or infer an ordered
  immutable result revision. Provenance must not expose another athlete's rows.
- `singleStatementSnapshot`, complete-tree and complete-audit guarantees are
  emitted only by the proven producer. Counts/aggregation must establish that
  no nested rows were truncated. Resource bounds must return a typed failure
  rather than successful partial arrays. No client-generated snapshot marker
  can certify separately fetched rows.
- If a programme claim is supplied, return a normalized scope witness **only**
  after the authority chain below is verified from the coherent read. Missing
  historical links return scope-unproven; contradictions return typed failure.
  The client does not silently drop the claim and retry as independent evidence.

The programme join must verify existing athlete assignment ownership and pinned
version/materialised hash; published immutable version/package authority;
occurrence assignment/version/hash/slot/protocol; linked outcome training session
and occurrence; actual session owner/protocol; History record assignment/session;
and exact immutable authored slot/protocol revision/block. Running claims also
pin the retained canonical execution mapping and exact step/repetition. Reuse
existing canonical package validation for bytes/hash and authored content rather
than trusting matching hash strings or display metadata. Design the reader
bridge to validate any returned immutable artifact before admitting the witness;
do not modify package schemas or existing programme resolvers through C2.

## Required proof before admitting a production reader

Use disposable local/fake-port evidence; hosted contact remains separately gated:

1. Cross-athlete denial, unauthenticated denial and unchanged authenticated RLS;
   no new result/audit writes or access broadening.
2. Correction race: a current snapshot is wholly before or wholly after the
   existing atomic correction, with matching actuals/audit membership. Force
   interleavings that fail under the old multi-query hydration.
3. Exact parent identity, duplicate/ambiguous running scopes, explicit unit/type
   validation, unsupported shapes and successful missing/partial/skipped states.
4. Complete child/audit collections under configured bounds; no pagination,
   truncation, missing audit identities or timestamp ties masquerading as a
   successful uncorrected/current revision.
5. Complete optional programme authority chain; old incomplete links never
   become a programme test by inference. Independent observations still work.
6. Digest/reference staleness, incomplete older audit inputs and explicit
   historical refusal. Current observations never grant B2 prescription
   eligibility, promote Cohort ingestion or alter frozen targets.

The pure adapter's fake-port tests are not database concurrency/RLS proof.
Approve/design the reader boundary and local migration separately before
implementing this portion. An embedded SELECT alternative may replace the RPC
only after meeting the same concrete guarantees and acceptance checks.

Selection/custom-profile storage, manual entry/correction writes, derived metric
calculation, comparison deltas, scoring, real profiles/tests, UI, production
wiring and schema v3 remain separately scoped. Stop for founder review.

## Authorised local continuation — 2026-10-05

Founder authorised the local migration, unwired bridge and disposable proof from
clean `5623a7975c583ef324ecc62d8ec7932bc60ea2fa`. See
[coherent reader handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md).
The additive [migration](../../supabase/migrations/20261005130000_performance_tracking_coherent_history_read.sql)
implements one STABLE SECURITY INVOKER SQL statement with `pg_catalog, pg_temp`
search path, schema-qualified existing tables, auth.uid ownership, complete raw
result/audit collections and authenticated-only client execution. No existing
relation grants, RLS, helpers or mutation functions change. Missing/inaccessible
owned records share one response. Limits are 10,000 total child/audit rows,
4 MiB returned JSON and 16 KiB optional claim JSON; excess fails explicitly.

The [strict bridge](../../lib/application/performance_tracking/coherent_history_rpc_reader.dart)
and [transport](../../lib/infrastructure/performance_tracking/supabase_history_tracking_rpc_client.dart)
are explicitly constructed, with no production registration. Envelope keys,
counts, UUIDs, ownership, graph parents, audit scope and actor changes are checked;
unknown witnesses/artifacts and ignored claims are refused. Supported field,
unit, chronology and correction validation stays in the existing adapter.

**Stopped authority:** the fresh disposable baseline has no authenticated SELECT
on `public.training_sessions`; that table has RLS disabled. No repository migration
establishes this SELECT. Its historical baseline notes explicitly exclude hosted
GRANT ALL, so this finding does not attest today's hosted ACL. The required actual
session owner/protocol join cannot be proven here. No SECURITY DEFINER fallback,
new helper, SELECT grant or RLS widening was implemented. The function checks
retained History assignment/session/protocol references only: absent links return
`programme_scope_unproven`, contradictory retained links return
`programme_scope_conflict`, and otherwise a supplied claim returns
`programme_authority_unavailable`. No supplied claim is dropped. This is not a
verified programme witness, and complete assignment/occurrence/outcome/package/
protocol/block/running joins remain unimplemented and unproven.

Canonical package bytes are not retained as a complete artifact in these source
tables (original phase/session keys are not persisted). The bridge admits no
programme witness or purported canonical artifact, so it cannot claim package
byte/hash validation. Resolving session access alone would not close this gap.
A later, separately scoped witness design must provide an immutable hash-pinned
artifact, reuse the canonical compiler, and prove exact authored scope against
the same coherent authority frame; no package reconstruction by labels/ordinals.

The next founder decision is a separately reviewed existing-authority read design
for the missing session join, including row isolation, plus the immutable artifact
source. A blanket SELECT grant on an RLS-disabled table is not the recommendation.
Do not infer hosted parity, alter table permissions or enable full witnesses from
this local proof. Hosted apply and production wiring remain separately gated.

The focused local gate proves complete owned evidence under the existing policies
and canonical correction path, not detection of privileged out-of-band database
corruption or future policy drift. All audit IDs are retained without a timestamp
ordering claim; incomplete old audit payloads remain incomplete. Tracking cannot
grant prescription eligibility or reconstruct missing historical inputs.
