# Launch Programme Library — architecture and readiness audit

**Recorded:** 2026-09-25
**Status:** Original audit preserved. Strategy **approved**.
Infrastructure architecture **approved**. Programme Studio Stage 1
**COMPLETE**. Sprint B **audited, awaiting approval**. Programme
content **not** authorised.

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=AUDITED_AWAITING_APPROVAL
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
HOSTED_INSPECTION=false
PUSHED=false
```

**Base:** `origin/main` `a2faba6740d55359822689e5cc8c907185ebc97c`

Binding:
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md),
[`COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](./COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md)
§4,
[`../architecture/Authored_Plan_Package_v1.md`](../architecture/Authored_Plan_Package_v1.md).

Hosted Field Manual was **not** contacted. Publication facts below are
from committed M9 closeout and repository artifacts.

---

## 1. Why this audit exists

Complete Athlete Experience closed the production journey around Daily
Journey. The next sequenced item is the **launch programme library**.
The hosted athlete catalogue today is **two** published families. Most
names in the product-plan family table have **no authored source**.

This audit separates:

- what is already a production-published programme
- what is a fixture or preview
- what the package/runtime can execute
- what must be authored before beta is useful

---

## 2. Repository evidence

### 2.1 Authored / published families

| Programme | Paths | Title | Purpose | Duration | d/w | Level | Equipment | Domain | Format | Validation / publication | E2E |
|-----------|-------|-------|---------|----------|-----|-------|-----------|--------|--------|--------------------------|-----|
| Apollo Build v2 | `tool/programmes/apollo_build_12_week_implementation_source.md`; `tool/programmes/apollo_build_12_week_v1.plan-package.yaml`; `supabase/migrations/20260821120000_*`–`20260821135000_*`; publish `20260822120000_publish_apollo_build_protocols.sql`; M9 `content/content_graph/v1/cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.*` | Apollo Build — 12-Week Initial Block | Founder concurrent physique + aerobic / Racehorse block | 12 | 7 | Experienced (source MD) | Conventional gym → barbell, cables, sled, SkiErg, run | Hybrid concurrent | MD + Plan Package v1 + SQL protocols | Package compile tests exist; M9 `APOLLO_V2_MANIFEST_PUBLISHED=true`; version `2ba018bd-7dc2-4dfd-8d8e-e35823158920`; hash `81033429…dd0b83` | Founder dogfood + local Apollo gates. **Not** a launch-quality review of every week as a sold SKU. |
| Spartan Physique v3 | `tool/programmes/spartan_physique_block1_week1.yaml`; `tool/programmes/spartan_physique_block1_week1.plan-package.yaml`; `content/content_graph/v1/sources/spartan_physique_v3.relationships.json`; M9 `…/spartan/32986922-47d1-46b0-b391-a7931d73033e.*` | Spartan Physique Block 1 | Upper-body relative strength + aerobic base (week 1) | **1** (package) | 6 | Not declared as beginner/intermediate | Gym slugs (pull-up, DB, row erg, carries) | Physique / hybrid | Founder YAML + Plan Package v1 | M9 `SPARTAN_V3_MANIFEST_PUBLISHED=true`; hash `b4bfaab4…05473e` | Week-1 structure only. Not a complete launch family. |

YAML `library_scope` on Apollo is `organisation` and the package comment
says it does not create a hosted version. Hosted publication used the
**SQL + M9** path. Treat Plan Package as interchange; treat M9 closeout
as publication evidence.

### 2.2 Not launch programmes

| Item | Paths | Classification |
|------|-------|----------------|
| HYROX Base / Elite / Foundation / Intermediate | Product plan §4 tables only | Incomplete — **no files** |
| Founder Acceptance | `lib/features/founder_acceptance/` | Development / demo |
| Cohort Foundation Test | `supabase/seed/cohort_foundation_test_programme.sql` | Seed fixture |
| Founder example YAML | `tool/examples/founder_example_programme.yaml` | Documentation example |
| Minimal plan package | `packages/cohort_plan_package/test/fixtures/minimal_plan_package.yaml` | Test fixture (`PROG-FIXTURE-01`) |
| S17 Journey D / Gate 1 YAML | `tool/staging/fixtures/` | Staging fixtures |
| SQL gate packages | `supabase/tests/sql/gate_j_catalogue_enrolment.sql` etc. | Test-only |
| Discovery preview Apollo/Spartan | `lib/features/programme/presentation/programme_discovery_decision_preview_catalog.dart` | Preview — **invented** 5 d/w / 8-week facts |

### 2.3 Authority implementations

| Stage | Evidence |
|-------|----------|
| Parse / validate / hash | `packages/cohort_plan_package/lib/src/plan_package_{yaml_parser,validator,canonicaliser,compiler}.dart` |
| Import RPC | `supabase/migrations/20260731120000_authored_plan_package_import.sql` |
| Approve / replace | `20260813160000_atomic_catalogue_version_replacement.sql` |
| Enrol | `20260801120000_athlete_catalogue_enrolment.sql`; latest body `20260923120000` |
| Materialise / start | `start_fixed_programme_from_enrolment` (`20260824120000`) |
| Discovery UI | `athlete_programme_selection_screen.dart`, `athlete_programme_decision_facts.dart` |
| Pin vs default | `athlete_programme_continuity.dart` |
| Trusted import | `server/trusted_plan_package_import/` — local; deployment not assumed |

### 2.4 Preview metadata hazard

Preview Apollo is titled “Apollo”, 12 weeks, **5** sessions/week,
“Intermediate”, “Barbell, run route”. The authored package is **7**
sessions/week and dogfood-positioned. Preview Spartan is “eight-week”
and “Advanced”; the package is **1 week**. Production catalogue must
not inherit preview numbers.

---

## 3. Readiness scoreboard

| Area | Score | Note |
|------|-------|------|
| Journey (discover → enrol → train → complete) | **Ready** | CAE complete |
| Package compile / hash | **Ready** | Deterministic for success |
| Publication RPCs | **Ready** | Import / publish / approve / replace |
| Pin / default integrity | **Ready** | CAE Sprint 2 |
| Hosted catalogue depth | **Not ready** | Two families; one is a 1-week block |
| Honest product metadata | **Partial** | Preview facts diverge; hosted rows not re-SELECTed this audit |
| Hybrid Foundation | **Missing** | Highest-value new family |
| HYROX programmes | **Missing** | Planning only |
| Apollo as sold SKU | **Partial** | Encoded and published; 7 d/w; encoding gaps; assessments empty in package |
| Spartan as sold SKU | **Not ready** | Incomplete duration |
| Quality gate (human + device) | **Defined, not run** as a launch gate |
| Authoring operator path | **Partial** | SQL history vs trusted RPC; Cloud Run not verified here |
| BYO / matching / adaptation | **Out of scope** | Later |

---

## 4. Confirmed candidates versus fixtures

**Confirmed production-published (repo + M9):** Apollo v2, Spartan v3.

**Confirmed authored launch *candidates* (not approved):** Apollo v2
(experienced concurrent); Hybrid Foundation (to be authored).

**Not candidates:** every fixture, seed, preview, example, gate package,
and every HYROX/Base/Elite name until files exist.

---

## 5. Content-model verdict

The **runtime can execute** Apollo-shaped hybrid work: strength blocks,
conditioning formats (intervals, EMOM, rounds, steady state), ergs when
`EX-*` exist, warm-up/cooldown, rest days, week intents.

The **package cannot carry prescriptions**. Every new family needs
protocols first.

**Blockers for the first library:** no Hybrid Foundation source; no
HYROX source; `WorkoutFormat.other` without capture fails closed;
selling Spartan as multi-week without more weeks.

**Quality (not first-slice blockers):** top-level Apollo `rir` / range
`rest_seconds` / `eccentric_seconds` drop-through; zone/pace typing;
empty package `assessments`; equipment only as protocol strings.

**Future:** parametric progression, package-native substitution,
SessionBlueprint generation, Exercise Knowledge UI.

---

## 6. Catalogue UI verdict

Existing discovery, detail, comparison (max two), enrolment review, and
completed continuity can present **a few real programmes** if metadata
is truthful and distinct.

Risks:

- two cards that look like the preview fixtures will mis-state Apollo
  frequency and Spartan duration
- 8–12 similar hybrid cards will be hard to compare without filters
- optional comparison rows are never populated

Do not redesign UI in the first implementation slice. Fix **authored
facts on the version row**.

---

## 7. Blockers and risks

1. **Catalogue is too thin and mis-positioned** for a general beta
   (7-day Apollo + 1-week Spartan).
2. **Dual authoring history** (SQL seeds vs Plan Package import) can
   produce metadata / hash / graph drift.
3. **Trusted import deployment** is not proven in this audit.
4. **Preview fixtures** can leak invented facts into founder review.
5. **HYROX names** create false readiness if used in marketing before
   protocols exist.
6. **Quality-gate inflation** (media, substitutions, 8–12 families)
   would stall the milestone. Keep the first gate executable.

---

## 8. Proposed implementation sequence

After founder approval only:

1. **Docs / decisions** — record
   `LAUNCH_PROGRAMME_LIBRARY=ARCHITECTURE_APPROVED`. Still no
   implementation until a separate authorised slice.
2. **Slice A (smallest first implementation):** Hybrid Foundation
   authoring + compile + local execution of every distinct session type
   + truthful catalogue metadata. No Field Manual publish until the
   quality gate and a later publish task.
3. **Slice B:** Apollo launch-quality pass (honest metadata, prescription
   normalisation, assessment declaration). No automatic default change
   for existing pins.
4. **Slice C:** decide Spartan complete-or-withhold.
5. **Slice D:** one HYROX Foundation family after station/exercise
   identity is actually available — not “Base” and “Elite” together.

Do not start BYO, adaptation, payments, or beta recruitment in these
slices.

### Smallest sensible first implementation slice

**Slice A only:** one new Hybrid Foundation programme through local
quality gate, using the existing Plan Package + protocol pipeline, with
no hosted publish in that first coding task unless separately
authorised.

---

## 9. Founder decisions required

Ask only these. Each has a recommendation.

### D1. Initial catalogue size

**Recommend:** **three-slot target** (Hybrid Foundation + Apollo as
advanced + later one HYROX Foundation). First coding slice authors
**one** new programme. Reject an 8–12 family drop.

### D2. Launch domains / goals

**Recommend:** concurrent hybrid first; one race family later. Do not
lead with running-only.

### D3. Supported athlete levels

**Recommend:** beginner–intermediate as the **default** product
(Hybrid Foundation). Keep Apollo labelled experienced / high frequency.

### D4. Is Apollo a launch programme?

**Recommend:** **Yes, as an advanced concurrent option**, after a
quality/metadata pass. **No** as the only or default beginner programme.

### D5. Are HYROX Base and Elite launch programmes?

**Recommend:** **No.** They have no authored source. Prefer a single
later **HYROX Foundation** family. Do not publish Base and Elite as
title variants.

### D6. Minimum equipment profile

**Recommend:** Hybrid Foundation assumes **gym or limited gym + a run
surface**. Sled / SkiErg / official HYROX kit are **not** required for
the first family. Document substitutes only when the session is actually
authored that way.

### D7. Acceptable authoring / review workload

**Recommend:** founder reviews **one complete family at a time**. Do not
author two race programmes and three hybrid variants in parallel.

---

## 10. Quality-gate verdict

The gate in
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md)
§10 is the proposed contract.

**Compilation ≠ launch approval.** No programme in this audit is marked
launch-ready.

Automated coverage already exists for compile/hash, catalogue
eligibility, pin, materialisation, and production-entry isolation.
Device coaching review and a publish runbook do not.

---

## 11. Explicit non-actions (original audit task)

- No Dart, SQL, migrations, tests, fixtures, or config changes
- No hosted SELECT / push / publication
- No athlete contact
- No programme authorship
- No next-milestone implementation

---

## 12. Founder resolution (2026-09-25)

Strategy is **approved**. Infrastructure is **architected only**.
Programme content, Studio implementation, Garmin, and hosted
publication remain **unauthorised**.

Children:
[`../architecture/Programme_Studio_v1.md`](../architecture/Programme_Studio_v1.md),
[`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md),
[`../architecture/Programme_Performance_Metrics_Profile_v1.md`](../architecture/Programme_Performance_Metrics_Profile_v1.md).

§9 recommendations above are **historical**. They are not the live
catalogue plan.

### 12.1 Bound decisions

- Cohort = integrated performance platform for hybrid athletes
- HYROX = initial acquisition wedge
- Product unites strength, running, erg, conditioning, and evidence
- No Garmin/Whoop claims before implementation
- Intended families A–G and build order 1–7 as in
  [`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md)
  §7
- Public HYROX proposition = four-programme family, authored sequentially
- Apollo = internal/test; not commercial
- Spartan = legacy, withheld; not deleted
- No Hybrid Foundation
- Paid programmes; trial/free is later commercial work
- Fixed authored programmes remain authority; generated plans deferred

### 12.2 Current running capability verdict

Block-native production path is a **strong foundation** for time-based
steady-state and interval running with manual capture. Authored pace,
zone, HR, power, cadence, nested repeats, laps, treadmill substitution,
and device export/import are **missing or unsafe/ambiguous**. Legacy
`IntervalSessionPlanBuilder` is **not** the production launcher.

HYROX Base must not be authored on prose zone/pace strings.

### 12.3 Programme Studio

Internal desktop/web. Stage 1 read-only over canonical Plan Package +
protocols. Stage 2 writes the same canonical source. Stage 3 explicit
publish. No unrestricted DB editing. Minimum review stage before
content review: Stage 1. Compile/publish may stay CLI.

### 12.4 Structured workout / device interop

Vendor-neutral `RunningWorkout` + steps. Garmin is not authority.
Cohort works without wearables. Provider APIs deferred. Athletes
should not re-enter reliable matched device data once import exists.

### 12.5 Pace-calculation verdict

Separate authored intent, programme policy, athlete benchmark,
calculated target, and actual. Methods must be versioned and tested.
**No final physiological formulas** chosen.

### 12.6 Metrics-profile verdict

Profile owned by the immutable programme version. Plan Package
assessments/evidence are a **hook**, not sufficient. A later additive
package field or companion hashed artifact is likely. Do not implement
schema now. Do not select real metrics now. Fail-closed publish once
the rule is introduced.

### 12.7 Revised readiness scoreboard

| Area | Score |
|------|-------|
| Programme Studio review | Architecture only |
| Structured authoring | Architecture only |
| Running workout model | Architecture only; current execution = time-based foundation |
| Pace calculations | Contract only; no approved formulas |
| In-app interval execution | Production-complete for time-based block intervals |
| Garmin export readiness | Not started; preview flags only |
| Activity import / reconciliation | Not started |
| Metrics-profile binding | Hook only; foundation not implemented |
| Programme-specific Progress projection | Not started (CAE last-good still applies) |
| Publication quality gate | Defined; not run for any launch family |

### 12.8 Infrastructure slices

**A** Studio Stage 1 → **B** running + pace foundation → **C**
metrics-profile foundation → **D** structured authoring workflow.
Hard stop after D: no real launch-programme source, prescription, or
metrics selection until later content-authoring approval.

### 12.9 Unresolved decisions that still change infrastructure

1. **Final pace/zone formulas** — require evidence + head-coach
   approval (not an infrastructure-start blocker if methods stay
   versioned stubs).
2. **Metrics profile storage** — additive Plan Package field vs
   companion hashed artifact (compatibility review).
3. **Strength for Endurance optional third session** — whether Plan
   Package needs an honest optional-slot primitive.
4. **First wearable provider** — Garmin vs other; adapter remains a
   separate integration.

Trial/free, pricing, and exact HYROX kit substitutions do **not**
change infrastructure sprints A–C.

### 12.10 Non-actions (this resolution task)

- No programme sessions authored
- No Apollo commercial conversion
- No HYROX Base content
- No Dart/SQL/schema/dependency changes
- No Studio or Garmin implementation
- No hosted publish/withdraw/delete
- No payments, beta, or launch work

Dated live flags at resolution time (superseded by §13):
`LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED_INFRASTRUCTURE_NOT_STARTED`,
`PROGRAMME_STUDIO_IMPLEMENTATION_AUTHORISED=false`.

---

## 13. Infrastructure approval (2026-09-25)

Founder approved the infrastructure architecture as governing
direction:

- [`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md)
- [`../architecture/Programme_Studio_v1.md`](../architecture/Programme_Studio_v1.md)
- [`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md)
- [`../architecture/Programme_Performance_Metrics_Profile_v1.md`](../architecture/Programme_Performance_Metrics_Profile_v1.md)

Infrastructure may proceed **sequentially**. Sprint A is the next
slice: **approved, not started**. This approval does **not** start
implementation.

| Sprint | Authorised to begin now |
|--------|-------------------------|
| A Programme Studio Stage 1 | Next slice only (separate implementation task) |
| B Running / pace foundation | No — after A accepted |
| C Metrics-profile foundation | No — after B accepted |
| D Structured authoring | No — after C accepted |

HYROX Base authoring may not even be proposed until A, B, and C are
accepted. Real programme content remains unauthorised.

Sprint A boundary and acceptance: Programme Studio §5 / §8 / §9.

Deferred (do not block A): pace/zone formulas → B; metrics storage →
C; optional third session → before Strength for Endurance; Garmin
provider → later device approval.
