# Performance Tracking C4 — bounded visual-review proposal

**Recorded:** 2026-10-06. **Current status (2026-10-07):**
INTEGRATED_VISUALLY_APPROVED_SYNTHETIC_ONLY.
The founder separately authorised implementation and approved the isolated
synthetic surface, including refined presentation at `0638046`. The
[C4 handoff](../checkpoints/PERFORMANCE_TRACKING_C4_VISUAL_REVIEW_HANDOFF.md)
records delivery and final review. No deployed athlete tracking, production
wiring or next-slice authority. The proposal-time recommendations and pauses
below are preserved as history; implementation/visual approval supersede only
those bounded pauses. Founder-authorised integration completed through `f316a48`;
no further implementation or production use follows from it.

Verified checkout: `/Users/leewebber/Developer/cohort_platform`, branch
`codex/c3-tracking-evaluation`, clean worktree before edits; HEAD and **cached**
origin/main both `ee2ebaeb14a809628a031b428ff9fee87b0c5e06`.
No fetch or hosted contact. The tip contains the reviewed C3 implementation and
alias-evidence fix. Earlier integration pauses in checkpoint/handoff text remain
dated records; local ref equality does not establish remote freshness or a new
product licence. Existing handoff test results are recorded evidence, not rerun.

Binding: [repository guidance](../../AGENTS.md),
[current checkpoint](../checkpoints/CURRENT_CHECKPOINT.md),
[revised tracking architecture](./Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[C1 handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md),
[C2 adapter handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md),
[independent reader handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
[programme-attribution handoff](../checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md),
[C3 handoff](../checkpoints/PERFORMANCE_TRACKING_C3_EVALUATION_HANDOFF.md),
[Studio architecture](./Programme_Studio_v1.md) and
[athlete product plan](../planning/Athlete_Product_Completion_Plan_v1.md).

## Placement and implementation boundary

Recommend one internal **Performance tracking review — synthetic fixtures**
screen, launched only by a dedicated proposed
`lib/main_performance_tracking_review_preview.dart` entry point. Reuse Cohort
theme, spacing, typography and Studio's navigation/workspace and expandable
integrity presentation conventions from the
[internal Studio shell](../../lib/features/programme_studio/presentation/programme_studio_app.dart).
Its controller and private widgets are programme-specific: do not fabricate a
programme to mount tracking, extend its four existing destinations or refactor
the shared shell for this slice. Keep Studio/B4/Bali defaults, inventory,
keyboard navigation and review workflows unchanged. No production route,
main-entry import, Home/History link or athlete preview integration.

Later approved implementation would contain this entry point, one presentation
screen and a small in-memory scenario factory under a dedicated internal-review
folder, plus focused tests/docs. No new general tracking framework or dependency.
Use synthetic C1 exact method/metric/profile artifacts and the unchanged C2
adapter with an in-memory fake reader to produce query/result envelopes. Reuse
the patterns in the [C3 synthetic tests](../../test/performance_tracking/profile_tracking_evaluator_test.dart)
and [C2 fixtures](../../test/performance_tracking/history_tracking_fixtures.dart);
do not import test libraries into runtime or hand-author evaluator output JSON.

Every scenario invokes the actual
[ProfileTrackingEvaluator](../../lib/application/performance_tracking/profile_tracking_evaluator.dart)
with a complete exact dependency closure, `TrackingProfileRequest`,
`TrackingEvaluationInput` and fixture-authored explicit
`TrackingComparisonRequest` operands using `TrackingComparabilityPolicy.reference`.
The screen formats returned facts/reasons; it does not reimplement eligibility,
deduplication, comparison, source extraction or arithmetic. Synthetic witness
fixtures exercise existing C2/C3 composition only, not live authentication,
publication or database proof. No Supabase client, RPC transport, environment
configuration, filesystem data loader or real catalogue is needed.

## Default presentation and interaction

Open the complete scenario with a persistent **Synthetic data — internal visual
review only** banner. A small scenario list changes only ephemeral preview state;
it is not an athlete profile selection. Reset expanded evidence on scenario
change and display failures without retaining observations from another scenario.
Provide no save, select profile, edit, enter result, upgrade, publish or accept
action. No refresh, automatic latest/best search or user-built comparison picker.

The workspace reads in this order:

1. **Profile and definitions:** synthetic profile name/version, composition kind
   and ordered metric members. For each show definition label/version, measured
   field in plain language, canonical unit, extraction method/version and relevant
   capture/context requirements. These are pinned supplied definitions, not real
   curated content. Full references distinguish any matching display labels.
2. **Recorded observations:** measured value with explicit unit, original
   performed date/time and precision, known source timezone or “timezone unknown”,
   source type and readable scope such as “recorded session block duration”.
   Correction time remains separately labelled; never substitute it for performed
   time or invent civil chronology. Preserve canonical decimal values and units.
   Missing values use state text, never zero or an unexplained dash. Show selected
   scope coverage and partial/skipped/unavailable reasons beside the row. A complete
   field in a partial session does not imply a completed session or test.
3. **Requested observation pairs:** two explicitly named observations side by
   side, their units/dates and “Comparable”, “Not comparable” or “Comparison
   unavailable”. Explain every material returned reason in plain language, including
   known mismatches alongside missing prerequisites. A comparable label means
   matching exact definition/method, unit, field scope and retained required context
   for two distinct observations; it carries no performance judgement.
4. **Authority:** show independent tracking eligibility and programme attribution
   separately. Use “Programme attribution not requested”, “Proven in this synthetic
   fixture” or “Programme scope unproven”, with claim failures visible. Always show
   “Tracking does not create prescription eligibility”: neither a valid observation,
   comparable pair nor proven programme scope authorises a training target or proves
   an authored assessment was completed. B2 eligibility and blocked Cohort 5 km
   ingestion remain separate.

Expandable **Definition evidence**, **Source and correction evidence** and
**Authority evidence** contain full profile/metric/method/policy references,
versions/digests, field and physical source IDs, input/audit/evaluation digests,
requested correction reference, complete unordered audit membership, declared
programme claim and returned proof/failure diagnostics. Keep these out of the
default reading path; explanations of missing evidence and comparability remain
visible. Digests identify content, not permission. Map known reason codes without
discarding them; unknown codes remain explicit in evidence, never become success.

## Six synthetic scenarios

Use neutral fixture labels, fixed synthetic dates and supported extraction fields.
No Longevity/Tactical/Hybrid membership, real procedure or coaching content is
selected. Fixture values are measured-input examples, not derived results.

| Scenario | Required visual evidence |
|---|---|
| Complete profile | All synthetic members have complete selected-field evidence. Two distinct duration observations, e.g. `12 seconds` and `14 seconds`, on explicitly supplied dates share exact definition/method and retained comparison context. Show the actual C3 comparable outcome; no difference or better/worse label. |
| Missing and partial | Include successful missing, partial, skipped and completed-but-value-unavailable outcomes; preserve coverage, permitted partial values and withheld values under their exact definitions. Missing operand prevents comparison while the other fact remains visible. Include an eligible complete field within a partial session to distinguish scope from session completion. |
| Corrected evidence | Current observed value plus requested audit reference and full unordered audit membership, including tied audit times and incomplete legacy payloads. Default wording: “Correction audit present; earlier inputs unavailable.” Membership alone does not establish that this field changed, its latest revision or a previous value. No before/after reconstruction or historical trend. |
| Incompatible units/methods/context | Distinct subcases preserve source units (e.g. metres/kilometres), exact differing metric/method references and conflicting or absent retained context. Render C2/C3 outcomes and all reasons. No conversion or equivalence by label. Unsupported methods, including difference, remain failures; do not pretend they produced observations. |
| Duplicate source aliases | Two references to one physical field render one observation with all alias/view links in evidence. A requested self-pair is not comparable. A contradictory alias variant visibly fails the evaluation for conflicting values, known capture state/coverage/unit or audit membership; never choose the newest or display a last-good value as current. |
| Independent with unproven programme scope | Supply a valid independent outcome and a separately requested unproven programme claim for the same source. Show the independent fact/eligibility and failed unproven claim together, with no fallback or programme-test badge. Add a proven synthetic witness variant and contradictory-proof variant to contrast attribution only; prescription eligibility remains false in all variants. |

No batch of synthetic frames claims one cross-record database snapshot. Aliases,
correction membership and programme binding declarations create neither another
attempt nor source trust. Programme-only failure supplies no independent fact.

## Acceptance checks for a separately approved implementation

- Fixture-to-widget checks invoke unchanged C1 validation, C2 adapter and actual
  C3 evaluator for all six scenarios/variants. Displayed values, units, evidence
  states, coverage, pair reasons and attribution match returned results; all
  historical-reconstruction and prescription flags remain false.
- Exact dependency evidence resolves the supplied artifacts; no label/latest
  substitution. Distinct source fields remain distinct; aliases share one physical
  observation. Reordered aliases/audits produce no winner or chronology claim.
- Widget checks cover scenario switching, cleared stale content, expandable
  evidence, keyboard focus/semantics, readable narrow layout and large text.
  Missing/failure states and synthetic labels must remain understandable without
  colour alone. No invented differences, scores, ranks or improvement language.
- Production import/reachability check proves the new entry/screen/fixtures cannot
  be reached from production entries. Focused Studio regressions confirm existing
  destinations/defaults/navigation remain intact; no real assets loaded by C4.
- Run focused C4/C3/affected Studio tests, changed-file analysis, the required
  Phase 2 consolidation safety gate, local document-link checks and
  `git diff --check`. No inherited analysis exception. No full suite, DB gate,
  migration or hosted verification is proposed for this isolated surface.
- Founder walkthrough checks the complete default, each scenario/variant and
  evidence expansion. Passing automated checks is not founder visual approval.

## Founder decisions and stop

The only requested allocation is approval of this synthetic-only internal preview,
its separate entry point with Studio visual reuse, and the default facts/pairs/
authority presentation above. Existing optional tracking, immutable definitions,
independent history and prescription separation are settled. No real profile,
test procedure, comparison arithmetic or programme binding needs choosing here.
Later visual approval would accept this review surface only, not production use.

This task delivers and locally commits proposal documentation; stop before
implementation. No hosted contact, migrations, production wiring, athlete UI,
persistence, manual entry, real profiles, programme/assignment/package changes,
content authoring, push or full test suite. Existing Studio workflows and protected
private programme state remain untouched. Further implementation requires separate
founder authority.
