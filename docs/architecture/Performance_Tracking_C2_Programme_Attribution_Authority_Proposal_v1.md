# Performance Tracking C2 — bounded programme-attribution authority

**Recorded:** 2026-10-05. **Status:** FOUNDER_APPROVED; LOCAL_IMPLEMENTED_VERIFIED_AWAITING_REVIEW.
[Implementation handoff](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md)
records the exact local boundary, migrations and gates. No hosted apply or wiring.
The inspection evidence below is the original proposal survey.
Inspected clean, fetched HEAD/origin/main:
`005d53dc9b822d7e8075c75e5679324b93edebf2`. No hosted contact or tests during the original proposal inspection.
The [C2 deployment record](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
is historical verification, not a refreshed hosted survey. Independent coherent
History reads are deployed; adapter/bridge remain unwired. Programme claims
remain blocked in the deployed independent reader; local attribution is now
verified as recorded in the handoff. This refines the [existing witness proposal](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md#programme-witness-follow-up--proposal-only)
and supersedes its read-time caller-supplied canonical-artifact option.
Binding: [approved tracking architecture](./Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[C1 contracts](../../lib/domain/performance_tracking/README.md),
[C1 review](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_REVIEW.md).

## Recommended implementation boundary

One separately authorised **local infrastructure slice**: a new owner-gated
combined read RPC, strict unwired bridge, immutable server-owned publication
artifact retention, and future-publication capture through the existing trusted
publisher. These are the minimum parts of a provable positive attribution path.
Synthetic fixtures only; no real publication, programme edits, assignment
changes, production consumer, hosted apply or permission remediation. A reader
alone cannot unblock legacy versions whose canonical authority is absent.
Keep deployed independent `read_performance_tracking_history_v1` unchanged.
Package schemas/hashes v1/v2 stay unchanged; schema v3 is unnecessary here.
Selection storage, manual entry, assessment/test flows, scoring, formulas,
calculations and prescription policy remain outside this boundary.

## Combined RPC contract and ownership

Approved signature (implemented locally, unwired):
`public.read_performance_tracking_programme_history_v1(p_record_id uuid, p_programme_claim jsonb) returns jsonb`.
The claim is required and closed. It pins assignment/occurrence UUIDs, actual
training-session BIGINT as a decimal string, programme-version UUID, package
SHA-256, slot key, protocol ID/revision and authored block ID. Running claims
also require workout ID, step ID, repeat ordinal and mapping SHA-256 together.
Reject unknown keys, null/partial claims, invalid types and out-of-range values;
the source block must resolve to an exact UUID in this database. Every supplied
claim is compared. No caller athlete/role, artifact bytes, as-of, policy or
latest-version parameters. The supplied hash is an assertion to check, never
the authority to trust.

Identity is only `auth.uid()`. Anchor first to the exact owned
`training_session_records.record_id`, with `athlete_id = auth.uid()::text`.
No coach override. Resolve private joins from that record's retained links,
then compare the claim; do not probe arbitrary caller-nominated foreign rows.

| Required authority | Exact checks in the same statement |
|---|---|
| History origin | Retained assignment ID, training-session ID, programme-session ID and source protocol; requested source block uniquely identifies a child block result under this record |
| Assignment/pin | `programme_assignments.id = record.assignment_id`; assignment athlete is actor; pinned version and materialised package hash/schema agree with server version/artifact. An inactive assignment is allowed when these retained links prove it |
| Projection/occurrence | `programme_schedule_projections` matches assignment, athlete, version/hash; claimed occurrence matches assignment/version/hash, session slot, protocol, programmed-session key and authored week/day/session order. Placement date is not identity |
| Outcome | Join `programme_slot_outcomes` by exact assignment + session slot to the occurrence; there is **no outcome occurrence_id FK**. Check retained version/materialised hash, programmed-session key and actual session. Completed/partial outcomes require `completion_record_id = record.record_id`; missing historical completion links are unproven. In-progress evidence cannot claim completion; replacement protocol conflicts cannot be relabelled as original scope |
| Actual session | `training_sessions.id = record.training_session_id = outcome.training_session_id`; athlete is actor and protocol is the exact authored protocol, independently of RLS or direct table permissions |
| Authored slot/version | Record programme-session ID = occurrence session-slot ID = `programme_version_session_slots.id`; slot → day → week → exact pinned version; `package_slot_key` matches claim and retained canonical artifact. Server version is published/archived with original publication/hash and supported immutable authority; drafts fail |
| Protocol/block | Artifact session reference pins protocol ID, session lineage and revision; `performance_protocols` agrees. Exact `session_blocks.block_id` belongs to that protocol and matches History `source_block_id` and the retained publication scope seal below; no reconstruction by name/position. Missing original scope seal or contradictory current graph cannot produce a witness |
| Running scope | Canonical slot mapping, persisted authored-running document and History structured-running block snapshot agree on workout/block/step/repeat and mapping hash. Require matching frozen occurrence/session/assignment links wherever that execution source requires them; never infer a missing link or treat targets as measured results |

Full raw History header, blocks, exercises, sets and **all** correction members
come from the same owned tree. Check every child parent; correction record,
athlete and retained session links must agree. A contradictory/cross-owner audit
row fails generically without its payload, rather than filtering it out and
claiming completeness. Preserve exact field paths, result identities, audit IDs
and input digests; existing strict adapter validates supported shapes/units and
missing, partial, skipped, unavailable and incomparable evidence states.

Absent/inaccessible records have identical responses, including with a claim;
neither admits programme scope. Missing private links/artifacts return
`programme_scope_unproven` with bounded reason codes. Contradictions in owned
retained links return `programme_scope_conflict`. No foreign IDs, payloads or
counts in failures. No successful programme frame on failure and no automatic
fallback to independent evidence. An explicit separate independent v1 read is
still possible. Session attribution does not prove an authored assessment was
performed or grant B2 prescription eligibility.

## Narrow definer boundary and coherence

Use one LANGUAGE SQL **STABLE, SECURITY DEFINER SELECT**, with materialised owned
anchors and qualified relations. This introduces a new bounded read authority
over existing records; the old public reads do not already provide it. Function
owner is the trusted migration owner (`postgres`), never a client role. Because
that owner can bypass RLS, explicit actor/parent predicates protect every private
branch, including training sessions, assignments, outcomes, snapshots and audits.
RLS must not be claimed as the definer's isolation guarantee.

Fixed `search_path = pg_catalog, pg_temp`; schema-qualify `auth.uid()`, digest and
every relation/helper. Authenticated EXECUTE only; revoke PUBLIC, anon and
service_role execution. No new client SELECT/write grants or RLS widening.
No dynamic SQL, caller-selected objects, mutation/volatile helpers, write locks,
calendar ensure/reconcile calls or client access to internal validators. Review
any reused helper as STABLE/IMMUTABLE and purely read-only under the same
snapshot; otherwise inline its validation. Do not call invoker v1 under the
definer and assume it retains client RLS protections.

Reuse validation patterns, not endpoints: [assigned graph policies](../../supabase/migrations/20260926150000_assigned_programme_graph_read.sql),
[package graph checker](../../supabase/migrations/20260731120000_authored_plan_package_import.sql),
and [B3 internal scope checks](../../supabase/migrations/20260929120000_b3_structured_running_targets_and_actuals.sql).
The [calendar resolver](../../supabase/migrations/20260924120000_completed_fixed_programme_calendar_inspection.sql)
can write on its active path; the [occurrence JSON helper](../../supabase/migrations/20260926190000_fixed_occurrence_time_of_day.sql)
lacks a standalone ownership gate. Neither supplies this combined authority.
Internal helper client grants stay unchanged; denied validator execution is not
bypassed to obtain present-day proof.

The [existing correction transaction](../../supabase/migrations/20260905121000_correct_interval_performance_record.sql)
updates actuals and appends audit atomically. One statement snapshot must read
the whole raw tree, correction membership, programme witness and publication
artifact before or after a concurrent commit, never separate RPC/hydration reads.
Complete audit membership does not recover omitted prior duration/distance inputs;
tied timestamps do not establish commit order or a latest field revision.
`canReconstructHistoricalInputs` and `grantsPrescriptionEligibility` stay false.

Versioned strict response: actor + complete raw C2 frame + normalized witness +
server-retained canonical UTF-8 text, original schema/hash and publication
provenance + narrowly necessary authored scope. Bridge checks actor continuity,
closed envelope/counts, exact links and independently recompiles the artifact
with the [existing compiler](../../packages/cohort_plan_package/lib/src/plan_package_compiler.dart).
Canonical bytes must match exactly and hash to the server-pinned digest; valid
JSON, equal hash strings or a content-graph digest cannot substitute for that.
Only then produce the existing `HistoryProgrammeWitness`; no production wiring.

Bounds: 16 KiB claim; 10,000 total History child/audit rows; 1 MiB artifact;
4 MiB complete response including artifact/scope. Exactly one matching artifact
and claimed authored scope; duplicates fail. Oversize returns explicit
`evidence_limit_exceeded`, never truncation/pagination disguised as completeness.
Evaluate counts/byte sizes before building oversized output. These bounds do
not guarantee execution time; prove bounded failure behavior in the local gate.

## Canonical authority: retained bytes, reproduction and legacy outcome

**No original full canonical artifact retention was found in the inspected
supported publication paths.** [v1 import](../../supabase/migrations/20260731120000_authored_plan_package_import.sql)
stores schema/hash and normalized graph; its graph checker explicitly says
phase_key is not stored. Session keys resolve to protocols rather than retaining
the original session catalogue. [v2 publisher](../../supabase/migrations/20260927120000_plan_package_v2_authored_running.sql)
SHA-256-checks `package_canonical_json` as exact UTF-8, compares graph payloads,
then delegates publication; the text is a transient variable, not stored.
The [payload builder](../../packages/cohort_plan_package/lib/src/plan_package_import_payload_builder.dart)
currently sends it only for v2. Content-graph `canonical_payload` is a relationship
manifest. Local source/publication files and synthetic compiler goldens are not
server-retained immutable publication artifacts. No external archive or hosted
artifact inventory was contacted; unknown storage is not positive evidence.

**Exact general reproduction is not provable.** The [canonicaliser](../../packages/cohort_plan_package/lib/src/plan_package_canonicaliser.dart)
includes phase keys, session keys/catalogue and metadata absent from normalized
rows. Synthetic counterexample: consistently rename a phase key and its week
references; normalized phase order/links remain equal while canonical bytes and
hash differ. Renaming a session key similarly loses identity on import. A stored
digest cannot recover those missing inputs. Current labels, generic database JSON
serialization, local YAML and a matching caller-supplied digest cannot repair it.

**Legacy result:** `programme_scope_unproven` / `canonical_package_not_retained`
when no proven retained artifact exists, even if all available link strings
agree. Contradictory links still fail explicitly. Keep published versions,
hashes and independent History usable; do not fabricate/backfill artifacts,
republish versions, opportunistically fill an `already_published` retry or infer
historical package content. Any later discovery of an original archived artifact
requires a separately reviewed provenance/admission proposal, not this read API.

**Prospective retention:** one immutable server-owned artifact per newly
published programme version: exact canonical UTF-8 bytes, schema, server-computed
SHA-256, trusted compiler release and server publication provenance. Capture in
the existing trusted publication transaction after full supported schema/graph
validation, before commit; version pin/hash and artifact must agree atomically.
Metadata is server-set, not caller certification. Require full compiler output
for future v1 as well as v2 through trusted publication transport; this does not
change either package's canonical format/hash. No client artifact upload/write
API or general artifact SELECT. RLS enabled with no client policies; trusted
publisher inserts only, normal update/delete forbidden, owner-gated RPC reads.
Do not admit a publication through the supported retained path without the seal.
Unsupported older publication paths remain explicitly unproven.

Package bytes pin session revisions, not every authored block's content. Include
a separate server-derived **authored-scope seal** in the immutable publication
artifact: referenced protocol/lineage/revision identities, exact block identities
and the supported block/mapping content needed by this reader, captured from
validated authoritative relations in that same publication transaction. Give
this manifest its own schema/digest; never include it in or relabel it as the
original package hash. Compare current protocol/block and History source scope
against the seal. The inspected session-revision migration declares immutability
but its lifecycle label alone is not a historical block-content attestation.
This bounded seal avoids depending on that assumption or inventing old blocks.
No general protocol archive or schema redesign; missing seal stays unproven,
contradictory scope fails, and old protocol content/History are not repaired.

## Permission discrepancy: evidence and separate remediation

The [recorded deployment](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
observed hosted authenticated training_sessions SELECT with RLS disabled. The
[local fixture](../../supabase/tests/fixtures/local_test_baseline_prereq.sql)
preserves that disabled-RLS schema but deliberately does not reproduce historical
GRANT ALL; inspected migrations provide no explicit training_sessions SELECT
grant. [Authenticated local proof](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md#training-session-permission-both-paths-proven)
shows denied parent SELECT does not block ordinary independent History reads;
it blocks the proposed invoker actual-session witness. Independent v1 never
joins that table. Hosted permissiveness is not intended tracking authority.
Prove the new definer path against denied parent SELECT, with explicit owner
checks. Auditing/removing hosted grants, enabling RLS and checking other
consumers requires separate security-remediation authority; no repair here.

## Approved local acceptance gates

Originally proposed without execution; current local results are in the handoff.

1. Disposable DB replay: only approved function/artifact/future-capture deltas;
   preserve existing ACL/RLS, History/correction/completion mutation bodies,
   independent v1 and v1/v2 hashes. Only trusted publication capture changes.
   Verify definer owner/path/volatility, qualified helpers, authenticated-only
   EXECUTE, no artifact client writes/reads, and temporary-object shadowing safety.
2. Authenticated athletes A/B and broader coach read role: own exact claim works
   despite denied training_sessions SELECT; cross-athlete record/assignment/session/
   artifact guesses fail without leakage. Missing and foreign records match;
   conflicting audit ownership fails rather than silently filtering evidence.
3. Every joined parent/pin/field: exact and contradictory claims, replacement
   sessions, mismatched completion record, absent historical links, inactive
   assignment, immutable published/archived pins, malformed/duplicate blocks and
   running mappings. No date/name fallback or ignored supplied claim.
4. Artifact: absent/hash-only/client candidates cannot prove legacy scope;
   malformed/unsupported/noncanonical bytes, bad digest and graph/revision
   mismatch fail. Synthetic trusted publication retains bytes atomically;
   failed capture rolls publication back, retries never backfill, artifact/scope
   seal mutation denied. Missing seal or changed live protocol/block scope fails;
   independent compiler round trips preserve existing goldens.
5. Full collections beyond PostgREST's default row limit; explicit row/byte
   bounds; raw malformed fields/units; missing/partial/skipped/unavailable/
   incomparable inputs; incomplete audit payloads and tied timestamps refuse
   historical reconstruction. RPC reads leave rows unchanged.
6. Barrier-controlled two-session correction/read races: complete committed
   actuals/audits and witness/artifact before or after, never mixed. Also race
   first synthetic publication against read: unproven before or sealed coherent
   scope after, never a version/artifact mismatch. Existing correction path
   unchanged. Narrow adapter/bridge/domain compatibility checks, changed-file
   analysis and safety gate only when implementation is authorised.

## Only material founder decisions

1. **Approve the new narrow SECURITY DEFINER combined read authority.** Recommended
   because explicit ownership permits required joins without broad table grants.
   Alternative: retain independent-only reads and keep programme claims blocked.
2. **Approve prospective publication retention and honest legacy scope-unproven.**
   Recommended because original canonical inputs cannot generally be recovered.
   This authorises future-only trusted publisher capture as part of the proposed
   local infrastructure slice; existing versions may remain independent-only.
   Alternative: defer retention and positive attribution until separately proven
   original artifacts exist. Client bytes/hash equality and fabricated backfill
   are not acceptable substitutes.

Founder approved both decisions for this bounded local implementation.
Neither authorises hosted deployment,
real programme publication, permission remediation, production wiring or the
next tracking-product slice. B2 evidence policy/ingestion boundaries remain intact.
