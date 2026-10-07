# First athlete History distance slice — local handoff

> **Completion ownership protection — locally proved, 2026-10-07:**
> [Completion handoff](./PERFORMANCE_TRACKING_COMPLETION_OWNERSHIP_PROTECTION_HANDOFF.md) preserves the audit, table remediation and blocked
> handoff from `ca3837946e526e29a0eb805665ec3e5aa0d29f1f` on
> `codex/completion-ownership-protection`; base/cached origin/main remains
> `b1d028fb33eb537391f307bb4eac22dddd98ebde`. Server ownership/exact-link
> guards and independent parent protection are implemented locally. The former
> completion-isolation failure and expanded actual-role/API proof pass; full DB
> replay/compatibility, structured-running gate, 317 focused Flutter tests,
> zero analysis issues and six safety groups pass. **AWAITING_FOUNDER_REVIEW**.
> Prior blocked results below are historical. Hosted application and device
> validation remain separately gated. No hosted contact/apply, push, release,
> phone build/install or next slice. Stop for founder review.

> **History permission remediation — local blocked candidate, 2026-10-07:**
> [Permission handoff](./PERFORMANCE_TRACKING_HISTORY_PERMISSION_REMEDIATION_HANDOFF.md) preserves audit
> `1b85fe3b1a54b436ee6aa9cb68a09c5cecabf1ff` on
> `codex/history-permission-remediation`, base/cached origin/main
> `b1d028fb33eb537391f307bb4eac22dddd98ebde`. Eight-table ACL/RLS remediation,
> replay, disposable evidence preservation and actual local role/API/C2/C3 checks
> pass. **BLOCKED_AWAITING_FOUNDER_REVIEW**: new canonical completion proof
> confirms a caller with its own valid assignment can supply a foreign session ID;
> the server commits and changes that foreign parent despite client RLS.
> No RPC repair implemented; specific owner/link validation is proposed.
> Existing full DB compatibility, 508 affected Flutter tests, zero changed-Dart
> issues and six safety groups pass; these do not override the failing isolation
> proof. No hosted contact/apply, release activation, phone build/install, push or
> next slice. Stop for founder review; separately authorise the proposed local
> server ownership slice. Earlier audit/visual snapshots below remain historical.

> **Security and real-source audit — 2026-10-07:**
> [Readiness audit](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_READINESS_AUDIT.md)
> is **BLOCKED_FOR_AUTHENTICATED_DEVICE_VALIDATION**. Clean audit base and cached
> origin/main: `b1d028fb33eb537391f307bb4eac22dddd98ebde`; no fetch.
> Cohort Field Manual identity/health and ledger 117 were reconfirmed by bounded
> SELECT-only inspection. New discovery/C2 ownership boundaries are intact in
> inspected definitions; existing anon/authenticated unrestricted
> `training_sessions` SELECT and excessive privileges require separate permission
> remediation. Two profile-athlete-owned complete km observations are structurally
> available; three values are absent, and all five candidates lack comparison
> context. No authenticated role/device run occurred. Remediation is proposed
> only; no permissions, release guard or product code changed. Earlier dated
> integration pauses below are historical; the audit records local ref equality,
> not a freshly fetched remote state or release approval.

**Recorded:** 2026-10-07. **Status:** VISUALLY_APPROVED_AWAITING_FOUNDER_INTEGRATION_APPROVAL.
**Branch:** `codex/athlete-history-distance-slice`.
**Exclusive implementation base:** `46a89b4571b903645c5f4863ff936fb321c234c2`.
**Implementation:** `04016f2b5b93f21cd47e97d65f1ada91b3f726a7`.
Cached origin/main remains `f316a48ba529e98d408bf0acefc9ea2798eb9726`;
no fetch, hosted contact or remote publication. Starting checkout was clean.
All prior commits and both proposal documents are preserved unchanged.

Founder approved the refined view at `86c6224a54223df6005748761b24515c0155fee7`
as a **bounded foundation, not the finished performance dashboard**. The final
review below supersedes earlier visual-review pauses. Approval does not close
security, real-source feasibility or authenticated device-validation gates.

## Approval and delivered boundary

Founder explicitly approved **Distance observations** and its complete-only
**Recorded block distance** kilometre metric exactly as specified in the
[metric decision](../architecture/Performance_Tracking_First_Athlete_Metric_Decision_v1.md),
then authorised this bounded local implementation. That supersedes the dated
proposal-only status for this content and slice, not release or hosted authority.
The [first-slice proposal](../architecture/Performance_Tracking_First_Athlete_History_Slice_Proposal_v1.md)
continues to govern ownership, discovery, independent reads and release gates.

The [approved bundle](../../lib/application/performance_tracking/distance_observations_profile.dart)
uses existing C1 artifacts and their canonical exact references. Proposed IDs are
retained exactly as approved; the namespace is not a publication status. One
curated History profile, one extraction metric, one method; no registry database,
selection revision, assessment, freshness rule or partial-value admission.
Canonical v1 digests are pinned in tests:

| Artifact | SHA-256 |
|---|---|
| Method | `4534245267ad80461826294d32d660a4f8ea04cb5915adc19ea1885b9aa479ba` |
| Metric | `86d3bc86a74d8e17e780cf7bc98ae46c4ba624f77bbfbea6bda3bb04d85c953d` |
| Profile | `8023b1fe99318be5584fe7d49922df2d053f6557231c21a47104bc742f0539a4` |

Owned [History](../../lib/features/performance/screens/training_history_screen.dart)
(including an empty list) and [record detail](../../lib/features/performance/screens/training_history_detail_screen.dart)
expose `Open Distance observations` only for the active athlete matching the
route, rechecked at press. The new view independently resolves ownership; route
IDs, permissive hydration and existing result titles provide no proof.
Existing detail/correction/back navigation and Studio entrypoints are preserved.

The [production composition](../../lib/features/performance_tracking/supabase_distance_history.dart)
requires an active athlete role and the same authenticated transport actor.
Discovery queries only owner-filtered, bounded metadata from
`training_session_records`: 25 rows/page, terminal statuses, stable ID pagination.
It does not hydrate children or read `training_sessions`. Each selected record
is revalidated through actual `SupabaseHistoryTrackingRpcClient` →
`CoherentHistoryRpcReader`, with no programme claim or fallback.

The [controller](../../lib/features/performance_tracking/distance_history_controller.dart)
keeps at most two records and one explicitly chosen block per record. Supported
raw distance/endurance scopes remain candidates regardless of unit/value/state.
Exact block-result/record/source-block identities are retained; duplicate titles
remain separate choices. No default first block or title-based metric matching.
Only private visit-scoped strict-bridge frames feed the adapter; actor/record and
independent mode are checked again. Frame/audit bounds are unchanged. No public
arbitrary-frame certificate or persistent cache was added.

Actual C2 outcomes feed actual C3 with the approved closure and explicit pair
request. Existing rules, evaluator and readers were not changed. Auth events,
account changes, role denial at operations, refresh, route/controller replacement
and disposal clear/invalidate choices and pending responses. Generation checks
prevent late responses restoring prior-account evidence. Refresh requires new
record choices and fresh reads. All auth events conservatively reset choices,
including token refresh; this may interrupt a visit but preserves isolation.

The [athlete screen](../../lib/features/performance_tracking/distance_history_screen.dart)
shows metric/version, native values/units, performed dates and precision limits,
source block, plain states and every comparison refusal. Block choice collapses
once selected; exact IDs, definitions/digests, coverage, eligibility, audit
membership and authority flags remain expandable Evidence. Values/states come
from C3 output, including unsupported-unit failures. Partial values are withheld;
metres remain visibly incompatible, never converted. No arithmetic or improvement.

Correction presence is visible, with no invented previous value/latest revision
or as-of reconstruction. C2 can lose original capture-state certainty in an
incompatible/ineligible view; coverage remains available and the UI does not
infer a missing/partial state beyond evaluator output. Separate record reads
are not a shared snapshot. Missing context leaves valid independent observations
usable but refuses comparison. No exercise/equipment/route equivalence claim.

## Verification at implementation

- **317 focused/regression tests passed**, including 34 new slice tests plus
  affected History navigation/entry/correction, journey integrity, C1/C2/C3,
  C4/Studio internal-review isolation and presentation regression coverage.
- **Changed-file analysis: zero diagnostics**, every changed Dart file including
  both History entry screens and navigation tests; no baseline exception used.
- **Safety gate: six groups passed, zero failed.**
- **Browser inspection:** direct in-app browser review of loopback preview;
  explicit duplicate-title source choice, recorded zero, completed-without-value,
  partial/skipped/metres, admitted pair and missing-context refusal, corrected
  evidence, expanded Evidence and sign-out removal. 320-pixel layout / 200% text
  wrap and scroll; UI tests additionally check expanded evidence at that size.
  No real athlete/session was read during visual verification.
- Local Markdown links and working/staged/range `git diff --check` checked for
  the closeout. Git final SHA, ordered range and clean state are reported after
  the documentation commit; this document does not invent its own commit hash.

Focused command:

```bash
FLUTTER_SUPPRESS_ANALYTICS=true flutter --suppress-analytics test --no-pub \
  test/features/performance_tracking test/performance_tracking \
  test/performance/training_history_navigation_test.dart \
  test/performance/completed_performance_correction_test.dart \
  test/programme/completion_history_preview_states_test.dart \
  test/programme/programme_completion_history_integrity_test.dart test/internal_review
```

Analysis: `dart --suppress-analytics analyze` over the new bundle, new feature,
synthetic preview, both changed History screens and affected test files.
Safety: `FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`.
No full suite: shared changes add guarded History entry buttons; underlying
History capture/correction, Home, Studio, programme and evaluator authorities
are unchanged. Focused regressions and the safety gate cover that concrete risk.
No DB gate/hosted proof, migration, phone build or athlete-data write.

## Founder preview and release gates

Loopback preview: **http://127.0.0.1:4197/**. Dedicated entry:
[synthetic review launcher](../../lib/main_athlete_distance_review_preview.dart).
It mounts the actual athlete screen/controller/strict bridge/adapter/evaluator
with [synthetic wire envelopes](../../lib/internal_review/athlete_distance/synthetic_distance_history.dart).
Approved real definition content is used; **all observations and actors are
clearly labelled synthetic**. No Supabase initialisation or production
composition is reachable from this entry; production and Studio cannot reach
these fixtures. It does not exercise the production navigation shell or hosted
RLS. Preview text-scale/sign-out controls are internal only. Reload restores
synthetic identity after simulated sign-out.

```bash
FLUTTER_SUPPRESS_ANALYTICS=true flutter --suppress-analytics run -d web-server \
  --web-hostname 127.0.0.1 --web-port 4197 --no-pub \
  -t lib/main_athlete_distance_review_preview.dart
```

The [recorded deployment](./PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
reports pre-existing authenticated `training_sessions` SELECT with RLS disabled;
local baseline denies it. Existing owner/parent History RLS and independent RPC
proof are reused as committed evidence, not a fresh security survey. This slice
uses neither that grant nor a table-read shortcut. No indispensable access gap
was found for local independent wiring; no permissions were changed.

Before real athlete use: separately authorised target access/security disposition
of that discrepancy and new metadata/read paths, source availability/retained
context feasibility, authenticated athlete walkthrough/device/release evidence,
and founder visual/integration/release approval. Real comparable pairs are not
promised. Content is bundled locally, not published through a hosted registry.
Programme consumer stays unwired; legacy scope remains unproven.

No conversions/deltas/scores, prescription eligibility, persisted selections,
manual entry, custom editing, programme attribution/test weeks, programme changes,
new result ledger, migrations, deployment or push. Stop for founder visual review;
no integration, release or next-slice work follows from this handoff.

## Presentation refinement — 2026-10-07

Founder-authorised presentation work starts from clean
`4c27c8f939527207ac80d4d52a71288045a5084d` on the existing implementation branch.
The introduction and comparison labels/reasons are shorter; removal is labelled
**Deselect**. Coverage, authority, eligibility, correction-audit and separate
snapshot diagnostics remain accessible in expandable Evidence. Important evidence
states, source units, dates, correction history and comparison limitations stay
visible. The synthetic preview banner is preserved.

The existing owner-filtered metadata read projects only the recorded
`session_snapshot->>sessionTitle` scalar as a display name. Missing names use a
neutral fallback. Existing recorded block labels remain display only. Neither
name participates in source identity or comparison: a rename regression confirms
unchanged exact binding and C3 evaluation digest. Definitions, evaluator rules,
ownership, explicit source selection and ephemeral selections are unchanged.

Current-task verification: all **37 affected feature tests passed** via
`flutter --suppress-analytics test --no-pub test/features/performance_tracking`;
`dart --suppress-analytics analyze` over the seven changed Dart files reported
**No issues found**. Direct browser inspection at the loopback preview confirmed
explicit duplicate-title/multi-block selection, recorded values/dates/provenance,
missing-context comparison refusal and expandable evidence, including scrolling
and wrapping at **320 pixels and 200% text**. Temporary viewport/text settings
were restored. UI tests also cover missing/partial/skipped/corrected evidence,
zero values, incompatible units and expanded evidence at narrow/large text.

The implementation's recorded 317-test and six-group safety verification above
is reused, not claimed rerun. No full suite or new safety run: this refinement
does not change shared navigation or evaluator/authority paths; the sole reader
addition is display metadata within the existing ownership boundary, covered by
the loopback reader test. Local links and `git diff --check` passed. No hosted
read, deployment, push or release-security verification occurred. All release
gates above remain open. Stop for founder visual review.

## Founder visual approval and final correctness review — 2026-10-07

Verified clean checkout on the expected branch and reviewed HEAD
`86c6224a54223df6005748761b24515c0155fee7`; cached origin/main/integration base
is `f316a48ba529e98d408bf0acefc9ea2798eb9726`. No fetch. The five existing
commits are preserved, linear and contain zero merges, in order:

1. `1ec96aca963ed589cedbac4c02999a8135b9f9b7` — first-slice proposal.
2. `46a89b4571b903645c5f4863ff936fb321c234c2` — metric decision.
3. `04016f2b5b93f21cd47e97d65f1ada91b3f726a7` — local implementation.
4. `4c27c8f939527207ac80d4d52a71288045a5084d` — implementation handoff.
5. `86c6224a54223df6005748761b24515c0155fee7` — presentation refinement.

This closeout adds only regression evidence and approval/live-pointer documents;
no scoped implementation defect was confirmed and no product code was changed.
Its sixth commit/final SHA is reported after committing rather than embedded
as a self-referential hash here. Integration remains unapproved.

Final source/test review confirms:

- Ownership requires the active athlete role and matching authenticated reader
  and discovery identities. Metadata proposes candidates only; actual strict C2
  proves record identity and parent coherence. Explicit block-result/source-block
  identity plus `['result_data', 'distance']` binds the field. Titles do not bind
  or compare; duplicate titles stay distinct and no first block is chosen.
- At most two records and one block each. Adding/removing records, changing
  blocks and refreshing discard prior pair results. Comparison requires a fresh
  explicit request. New regression covers an admitted pair, block replacement,
  refused pair, deselection, third-record replacement and refresh.
- Auth events synchronously reset data and advance the request generation;
  identity is checked again after each awaited read. Existing account-change
  tests and new pending-projection/sign-out and old-RPC-after-sign-in tests prove
  late work cannot restore a prior visit's evidence, even if the actor returns.
  Disposal and controller replacement invalidate the old visit.
- Zero remains a recorded value; absent value is unavailable, not zero.
  Missing/not-started, partial, skipped and incomplete-endurance states retain
  their C2/C3 meaning. Partial values are withheld. Metres remain visibly
  incompatible; unsupported units remain explicit failed evidence/candidates.
  Corrections expose audit provenance with no prior-value/latest-field-revision
  or historical reconstruction claim.
- Production composition uses the actual independent RPC, strict bridge,
  adapter and C3 evaluator. Import-reachability tests prove synthetic fixtures
  are unreachable from production; the preview cannot reach Supabase composition.
  No session-table shortcut, write, programme reader or extra result ledger.
- Pair admission is only recorded-quantity comparability; every refusal remains
  visible, with technical evidence expandable. No arithmetic, fitness-improvement
  or prescription claim. Separate record snapshots remain separate.
- History entry ownership checks, list/detail/back/correction behavior and
  existing Studio workflows are covered by affected navigation/integrity and
  internal-review regressions. Existing application release configuration guards
  are untouched. This local feature has no dedicated rollout switch; its entry
  composition must not be mistaken for release approval or deployed availability.

Current final checks: **323 affected regressions passed**, using the focused
command above; **zero analysis diagnostics across all 13 Dart files changed
since the integration base**, including the new regression additions; **six
safety groups passed, zero failed**. Local Markdown links and working/staged/range
`git diff --check` passed. Earlier browser evidence is reused from the approved
immutable presentation checkpoint, not claimed rerun. No full suite: shared
changes remain bounded History entry points; affected History, correction,
C1–C3, Studio/isolation tests and safety cover their concrete risk. No DB gate,
build, hosted proof or athlete-data write was needed or performed.

Only the distance preview's known Flutter session was quit; application exit
and absence of a listener on loopback port 4197 were verified. Other processes
were not stopped. The historical launcher above is retained for evidence, not
a running preview.

Release gates remain open: separately authorised permission-security disposition
of the recorded `training_sessions` discrepancy and metadata/read access;
real-source/unit/retained-context feasibility; authenticated athlete/device
validation; integration and release approval. No real comparable pairs are
promised. No permissions or release guard changed. Stop for founder integration
approval; no fetch/push, rollout, hosted operation or next slice.
