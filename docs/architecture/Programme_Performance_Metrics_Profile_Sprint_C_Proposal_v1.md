# Programme performance-metrics profiles — Sprint C foundation proposal

**Recorded:** 2026-10-05
**Status:** PROPOSED_NOT_AUTHORISED; documentation only, awaiting founder approval.
**Parent:** [Programme_Performance_Metrics_Profile_v1.md](./Programme_Performance_Metrics_Profile_v1.md)
**Audit:** [PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md](../checkpoints/PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md)

The recommendation is one immutable programme-owned definition, included in
canonical programme content, and one read-only evidence evaluation boundary.
It adds no global fitness score, prescription, adaptation or benchmark-ingestion
authority. Every future published version should explicitly declare its profile;
existing published versions without one remain valid and unchanged.

```text
PROGRAMME_METRICS_PROFILE_SPRINT_C_AUDIT=COMPLETE
PROGRAMME_METRICS_PROFILE_SPRINT_C_PROPOSAL=AWAITING_FOUNDER_APPROVAL
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
COHORT_5K_TEST_INGESTION=BLOCKED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## 1. Canonical storage and hash

Recommend **Plan Package schema v3** with a required `metrics_profile` object
(`profile_schema_version: 1`). Do not extend the meaning or bytes of schema v1
or v2. V3 preserves v2 running documents and introduces no exercise identities
into v1. Keep the compiler in `packages/cohort_plan_package`; Flutter and
trusted tooling continue consuming that single implementation.

Persist the canonical profile as JSONB on `programme_versions`, atomically
with the imported package. This is a verified projection of the canonical
package object, not a separately editable companion authority. The existing
`package_content_hash` covers profile content as part of the v3 canonical
UTF-8 JSON. A separate profile digest may aid diagnostics but cannot replace
or bypass the package hash. Never hash a database-generated version UUID into
the package: publication binds the hash and profile to the exact version row.

Canonical rules must fix allowed fields, enum values, number representations,
units, null/absence, stable-ID sorting for unordered collections, and authored
order for display/test windows. Equivalent input gives identical bytes;
changing a metric, evidence policy, test link, method, parameter, rounding,
intent or display definition changes the hash. Athlete evidence is excluded.

Future v3 import/publication must verify canonical bytes/hash, payload parity,
profile validity and exact references before any write. Freeze profile on
publication/archive using the existing immutable-version protections. Published
corrections require a new version; default replacement never repins athletes.
Draft reads retain existing founder/service-role boundaries; athlete reads
must enforce entitlement to the exact published pinned version, including
historical private versions. No broad draft/catalogue or athlete-evidence grant.

For new v3 versions use an explicit `profile_kind`: `performance` or
`no_performance_claim`. The latter requires a reason and zero performance
metrics; it is not an omission escape hatch for a programme claiming outcomes.
Future launch approval should reject absent/invalid profiles and a
`no_performance_claim` declaration that contradicts the authored promise.
Automated checks enforce structure; founder review judges that promise. This
publication rule is prospective, not retroactive. Supporting the trusted global
import and private publication paths requires separate reviewed v3 adapters;
current v2 private publication does not prove a v3 global route.

## 2. Small definition contract

| Definition | Required meaning |
|---|---|
| Profile | Schema version, kind, authored intent, primary/secondary metric IDs, ordered assessment windows |
| Metric identity | Stable authored ID within programme lineage; runtime key is exact version UUID + package hash + metric ID; label is never identity |
| Classification | `measured` or `derived`; descriptive/diagnostic/outcome role; no inferred coaching interpretation |
| Units | Closed canonical unit and dimension, explicit display conversion and rounding; reject unknown or inconsistent units |
| Source policy | Explicit allowed source kinds and capture fields, manual/backfill permission, capability requirement; device sources deferred |
| Scope | Exact slot/session revision and assessment references; exact block/result field and step/repetition scope when needed |
| Method | Allowlisted method ID + immutable version + explicit parameters; input/output dimensions and deterministic failure rules |
| Quality | Required inputs, completeness, supported plausibility/context checks, freshness policy (including explicit none), minimum coverage |
| Comparison | Named baseline/checkpoint/final windows; compatible test definitions/context, selection/tie-break, improvement direction or none |
| Presentation | Priority, honest authored label and intent; technical details available in Studio |

Metric IDs cannot be reused for changed meaning. An unchanged ID across versions
is not comparison permission. Unit codes such as `ms`, `m`, `kg` and `count`
are a vocabulary proposal, not new capture formats. Each adapter must validate
and convert existing units explicitly; display rounding is not calculation
rounding. Band-based improvement requires later authored band authority; none
is supplied here. Do not infer tests from names, proximity, lineage alone or
relationship-graph adjacency.

Windows must specify authored assessment membership, date/time precision and
IANA timezone rules where time matters. Evidence selection is explicit (for
example latest eligible observation in a named window), with a stable record-ID
tie-break and duplicate rejection. Freshness uses the declared event time/civil
date policy, never correction or ingestion time. Missing baseline suppresses
the comparison while leaving the eligible final observation visible. No
averaging or selection of a best attempt is implicit.

Keep derivations small: typed measured-field extraction with versioned unit
conversion, and a versioned difference between two eligible observations.
No arbitrary expressions, user scripts, weights, composite scores, normative
bands, rankings or physiological models. The method registry defines frozen
semantics in code with golden vectors; package parameters are hashed. Unknown
method versions fail validation/evaluation, never resolve to the newest method.
Retain old implementations for historical replay. B2 arithmetic is reusable
only for its existing explicit policy and eligible evidence; it is not a
default performance metric or threshold estimator.

## 3. Exact authored scope and evidence adapter

Reuse package assessment/comparison IDs as reference hooks. Existing assessment
`evidence_requirement` is text, not a proven typed evidence-key join. V3 must
add explicit typed bindings and validate their consistency with existing arrays;
never reinterpret legacy text or manufacture a relationship from labels.

Compile validates slot keys, session lineage/revision references and declared
assessment/comparison/evidence IDs. Import/publication then resolves exact
published protocol UUID/revision, canonical block IDs and result capture shape.
Running scopes require the B3 attested workout/step/block mapping, supported
repeat identities and work role, not merely an `authored_running_v1` document.
Strength/exercise scope uses the executable snapshot and explicit identity;
Plan Package v1 acquires no exercise IDs. Unsupported scopes fail closed.

At evaluation the authority envelope is: authenticated athlete → assignment
→ exact programme version/hash → occurrence/slot → linked training session
and terminal outcome → History record → block/set/step/repetition IDs →
selected actual fields and correction provenance. Compare independent links;
reject mismatch, duplicate/ambiguous result trees and incomplete scope. Do not
join by date, title, display order, current default or `programme_id` alone.
Start with existing fixed materialised occurrences. Unprovable older records
stay visible in History but are ineligible for profile evaluation.

A partial session may contain a fully measured eligible test scope only when
the hashed metric policy explicitly permits it. Skipped required work cannot
qualify as a complete test. Timer expiry, adherence, terminal slot disposition,
planned load, frozen B2 target or a human-entered pace are never substitutes
for actual evidence of the declared test.

**Cohort 5 km benchmark ingestion remains blocked.** Profile declaration,
B3 completion and exact step links do not enable the B2 ingestion command or
prove elapsed-inclusive-pauses 5,000 m test eligibility. Manual B2 benchmark
records remain their own evidence/revision authority; this foundation neither
writes them nor converts ordinary session results into them. External/device
sources remain unavailable until separately proven and authorised.

## 4. Evidence states and corrections

Evaluation returns typed states, a nullable value, unit, quality/context,
selected evidence references, method/version and explicit reason codes. Numeric
zero is valid only when actually measured and allowed by the field contract.

| Condition | Required projection |
|---|---|
| Successful query, no qualifying evidence | `missing`; no zero or invented baseline |
| Some required scope/fields absent | `partial`; show coverage, suppress whole-test result unless explicit policy permits it |
| Authored scope skipped | `skipped`; excluded, never zero |
| Completed scope with pace/value unavailable | `unavailable`; preserve completion fact |
| Stale / implausible / unsupported source | `ineligible` with reason; no substitution |
| Eligible individual values but incompatible test, unit or context | Show individual facts; `incomparable` comparison, no delta |
| Changed actuals | `corrected` provenance alongside current quality state; recompute affected derivations |
| Query/identity/hash failure | Typed failure; same-context last-good display labelled stale, never empty success |
| Older version lacks profile | `profile_absent_legacy`; existing execution and History continue |

Correction is an annotation, not a competing measurement status. Read current
actuals through existing correction authority; do not append another actuals
ledger. Existing `performance_result_corrections` stores append-only before/
after changes while current result rows are updated. It is not a complete
immutable revision API for every historical record.

Every evaluation carries exact input record/result IDs, correction IDs where
available, a deterministic digest of selected actual values, evaluation time,
profile/package hash, and method version. Coherent reads must prevent mixing
pre-correction fields with post-correction audit data. Before claiming historical
replay, prove complete as-of reconstruction from original values and ordered
correction chains (including ties and concurrent corrections); otherwise return
`historical_inputs_unavailable`. Method freezing alone cannot reproduce a prior
value after mutable actuals have changed.

Use pure on-demand evaluation first, with no persisted metric cache. A later
cache would require input digests and invalidation after correction; it is not
part of this foundation. Corrections never modify profile, prescription,
occurrence snapshot, completion chronology or assignment progression. Window
selection uses performed date/time precision and authored scope; correction
submission time must not move evidence into a different test window.

## 5. Programme-specific read projection

Keep measured facts (including manual source labels), derived values (method
and inputs), and coaching interpretation separate. A difference is descriptive;
it does not prove causation or improvement attributable to the programme.
Interpretation is later authored coaching content with its own approval, not
an evaluator output. No percentile, readiness, discipline or global fitness
score is introduced. Existing generic Progress facts retain their meaning.

Studio later renders the canonical profile read-only: intent, primary/secondary
metrics, units, exact tests/windows, permitted sources, methods, quality policy,
missing/legacy/unsupported findings, and technical binding. Use B4's validated
artifact/hash and graph review path; derived review JSON never authors the
profile. Synthetic evaluation preview starts empty, is clearly labelled and
never persists or selects real athletes. A profile existing does not mean that
its evidence source is available or that programme content is approved.

Later athlete presentation loads the pinned profile and only that athlete's
assignment evidence. Separate attempts on the same version by assignment;
completed/replaced assignments remain inspectable. Baseline/checkpoint/final
comparisons stay within the explicit scope. Cross-version and cross-programme
comparison is deferred even when metric labels/IDs match. Identity/assignment
changes clear last-good state; errors retain it only within the same scope.
No athlete UI, refresh wiring or presentation is implemented in this audit.

## 6. Synthetic contract example only

A synthetic programme `SYNTHETIC-METRICS-DEMO`, with invented slots
`test-start` and `test-end`, explicitly references their protocol revisions,
assessment IDs and an exact test block. `synthetic.elapsed` extracts a captured
elapsed-duration field into canonical milliseconds via `elapsed_field/v1`.
`synthetic.elapsed_delta` uses `difference/v1` (final minus baseline) only when
both exact test scopes and contexts agree. Synthetic inputs 12,000 ms and
11,000 ms produce -1,000 ms. Missing final input gives `missing`; incompatible
context gives `incomparable`; a corrected final of 11,500 ms gives -500 ms with
correction provenance. A skipped test gives no value. This demonstrates only
contract arithmetic, with no fitness interpretation, bands or prescription.

No HYROX/Bali metrics or content files are created. No real benchmark is used
as the example. Synthetic references must resolve in isolated future fixtures;
they must never enter real inventory or publication operators.

## 7. Bounded implementation slices (all require later authority)

| Slice | Scope | Acceptance before next slice |
|---|---|---|
| C1 | Pure v3 profile types, parser, validator, canonicaliser, method contracts and synthetic fixtures | Golden determinism; every profile edit changes hash; exact v1/v2 Apollo/Bali/B3 goldens unchanged; unknown fields/units/methods/refs rejected; no runtime or persistence |
| C2 | Local canonical storage, trusted import/private publication adapters, prospective approval guard, exact executable validation | Disposable DB gates: atomic rollback, canonical/payload parity, repeat import idempotency/conflict, immutable profile, draft/RLS/grants, private historical pin reads, replacement without repin, legacy versions unchanged; no hosted apply or adoption |
| C3 | Read-only fixed-occurrence evidence adapter and pure evaluator; correction provenance/coherent reads | Cross-athlete/assignment/version/hash/scope denial; missing/partial/skipped/unavailable/stale/invalid states; unit conversion; comparison determinism; correction/concurrency/as-of limitations; backfill chronology; no evidence writes or B2 ingestion enablement |
| C4 | Read-only Studio profile review using synthetic inputs | Exact artifact/hash checks; legacy absence distinct from malformed profile; unsupported capability visible; no writes, real metric selections or athlete consumer |

Later athlete presentation is a separately allocated task after the foundation
is accepted, not an implicit C5 licence. Structured authoring Sprint D, real
profile selection, content authoring and hosted application each need separate
authority. Accepting C does not release the strategic pause.

Each implementation slice must run its focused checks and changed-file
analysis. Architecture-affecting implementation also runs the Phase 2
consolidation safety gate; broader verification follows repository guidance.
No warning-baseline exception is inherited. The current documentation audit
runs link validation and diff checks only; none of these future gates is
claimed passed here.

## 8. Material founder decisions

1. Approve or amend **v3 embedded profile + verified immutable version-row
   projection**, preserving every existing v1/v2 hash, rather than a companion
   artifact with a second content identity.
2. Approve or amend the **prospective explicit profile requirement** for new v3
   publication, with an honest `no_performance_claim` declaration and permanent
   legacy compatibility; decide against any retroactive launch/pin mutation.
3. Approve or amend **C1–C4 foundation scope**, limited derivations and current
   corrected evidence with honest historical replay limits. Then separately
   authorise a concrete implementation slice (recommended first: C1).

Real metric choices, test prescriptions, bands and weights belong to future
content-authoring decisions and are not questions blocking this infrastructure
proposal. There is no request to approve hosted work or programme changes.
