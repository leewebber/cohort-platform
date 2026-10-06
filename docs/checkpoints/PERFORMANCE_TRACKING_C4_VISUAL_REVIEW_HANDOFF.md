# Performance Tracking C4 — internal visual-review handoff

**Recorded:** 2026-10-06. **Status:** LOCAL_IMPLEMENTED_VERIFIED_AWAITING_FOUNDER_VISUAL_REVIEW.
The founder authorised the bounded [C4 proposal](../architecture/Performance_Tracking_C4_Visual_Review_Proposal_v1.md)
for this synthetic-only preview. This does not authorise production tracking or
another slice. Automated verification is not founder visual approval.

## Exact local range

Checkout `/Users/leewebber/Developer/cohort_platform`; clean starting branch
`codex/c3-tracking-evaluation` at proposal commit
`f1d244bda42de754b4cb5bea6130a4d8af38f078`, whose immediate parent is expected
base/cached origin/main `ee2ebaeb14a809628a031b428ff9fee87b0c5e06`.
Created local implementation branch `codex/c4-tracking-visual-review`.
No fetch or hosted contact; no claim of remote freshness.

Implementation: `72024bbfa2882e1afbe4dc6c2b139f686383929f`.
The following handoff/checkpoint commit completes the range
`ee2ebaeb14a809628a031b428ff9fee87b0c5e06..HEAD`: **three linear commits**,
preserved proposal, implementation and handoff. Implementation continuation is
`f1d244bda42de754b4cb5bea6130a4d8af38f078..HEAD`: **two commits**.
The final Git report supplies the handoff tip's full SHA. No merges, amend,
rebase, push or main-ref change.

## Delivered surface

[Dedicated entry](../../lib/main_performance_tracking_review_preview.dart),
[review screen](../../lib/internal_review/performance_tracking/tracking_review_screen.dart)
and [synthetic scenario factory](../../lib/internal_review/performance_tracking/tracking_review_scenarios.dart).
Shared Cohort theme/spacing/type and Studio navigation/evidence conventions are
reused. Studio's controller, four destinations, defaults, source assets and
B4/Bali workflows are unchanged. C4 has no production import or route.

All six scenarios call unchanged C1 validation, actual C2 adapter over in-memory
fake-reader frames, then the actual C3 evaluator. No evaluator-output fixture,
copied result store, parallel comparison engine or transport is introduced.
Six scenarios comprise **12 review cases**, including unsupported method,
contradictory alias and programme proof variants. The complete default shows
exact synthetic profile/definition versions, recorded values/units/dates, source
scope, evidence/coverage and explicit pair outcomes/reasons. Independent tracking
eligibility and programme attribution are distinct. All raw references/digests,
audits, claims/witness diagnostics are behind expandable evidence. Scenario
navigation is ephemeral and resets evidence expansion and prior content.

Founder walkthrough:

| Scenario | Review expectation |
|---|---|
| Complete profile | `12 seconds` and `14 seconds`, explicit performed dates and matching exact definition/method/context; comparable, without a computed change or judgement |
| Missing and partial | Missing, skipped, partial and completed-without-value remain distinct; partial values are permitted/withheld by exact definitions; complete field inside partial session stays separate from session completion |
| Corrected evidence | Current set duration plus two unordered tied-time audits with incomplete legacy payloads; no reconstructed earlier value, latest revision or claim this field changed |
| Incompatible evidence | Source metres remain metres; method/definition and context mismatches remain explicit; absent context prevents comparison; unsupported difference yields refusal |
| Duplicate source aliases | One physical observation with both references; self-pair refused; conflicting alias evaluation admits no observations and chooses no winner |
| Independent and programme | Separately requested independent fact stays eligible beside an unproven claim; fake proven scope is labelled synthetic; contradictory proof admits no fallback fact |

No numeric differences, improvement claims, scores/ranks, conversion, automatic
latest/best choice, save/selection writes or prescription eligibility. Date-only
and unknown civil timezone remain explicit. Current audits cannot reconstruct
historical inputs. Multiple frames do not attest one cross-record database
snapshot. A typed fake witness does not prove live authentication/publication,
test completion or registry approval. Legacy real scope remains unproven.

## Current-task verification

| Gate | Evidence at implementation 72024bb |
|---|---|
| Focused C4/C3/Studio run | **96 passed**: 25 C4 scenario/widget/isolation tests, 48 C3 evaluator tests and 23 existing Studio surface/isolation/structured-running regressions |
| C4 layouts/interactions | All six scenarios at **390 × 844 / 200% text**, expandable evidence without overflow, desktop facts/hidden diagnostics, scenario reset, focus/menu/semantics and plain attribution/failure states |
| Changed-file analysis | **Zero diagnostics** across the new entry, two internal-review files and three tests |
| Phase 2 safety gate | **6 groups passed, 0 failed** |
| Isolation | Import/export/part reachability from production main and Studio preview cannot reach C4; C4 reaches actual C2/C3 with no live client, IO, asset loader, persistent store or test-library import |
| Diff/links | Staged implementation `git diff --check`; final documentation links and range diff checked at closeout |

Commands:

```bash
flutter --suppress-analytics test --no-pub test/internal_review test/performance_tracking/profile_tracking_evaluator_test.dart test/programme_studio/programme_studio_surface_test.dart test/programme_studio/programme_studio_isolation_test.dart test/programme_studio/programme_studio_structured_running_test.dart
dart --suppress-analytics analyze lib/main_performance_tracking_review_preview.dart lib/internal_review/performance_tracking test/internal_review
FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh
git diff --check
```

Routine pre-commit corrections: the unsupported-method fixture initially used
an invalid C1 source declaration and was corrected to the existing difference
contract; evidence tiles received a proper Material ancestor; the large-text
banner became compact so content remains scrollable. Final affected checks above
pass. No shared runtime/authority changes warrant a full suite. C1/C2 DB,
compiler/publication and hosted evidence remain attributed to their committed
handoffs; not rerun or refreshed here. No analysis exception was used.

## Loopback review and stop

After this handoff commit, launch the dedicated synthetic preview on the loopback
review target [http://127.0.0.1:4196](http://127.0.0.1:4196):

```bash
flutter --suppress-analytics run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 4196 -t lib/main_performance_tracking_review_preview.dart
```

Launch/HTTP readiness is reported separately in the final task response; the
test gates above do not attest that a server has started. No Supabase configuration
or athlete sign-in is required. Local browser review is synthetic, not athlete UI.

Stop for founder visual review. No hosted contact, migrations, production wiring,
persistence, manual entry, real profiles/content, programme/assignment/package/B2
changes, fetch/push or full suite. `.env` and `supabase/.temp` remain untouched.
Visual acceptance, integration and any later product slice require separate
authority.

## 2026-10-06 bounded presentation review

Direct browser review of the loopback preview covered all six scenarios at
1118 × 768 and 390 × 844, including 200% Flutter text. A temporary text-scale
override was used only for browser QA and removed before commit. The normal
preview was restored. Expanded definition/observation, correction and authority
evidence were inspected; narrow large-text evidence wraps and remains scrollable.

The default view now names the metric alongside every observation, renders dates
in plain form while preserving precision/timezone limits, and uses `Can compare`,
`Cannot compare` or `Not enough evidence` with short refusal reasons. Missing,
partial, skipped, corrected and refused requests remain explicit. Coverage,
tracking eligibility, raw dates/IDs and authority diagnostics are expandable
Evidence. Independent observations and programme claims remain distinct; the
visible review limits retain prescription and historical/coherence boundaries.
Synthetic labelling stays visible. No evaluator, fixtures or authority rules changed.

Current-turn verification: **15 affected UI/isolation tests passed** (13 UI,
2 isolation); **zero changed-file diagnostics** for the screen and UI test.
All six UI scenarios still pass at 390 × 844 / 200% text, including evidence,
menu focus and reset. Diff and local document links checked. Prior evaluator,
Studio and safety-gate results above remain attributed to implementation
72024bb; presentation-only edits do not change shared paths and did not rerun
those gates or the full suite. Founder visual acceptance remains pending.
