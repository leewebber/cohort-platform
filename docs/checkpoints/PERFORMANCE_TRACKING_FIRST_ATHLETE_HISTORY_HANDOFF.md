# First athlete History distance slice — local handoff

**Recorded:** 2026-10-07. **Status:** LOCAL_IMPLEMENTED_VERIFIED_AWAITING_FOUNDER_VISUAL_REVIEW.
**Branch:** `codex/athlete-history-distance-slice`.
**Exclusive implementation base:** `46a89b4571b903645c5f4863ff936fb321c234c2`.
**Implementation:** `04016f2b5b93f21cd47e97d65f1ada91b3f726a7`.
Cached origin/main remains `f316a48ba529e98d408bf0acefc9ea2798eb9726`;
no fetch, hosted contact or remote publication. Starting checkout was clean.
All prior commits and both proposal documents are preserved unchanged.

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
