# First athlete performance-tracking slice — bounded proposal

**Recorded:** 2026-10-07. **Status:** PROPOSED_AWAITING_FOUNDER_APPROVAL.
Documentation only: no implementation, real definitions, wiring or release authority.

Verified repository `/Users/leewebber/Developer/cohort_platform`, clean worktree
on `codex/c4-tracking-visual-review`; HEAD and **cached** origin/main both
`f316a48ba529e98d408bf0acefc9ea2798eb9726`. No fetch or hosted contact.
Local proposal branch: `codex/athlete-tracking-first-slice-proposal`.
The founder-authorised C4 five-commit fast-forward was completed in the preceding
integration task. C4 is integrated, visually approved synthetic review only;
its dated pending-integration text is historical. C3 is an ancestor of this base.
Neither integration creates an athlete tracking consumer or real approved content.

Binding: [repository instructions](../../AGENTS.md),
[current checkpoint](../checkpoints/CURRENT_CHECKPOINT.md),
[revised tracking architecture](./Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[C1 handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md),
[C2 adapter](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md),
[independent reader](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
[programme reader](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md),
[C3 evaluation](../checkpoints/PERFORMANCE_TRACKING_C3_EVALUATION_HANDOFF.md),
[C4 review](../checkpoints/PERFORMANCE_TRACKING_C4_VISUAL_REVIEW_HANDOFF.md),
[athlete product plan](../planning/Athlete_Product_Completion_Plan_v1.md) and
[roadmap](../planning/Delivery_Roadmap_v1.md). This proposal does not reorder
other milestones or allocate a new numbered phase.

## Audited mechanisms and gaps

| Mechanism | Repository evidence | Required for the first slice |
|---|---|---|
| Definition/profile authoring and approval | [C1 contracts](../../lib/domain/performance_tracking/tracking_contracts.dart), codec and validator provide immutable exact references and dependency validation. Synthetic C4 artifacts are not approved real content. No real tracking registry/approval consumer was found in audited call sites. | Separately author and founder-approve one profile, one extraction metric and its method closure; record purpose, source meaning, units, capture/partial/context requirements and version/digest. Structural validation alone is not content approval. |
| Profile discovery and opening | C3 accepts a [profile request](../../lib/application/performance_tracking/profile_tracking_evaluation_contracts.dart) without a selection revision. No athlete profile catalogue, selection UI or store was found. | Deliver one explicit approved bundle and an `Open profile` card from History. Opening pins the exact reference for this visit; do not call this a saved athlete selection. |
| Exact History discovery/binding | [History list](../../lib/features/performance/screens/training_history_screen.dart) supplies record navigation; its [store](../../lib/features/performance/repositories/supabase_performance_record_store.dart) separately hydrates children and only the last correction timestamp. C2 requires caller-supplied exact [field identities](../../lib/application/performance_tracking/history_tracking_read_contracts.dart). No profile-to-History source resolver was found. | New bounded discovery of candidate fields from a strict C2 frame, and explicit record/field choices. History titles, positions and hydrated values cannot bind metrics or certify evidence. |
| Production reads/evaluation | [Independent transport](../../lib/infrastructure/performance_tracking/supabase_history_tracking_rpc_client.dart), [strict bridge](../../lib/application/performance_tracking/coherent_history_rpc_reader.dart), adapter and C3 exist but are unwired. Combined programme reader is also unwired. | Explicit authenticated independent composition, cancellation/identity guards and request-scoped orchestration. Actual C2 outputs feed unchanged C3; no evaluator-output fixtures in production. |
| Athlete presentation | Existing History/Progress surfaces are operational; [C4](../../lib/internal_review/performance_tracking/tracking_review_screen.dart) is an isolated synthetic screen. Existing Progress metrics are not C1 profile definitions. | A small athlete detail route with C4's reviewed facts/reasons/evidence conventions. Keep C4 entry and fixture factory isolated; do not mount synthetic navigation in athlete UI. |
| Selection persistence | C1 selection revision values/validation exist, not storage, ownership enforcement or an upgrade workflow. | Not necessary for opening a pinned profile. Defer saved profiles, select/deselect/upgrade writes and a general registry. |
| Manual measurements | C1 represents future manual sources/revisions; C2/C3 support History extraction, not manual ingestion/storage/execution. | Not necessary. Defer entry, correction persistence, duplicate-import reconciliation, custom editing and assessment execution. |

The deployed C2 RPCs are recorded in the
[independent deployment](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
and [combined deployment](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_DEPLOYMENT.md).
Those records attest migration/security metadata and local proof, not a fresh
hosted survey or an exercised athlete UI. Recorded artifact retention was empty;
legacy programme scope remains unproven. No mechanism above is assumed complete
merely because a typed contract exists.

## Recommended sequence and first-slice boundary

1. **Approve content and feasibility first.** Separately choose one generic
   recorded-field observation profile, with a single C2-supported extraction
   metric. Prefer block duration in seconds for the smallest mapping; this is a
   candidate field family, not an authored real definition or fitness measure.
   Approve the exact meaning and source policy before implementation. Verify
   representative capture shapes/retained IDs/context using authorised evidence;
   no real data availability or comparable pairs are claimed by this audit.
   Use a History view, no assessment requirement or unsupported freshness rule.
   If this candidate cannot be defined usefully, return for content direction;
   do not substitute pace, invented tests or title-based matching.
2. **Package the approved immutable closure.** A small repository-owned bundle
   plus explicit approved reference allowlist is sufficient initially; no registry
   database/editor is indispensable. It must retain approved versions, validate
   complete C1 closure and fail on missing/conflicting digests. No implicit latest
   lookup or upgrade. Content approval and code integration are separate gates.
3. **Implement a local end-to-end independent read slice, once authorised.**
   Enter from an existing owned History detail, see the profile's purpose and
   exact definition version, and open it. Show candidate observations in that
   record. Optionally choose one second owned History record and two explicit
   fields to ask whether they can be compared. At most two records per view;
   no history-wide scan, automatic baseline/best/latest or pair generation.
4. **Review before release.** Focused local identity/source/evaluator/UI checks,
   safety gate and founder visual review precede integration. A separately
   authorised target security/readiness review and athlete walkthrough precede
   release/hosted use. Proposal approval alone authorises none of those operations.
5. **Allocate later capabilities separately.** Broad profile catalogue/discovery,
   saved selection and upgrade persistence, manual entry, custom composition,
   programme test-week binding, assessments and arithmetic are not prerequisites
   for this bounded view. They each require their own authority and verification.

This first slice is a view of selected existing History records, not a full
longitudinal dashboard or durable profile subscription. With no History, the
profile can still explain its definitions and show an honest empty state;
programme enrolment is not required. Progress/Home authorities stay intact.
No workout start, programme edits, occurrence placement or test insertion.

### New discovery and wiring obligations

Resolve identity from the active authenticated athlete session, with no production
fixture/override ID. [CurrentUserSession](../../lib/features/auth/services/current_user_session.dart)
uses the auth user ID for athlete identity; the new controller must verify that
role/ID against the transport's current authenticated actor before and after every
await. Route athlete/record parameters are not ownership proof. Sign-out, account
switch, record/profile switch or disposal clears pending/visible evidence and
invalidates old responses. Coaches must not gain another athlete's tracking view.

Existing History record IDs are navigation candidates only. An optional second
record picker needs a new small, paginated metadata-only read of owned
`training_session_records`, using active identity and existing RLS; the current
hydrating `listHistory` is not such a port. Label the page as a bounded list,
not all History; no inference that unlisted records are absent. Revalidate any
chosen record through C2. Do not query `training_sessions` to discover candidates.

Read the chosen record through `SupabaseHistoryTrackingRpcClient` →
`CoherentHistoryRpcReader`, with no programme claim. Enumerate supported raw
block candidates from that validated frame, including missing/partial/skipped
scopes rather than filtering only measured values. Construct
`HistoryFieldSelection` with exact record/block-result/source-block IDs and
`result_data.durationSeconds` for the proposed family; reject absent, duplicate
or contradictory identities. Snapshot titles may help display but never resolve
identity, context or metric semantics. No guessed row IDs, ordinal aliases,
planned durations, timers or default units. Unsupported shapes remain explicit.

A new request-scoped orchestrator may reuse that strict bridge-produced immutable
frame for discovery and adapter queries for the same record/actor, avoiding a
remote reread per field. This bounded reuse does not exist today and needs proof:
only the actual bridge may produce the frame; the port must enforce exact record,
actor continuity and independent query mode. It is not a persistent cache or a
public arbitrary-map certificate. Do not set coherence flags on hydrated History
or fabricate a witness. Preserve C2's complete tree/audit bounds; no truncated
frame masquerades as success. UI pagination must not truncate authority evidence.

C2 extracts values and states using approved exact definitions; C3 receives
original query/result envelopes and explicit profile/pair requests. Physical
identity deduplicates aliases. The first current read needs no invented digest
or audit reference; subsequent evidence retains the returned digest/membership.
Refresh explicitly obtains new current frames and clears prior pair state. A
stale pinned reference fails visibly; never overwrite it silently. Two records
are two independently coherent reads, not one cross-record database snapshot.
C3 batch conflicts remain failures, with no last-good winner or independent
fallback from a failed programme query.

Only the **independent** deployed C2 reader is needed in this slice. The combined
reader needs exact programme claims and retained publication proof, which this
independent profile neither discovers nor requests. Do not wire it just because
it is deployed. An independently valid legacy observation remains usable with
`programme_attribution=not_requested`; this is no claim that its programme scope
is proven. Later programme views must show unproven/refused claims separately.

### Athlete reading and interaction

Default: profile/metric names and versions, current measured value/unit, performed
date and precision/timezone limits, source scope, and plain evidence status.
Missing is never zero. Distinguish missing selected evidence, partial capture,
skipped work, completed work lacking a value, unsupported/incompatible evidence,
no candidate sources and a failed/unavailable read. A complete field in a partial
session does not prove a completed session/test. Correction audit presence stays
visible, with “earlier inputs unavailable”; membership does not prove this field
changed or a latest revision.

Two chosen fields show `Can compare`, `Cannot compare` or `Not enough evidence`
from actual C3, with every material refusal reason. Missing comparison context
is a valid refusal; do not generate `comparisonFamily` or relax it to force a
useful-looking pair. No difference, chart trend, improvement, ranking or score.
Technical IDs, full definitions, raw chronology, digests, coverage/eligibility,
source/audit membership and authority diagnostics remain expandable Evidence.
Do not expose unrelated raw columns or another athlete's data in evidence/errors.
Show independent observation wording and the plain boundary that tracking grants
no training targets or prescription eligibility. B2 and blocked Cohort 5 km
benchmark ingestion are unchanged. No save, manual-entry or programme actions;
profile/source/pair choices are transient and clearly reset on leaving the view.

## Recorded permission discrepancy and release dependency

Hosted authenticated already had `training_sessions` SELECT with RLS disabled;
the disposable local baseline denies SELECT. C2 deployments preserved this
pre-existing discrepancy. This is a potential unrestricted session-read exposure,
not intended programme authority or proof of current target security. Nothing in
this proposal contacts the target, changes grants or remediates it.

The independent RPC does not depend on that relation: it anchors owned History
through auth.uid(), existing owner-readable result/audit RLS and exact parents.
Local proof with denied session SELECT remains applicable. Therefore no session
grant, RLS change, definer fallback or restricted-validator access is an
indispensable dependency for local independent wiring. The combined owner-gated
RPC is separately proven; its definer checks do not repair direct table exposure.

Before production release, separately scope an authenticated access review of
record discovery, independent RPC and reachable session-table access for the
intended target. Determine whether the recorded exposure needs remediation or
explicit release disposition; do not describe the target as isolated while that
question is unresolved. If a security change is required, pause release and
propose its exact policy/migration separately. Do not silently broaden this slice
or assume it cannot proceed locally without blanket session SELECT. No new
client path may use the discrepancy as a shortcut to source or programme proof.

## Concrete acceptance checks for later authorised work

- **Approved content:** exactly one reviewed real profile/metric/method closure,
  approval record and pinned digests; synthetic artifacts cannot enter the athlete
  allowlist. Same label/different digest, missing method and unsolicited latest
  upgrades fail. No invented tests, normative meaning or content in this proposal.
- **Authenticated entry/discovery:** two athlete fixtures, coach/foreign/missing
  record IDs, anonymous state, account switches during metadata/RPC/evaluation,
  route/profile changes and disposal. No cross-account last-good evidence;
  absent/foreign records have the same non-leaking response. No hardcoded actor,
  unrestricted search or `training_sessions` access in the new path.
- **Exact evidence:** candidate discovery retains raw IDs/parents, missing and
  skipped scopes; stale digests, malformed/ambiguous IDs, bounds/truncation and
  transport failures remain explicit. Actual C2/C3 drive the view, not permissive
  History hydration or fixture JSON. One record's queries reuse only its proven
  frame. Two-record reads disclose their separate snapshot limits.
- **States/refusals:** complete, missing, partial (permitted and withheld values),
  skipped, completed-without-value, corrected tied/incomplete audits; incompatible
  unit/method/context, unknown context, duplicate/conflicting aliases. Values,
  units, dates and reasons equal evaluator output. No fabricated previous value,
  conversion, automatic pair or silently selected winner.
- **Authority:** valid independent legacy evidence remains visible with no
  programme claim; unproven claims cannot relabel themselves independent. All
  historical-reconstruction and prescription flags remain false. No writes to
  actuals, selections, assignment/programme/targets or a duplicate result ledger.
- **UI/regression:** empty/loading/failure/retry, transient choice/reset,
  expandable evidence, screen-reader/focus, narrow layout and large text; existing
  History correction/navigation, Progress, Home, Studio/Bali and B2 unchanged.
  C4 remains isolated. Founder walkthrough of actual entry plus synthetic edge
  cases does not substitute for authenticated source/security proof.
- **Verification/release:** focused new orchestrator/identity/discovery/C2/C3/UI
  tests and affected History/shell regressions, changed-file analysis without an
  inherited exception, Phase 2 safety gate, local link/diff checks. Broaden tests
  only for a concrete shared-path risk. Separately authorised local DB proof where
  new read semantics warrant it; target access review and release/device evidence
  before real athlete use. No full suite/build/DB/hosted checks were run here.

## Genuine founder decisions and stop

1. Accept the History-first, independent, one-profile/one-metric view with at most
   two explicitly chosen records, transient opening and no saved selection?
2. Approve a separate content task to choose the useful field family and author
   its exact profile/metric/method plus source meaning. Block duration is the
   smallest candidate, not an approved product definition. Do not choose actual
   IDs/content by implication from this proposal.
3. Allocate the bounded wiring/UI work only after content approval, and a separate
   target access/release decision for the permission discrepancy? Local wiring,
   hosted verification/remediation and athlete release must remain distinct gates.

Manual entry, custom editing, test-week integration, programme claims, catalogue
persistence and arithmetic remain deferred; no indispensable dependency on them
was found. This task commits proposal/live-pointer documentation and checks local
links/diff only. Existing C1–C4 verification is attributed to its handoffs, not
rerun. No implementation, hosted contact, migrations, builds, real authoring,
production wiring, push or full suite. Stop for founder approval.
