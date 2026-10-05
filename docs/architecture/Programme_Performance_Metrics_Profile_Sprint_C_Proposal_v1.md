# Performance tracking profiles — revised Sprint C foundation proposal

**Recorded / revised:** 2026-10-05
**Status:** Revised contract architecture FOUNDER_APPROVED; C1 INTEGRATED at
`72c1281f0966f2a6485873f6071b0e000ba1e000`. C2's bounded local pure History
adapter is implemented/verified, awaiting founder review; production read boundary deferred.
**Handoff:** [C1 implementation and verification](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md)
and [C2 local adapter/gaps](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md).
The explicit C1 and bounded C2 authorities superseded their earlier pauses;
neither grants a broader tracking-product licence. C2 has no production reader,
SQL, persistence or UI; see [coherent read proposal](./Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md).
**Parent (amended direction):** [Programme_Performance_Metrics_Profile_v1.md](./Programme_Performance_Metrics_Profile_v1.md)
**Audit:** [PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md](../checkpoints/PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md)

This revision supersedes the programme-only recommendation at `8347480`.
Tracking profiles are optional observational views over athlete-owned
measurements. They can belong to a programme, be independently selected from
curated profiles, or be composed by an athlete from supported definitions.
Longevity, Tactical and Hybrid are product examples only: no real profiles,
metric selections or tests are authored here. No programme enrolment is required
to keep measurement history or select an independent profile.

```text
PROGRAMME_METRICS_PROFILE_SPRINT_C_AUDIT=REVISED_COMPLETE
PERFORMANCE_TRACKING_CONTRACT_ARCHITECTURE=FOUNDER_APPROVED
PROGRAMME_METRICS_PROFILE_C1_AUTHORISED=true
PROGRAMME_METRICS_PROFILE_C1_IMPLEMENTATION=IMPLEMENTED_LOCAL_VERIFIED
PROGRAMME_METRICS_PROFILE_C2_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
COHORT_5K_TEST_INGESTION=BLOCKED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## 1. Product and authority boundaries

Selecting a profile organises observations; entering a measurement records a
fact. Neither operation changes programming, inserts tests, schedules a
retest, generates a training target, advances an assignment or invokes
adaptation. Tracking eligibility and prescription eligibility are distinct
policies. A valid tracking observation can remain wholly ineligible for
prescription. No profile has permission to promote it automatically.

Programme test weeks remain authored programme content. An optional tracking
binding describes how to observe that content, not how to create it.
Standalone assessments are separately authored and explicitly chosen by the
athlete; they do not occupy, replace, complete or reschedule an active
programme occurrence. Any later proposal to place one within a programme
requires the existing explicit scheduling/content authority, outside Sprint C.

Measured results, supported derived metrics and coaching interpretation remain
separate. Derivation records its inputs and method, not coaching advice.
Interpretation requires later approved content. There are no global fitness
scores, weights, normative bands, rankings, physiological estimates or automatic
training targets in this foundation.

## 2. Authorities, identity and versioning

| Entity | Authority and stable identity | Version/change rule |
|---|---|---|
| Supported metric definition | Cohort-owned definition registry; stable metric ID + immutable definition version + content digest | Meaning, canonical unit, source contract, assessment requirements, quality/comparison semantics or method change requires a new version. A different concept gets a new ID; label is not identity |
| Curated tracking profile | Cohort-authored collection; profile ID + immutable version/digest, exact metric-definition dependencies | Selection, ordering, intent or observational filter changes create a new profile version. Longevity/Tactical/Hybrid are not populated in this work; old versions remain resolvable |
| Optional programme binding | Authored programme-version authority; exact profile version/digest plus authored slot/test/window links | Frozen with the programme version; changing it requires a new programme version. An independent curated selection is not a binding |
| Athlete custom profile | Athlete-owned profile ID and immutable composition revisions referencing supported definition versions | Athletes may change name, supported metric membership/order and supported view options. Save creates a revision; they cannot author metric semantics, formulas, tests or units |
| Athlete profile selection | Athlete-owned selection ID/revision referencing an exact curated/custom profile revision; optional programme-binding context | Select/deselect or explicitly upgrade a profile records a new selection state. No silent latest-version upgrade; no measurement copying/deletion or programme rewrite |
| Athlete measurement | Athlete-owned measurement ID + append-only revision identity; exact metric-definition version, value/unit, performed time and source/context | Correction adds a revision and preserves earlier values. Removing a profile never removes history. Imported History facts remain owned by their original result/correction authority, not a second writable ledger |
| Authored assessment/test | Separately approved assessment identity + immutable procedure version/digest, required capture/context and definition references | A performed attempt pins the version. Programme use also pins the exact authored slot/protocol revision/scope; standalone use creates its own attempt identity |

All published artifact content is immutable, including labels and display
metadata; editing it creates a new artifact version. A registry may mark a
version deprecated without rewriting its historical meaning or references.

The registry is a shared vocabulary, not a global scoring engine. A profile
references supported definitions; it does not redefine their meaning. An
explicit authored programme filter may narrow eligibility but cannot relax
required measurement validity. Custom profiles cannot invent test equivalence
or source trust. Registry/profile updates preserve previously selected versions;
unsupported historical method versions are unavailable, never replaced silently.

Future storage should preserve these ownership boundaries: definition/profile
artifacts are canonical content; selections and custom compositions are private
athlete state; measurements are private athlete evidence. Publication, RLS and
historical private reads need later explicit design and local proof. No tables,
columns or grants are added by this documentation task or revised C1.

## 3. Reusable athlete measurement history

Maintain one logical athlete-owned measurement history, independent of profile
or programme lifecycle. A profile queries eligible observations by definition,
source and context; it does not own copies. Reusing a measurement across two
profiles or programmes is reference reuse, not two attempts. Identity-based
source deduplication prevents a manual import of an existing result from
silently becoming another independent performance; unresolved duplicates stay
visible with ambiguity rather than contributing twice.

For new manually entered existing results, future capture records the original
performed date/time precision, IANA timezone where required, canonical unit,
metric-definition version, source declaration, context and any declared test
procedure. Do not require a fictional programme or fabricate a completed
assessment. Missing provenance can allow a labelled observation while making
it ineligible for comparison or a test-specific metric. Unknown units and
invalid values cannot be silently converted into valid measurements.

Existing programme/session results are read through source adapters referencing
record/block/set/step IDs, original result snapshots, correction audit and an
input digest. Do not add another writable copy of actuals. Programme-specific
claims require verified athlete → assignment → version/hash → occurrence/slot
→ training session/outcome → History/result scope links. Older records with
insufficient programme links can still be eligible for an independent metric
when their metric/source contract is satisfied; they cannot be labelled a
programme test by inference.

Reuse across programmes does not imply attribution to each programme. A
programme baseline may explicitly accept an earlier independent observation;
a programme test-completion claim must use the bound authored scope. Programme
windows default to their declared assignment context; broader observations
require an explicit authored rule and are labelled as external to that attempt.
Cross-profile display is allowed. Cross-definition-version or cross-test
comparison requires an explicit supported equivalence rule; matching labels,
movement identity or lineage alone do not establish it. No such equivalence
rules are invented in C1.

## 4. Entry and assessment routes

| Route | Evidence produced | Boundary |
|---|---|---|
| Enter a result already performed | Athlete-declared observation with source, event chronology and context | Entry is not execution, proof of an authored test, trusted device evidence or programme completion |
| Reuse a recorded session result | Read projection of exact result/correction identity | Never planned loads, timer expiry, frozen target or terminal-slot count used as measured performance |
| Perform an authored programme test | Attempt linked to the exact authored slot, published protocol revision and required capture scope | Tests/test weeks must already be authored; a profile cannot insert them |
| Explicitly perform a standalone authored assessment | Separate attempt, pinned procedure and capture scope | No implicit programme occurrence, completion, schedule change or target calculation |

A tracking definition declares what sources and capture fields it accepts,
canonical/display units, completeness/context checks, freshness (including
explicit none), and any required assessment identity. Programme bindings can
add exact baseline/checkpoint/final windows; independent profiles need not have
programme windows or scheduled tests. Selection/tie-break rules must be explicit
(for example latest eligible observation, then stable source ID), based on
performed time rather than correction/entry time. Missing baseline does not
hide an eligible current result. No implicit best-attempt choice or averaging.

For a full-test result, incomplete required work cannot qualify. A partial
session may contain an eligible complete measurement scope only when the
supported contract and any programme filter permit it. Incomparable conditions
keep individual facts visible without a delta. No test name, proximity,
relationship adjacency or displayed ordinal can create evidence identity.

## 5. Honest states, correction and prescription separation

| Condition | Required observational state |
|---|---|
| No profile selected or programme has no binding | `not_selected` / `profile_not_configured`; valid optionality, not missing athlete data |
| Successful query, no eligible observation | `missing`; no zero, placeholder score or inferred baseline |
| Required scope/fields incomplete | `partial`; explicit coverage and no whole-test value unless allowed |
| Assessment work skipped | `skipped`; no measured zero |
| Performed work but requested value absent | `unavailable`; retain the completion fact |
| Stale, invalid context or unsupported source | `ineligible` with reason; preserve honest original observation where safe |
| Valid observations but incompatible procedure/definition/context | `incomparable`; individual facts, no comparison |
| Corrected result | Current value/quality with correction provenance; prior revision retained where available |
| Query, identity, hash or dependency failure | Typed failure, not successful emptiness; last-good state only for the same athlete/selection/scope |

New manual measurements should have append-only revisions. Existing result
corrections currently mutate result rows while appending before/after audit
entries. Future adapters need coherent reads, selected-value digests and exact
source correction references. Historical replay must prove complete input
reconstruction; otherwise report `historical_inputs_unavailable`. A frozen
method alone cannot reproduce a value after inputs change. No persistent metric
cache or inferred immutable result revision is proposed for C1.

Tracking validity is **not** prescription permission. Any future prescription
consumer must independently validate an explicitly approved, versioned policy,
eligible evidence, exact scope and its own freshness/source rules. A profile
selection, manual observation, assessment label or tracking digest is not a
credential for B2 target calculation. Do not extend B2 accepted sources,
commands, percentage bands, correction semantics or snapshot eligibility.

**Cohort 5 km ingestion remains blocked.** B3 completion and profile/assessment
links do not prove the exact 5,000 m elapsed-inclusive-pauses test required by
B2. Existing manual benchmark evidence/revisions and occurrence target freeze
retain their current authority. A later observational adapter may reference a
permitted existing benchmark without writing, promoting or reclassifying it.
Corrections to tracking history cannot alter an already frozen target. Device
trust/import, distance/manual-lap execution and commercial pace policy remain
separately gated.

## 6. Schema and hash reassessment

**Schema v3 is not required for revised C1 or independent tracking.** Metric
definitions and curated profiles need their own versioned canonical artifacts;
custom profile revisions, selections and measurement revisions have independent
identities. None of them requires changing a Plan Package.

Recommend reserving a future **schema v3 optional `tracking_profile_binding`**
for programme-authored tracking. Do not introduce it in C1 or extend existing
v2 parsing/bytes. A new schema marks the future package capability clearly;
there is no mandatory-profile rule and no `no_performance_claim` escape field.
An absent binding is valid for both old and new versions. Malformed declared
bindings fail closed; publication does not reject a programme simply for having
no tracking profile. Programme promise/content review remains a human gate.

If/when that binding is implemented, its programme content hash includes:

- Binding schema version, exact profile ID/version/digest and recursively pinned
  metric-definition versions/digests (including frozen method dependencies).
- Programme-authored observation scope: assessment IDs/procedure versions,
  slot keys and session protocol revisions, exact block/step/repetition links
  where needed, evidence-source restrictions, comparison windows and selection
  policy. Existing package assessment/session declarations remain hashed too.
- Any programme-authored metric subset, ordering, display labels/intent or
  allowed observational parameters that alter the bound view.

Hash only present programme-owned fields; published dependency artifacts must
remain immutable/resolvable and validators verify each digest. Registry changes
cannot change a pinned package's effective meaning. The full external catalogue
is not copied into every package. An optional version-row JSONB projection
would be verified from the binding, not become independently editable authority.
No generated row UUID or athlete ID participates in canonical package bytes.

The programme hash **excludes** athlete profile selections/custom compositions,
measurements/revisions, derived read results, evaluation timestamps, UI state,
and independently selected curated profiles. A curated profile's own digest
covers its selections, labels/order, observational rules and immutable definition
dependency digests; definition digests cover measurement/method meaning, units,
source/context requirements and comparability rules. Athlete revisions never
change these authored digests or the programme hash.

Preserve every published v1/v2 package, golden hash, pin, assignment, execution
path and historical record. Do not backfill profiles/bindings into immutable
versions or infer them from programme names. A later desire to bind tracking to
an existing programme requires an explicitly authored new version, not a side
artifact silently attaching new content to an old pin. That operational work
remains unauthorised.

## 7. Read-only review and later athlete presentation

Studio later reviews optional programme binding, resolved immutable profile and
metric dependencies, exact authored test/window scopes and unavailable sources.
It uses B4 artifact/hash checks and never authors profiles from derived review
JSON. Missing optional binding is distinct from invalid declared binding.
Independent curated/custom views later work without an active programme;
programme-specific views retain exact pin/assignment context. Explicit profile
upgrades do not relabel older measurements or delete history. Auth/selection
changes clear stale view state. UI, refresh wiring and assessment execution are
not implemented or authorised here.

The earlier athlete-defined Performance Portfolio remains deferred in the
[product plan](../planning/Athlete_Product_Completion_Plan_v1.md). This founder
clarification extends Sprint C's proposed data contracts to support composition
and reusable history; it does not authorise that full feature, custom metric
semantics, targets, radar, scoring or neglected-capability recommendations.
The historical [assessment vision](../product/Plan_Assessments_Vision.md) is
context only; its example test lists and legacy PlanDefinition path are not
content or execution authority.

## 8. Revised C1 boundary (integrated)

The pure, UI-free [tracking domain library](../../lib/domain/performance_tracking/performance_tracking.dart)
implements these contracts independently of programme runtime and the package
compiler. Its delivered checks and limits are recorded in the C1 handoff:

1. Supported metric reference/definition contracts with stable ID, immutable
   version/digest, canonical units, typed source/context requirements and
   supported method references. Synthetic supplied registry only.
2. One profile-composition contract with curated and athlete-owned variants;
   exact metric references, order, supported view options, profile revision
   and selection identity. No real registry/profile content or selection writes.
3. Measurement/source-reference and revision contracts, ownership, performed
   chronology, declared provenance and quality states; distinguish standalone
   attempts, manual existing results and existing History references.
4. Optional programme-binding and authored assessment reference contracts as
   standalone values only, to exercise separation and future hash boundaries;
   no Plan Package field, parser or publication change.
5. Pure validation and deterministic artifact encoding/digests for these
   contracts. Reject missing/ambiguous dependencies, unsupported units/methods,
   formula fields and invalid composition/scope; no database/network resolver.

C1 contains reference/type contracts for supported extraction or difference
methods, not an executable derivation engine, calculation of training targets,
historical replay implementation or production result importer. Its synthetic
fixtures demonstrate one definition reused by curated/custom compositions,
a measurement reused without duplication, a correction reference and optional
programme scoping; no real test procedure or profile membership is selected.

C1 acceptance requirements (verified as recorded in the handoff): deterministic dependency-aware digests; immutable-version
reference validation; ownership/context isolation; missing/partial/skipped/
incomparable states; manual entry distinct from test proof; source identity
reuse; definition incompatibility rejection; and no tracking-to-prescription
promotion. Existing v1/v2 golden bytes/hashes remain exactly unchanged. Use
focused unit checks/changed-file analysis and the required architecture safety
gate for implementation. No warning-baseline exception carries forward.
The C1 handoff reports the actual current-task passes; broader slice gates
remain future requirements.

**Excluded:** persistence/migrations/RLS, compiler schema v3, live evidence
queries or ingestion, runtime evaluation, correction writes, UI/Studio,
assessment execution or scheduling, arbitrary custom formulas, scoring,
real curated profiles/metric selections/test content, programme or assignment
changes, builds, hosted work or push. The old C1–C4 implementation sequence is
superseded; later persistence, source adapters, programme packaging and UI
slices must be reallocated after revised C1 review rather than inherited.

## 9. Founder-approved contract decisions

The founder has already settled optional tracking, independent curated/custom
composition, athlete-owned reusable history and observational defaults. Do not
ask to reconfirm those product choices. The following contract decisions were
also approved in the explicit C1 authorisation. Alternatives are retained for
rationale, not pending approval questions:

1. **Definition and profile version authority:** recommend immutable supported
   definition/profile versions with explicit athlete selection upgrades and
   custom composition revisions. Alternative: follow latest definitions/profile
   content automatically, making historical meaning drift. Approved for C1.
2. **Package boundary:** recommend no package change in C1; reserve future v3
   for optional authored programme bindings with only the content above hashed.
   Alternative: a later version-owned companion binding needs its own immutable
   hash and checks throughout review/read paths. Full later storage mechanics
   can wait; C1's package exclusion is approved.
3. **Measurement source authority:** recommend references to existing History
   actuals/corrections, and append-only revisions for future new manual results,
   both forming one logical athlete history. Alternative: copy all actuals into
   a second writable measurement ledger, with duplicate/correction drift risk.
   The source/reference contract is approved for C1; database mechanics can wait.

C1 was separately authorised, reviewed and integrated. The bounded C2 request
authorised an unwired read-only History adapter; its independent pure work is
locally verified. The [C2 handoff](../checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md)
records the stopped production/database portion and concrete proposal. Full later
storage/package choices remain deferred. C1 does not author real profiles/tests
or release the strategic pause before content creation. Tracking confers no
hosted publication, assignment, prescription-policy or B2 ingestion authority.
