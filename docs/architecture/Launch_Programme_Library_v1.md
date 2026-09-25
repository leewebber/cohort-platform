# Launch Programme Library v1

**Status:** Strategy **approved**. Infrastructure architecture defined.
Infrastructure **not** started. Programme content **not** authorised.
Hosted publication **not** authorised.
**Recorded:** 2026-09-25
**Strategy bound:** 2026-09-25
**Audit:**
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md)
**Children:**
[`Programme_Studio_v1.md`](./Programme_Studio_v1.md),
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md),
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md)
**Base:** `origin/main` `a2faba6740d55359822689e5cc8c907185ebc97c`

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED_INFRASTRUCTURE_NOT_STARTED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PROGRAMME_STUDIO_IMPLEMENTATION_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
```

This document binds the founder-approved launch-library **strategy** and
the supporting infrastructure architecture. It is **not** a licence to
implement Studio, running/device code, metrics schema, or any programme
content. Compilation alone is not launch approval.

Parents:
[`Authored_Plan_Package_v1.md`](./Authored_Plan_Package_v1.md),
[`Athlete_Catalogue_Enrolment_v1.md`](./Athlete_Catalogue_Enrolment_v1.md),
[`Athlete_Programme_Discovery_and_Decision_v1.md`](./Athlete_Programme_Discovery_and_Decision_v1.md),
[`Complete_Athlete_Experience_v1.md`](./Complete_Athlete_Experience_v1.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md),
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md),
[`../checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](../checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).

---

## 1. Purpose

An authenticated athlete can already discover, enrol, train, complete, and
retain history. The remaining product hole is **honest choice**: there are
not yet enough **launch-quality authored programmes** for a meaningful
beta population.

This milestone must produce:

- one recommended authoring and publication authority
- a mandatory metadata contract
- a quality gate that is stricter than compile/import
- a small curated catalogue, not fake breadth

It must preserve existing authorities: Plan Package interchange, immutable
`ProgrammeVersion`, catalogue eligibility, exact-version pin, Programme
Athlete execution, completion, and history.

## 2. Non-goals

This milestone must **not**:

- implement programmes, publish catalogue content, or apply migrations
- invent coaching content
- change Plan Package v1 to carry exercise identities
- start Build Your Own, matching, or the adaptation engine
- start payments, wearables, Android, or commercial launch
- reopen Complete Athlete Experience
- treat fixtures, previews, or seeds as launch programmes
- convert Apollo into a commercial programme
- create HYROX Base or any other launch-family content
- implement Programme Studio, Garmin integration, or payments
- claim Garmin, Whoop, or other integrations before they exist
- delete or mutate hosted Spartan / Apollo rows
- contact Field Manual except optional founder-authorised SELECT

---

## 3. Current authority trace

Recommended production path (do **not** consolidate competing paths in
this task):

```text
authored Plan Package v1 YAML
  → PlanPackageYamlParser
  → PlanPackageValidator
  → PlanPackageCanonicaliser + SHA-256
  → trusted import (service-role import_authored_plan_package)
  → hidden cohort_global draft
  → publish_cohort_global_programme_version
  → approve_cohort_global_programme_version
     or replace_approved_cohort_global_programme_version
  → athlete catalogue discovery (published + approved + not archived)
  → enrol_athlete_in_catalogue_programme_version (exact version UUID)
  → start_fixed_programme_from_enrolment
  → Home / Calendar / Daily Journey
  → complete_fixed_programme_occurrence_and_advance
  → Progress / History
```

| Boundary | Authority |
|----------|-----------|
| Interchange | Plan Package v1 YAML (`package_schema_version: 1`) |
| Compile / hash | `packages/cohort_plan_package` (`PlanPackageCompiler`) |
| Session body | Published `performance_protocols` + session blocks (not the package) |
| Upstream protocol authoring | Founder Programme YAML import **or** protocol builder — **not** catalogue interchange |
| Import | `import_authored_plan_package` (`service_role` only) |
| Publish / approve | `publish_cohort_global_programme_version`, `approve_cohort_global_programme_version` |
| Default swap | `replace_approved_cohort_global_programme_version` |
| Discovery | RLS + `AthleteProgrammeSwitchCatalogService` |
| Enrolment pin | `programme_assignments.programme_version_id` |
| Execution | Programme Athlete runtime; authored prescription |
| Graph | M9 derived read-model bound to package hash; not prescription |

**Authors should use Plan Package v1 YAML** for catalogue schedule and
metadata, after executable protocols exist and are published. Raw YAML
text is not canonical meaning.

**Determinism:** successful compile produces a stable canonical JSON
SHA-256 (golden-tested). Import still depends on hosted protocol state.
A compile-valid package can fail import, publish, approve, or
materialisation.

**Identity:** content identity is the package hash. Row identity is
`programme_versions.id`. Human key is `(lineage_code, version_number)`.

**Immutability:** published content cannot be edited in place. A correction
is a new `version_number` on the same lineage.

**Default replacement** changes only catalogue eligibility. Enrolled
athletes stay on the pinned version. They are not auto-repinned.

**Draft leak:** athlete catalogue SELECT requires published +
`cohort_global` + `approved_for_global`. Drafts and published-unapproved
rows must not appear.

**Publication tooling:** intended path is service-role RPCs via trusted
import. Historical Apollo/Spartan **SQL protocol migrations** remain
hosted content, not the interchange authority. Trusted Cloud Run import
is implemented locally and **not** the assumed production operator path
until separately verified.

**Competing paths (do not mix):** Founder Programme YAML as catalogue
writer; coach-private drafts; Journey D staging; raw SQL seeds; Plan
Library / Coach Brain generation; M9 graph publication as if it were
prescription.

---

## 4. Source and inventory classification

| Item | Classification | Launch credit |
|------|----------------|---------------|
| Apollo Build v2 (`APOLLO-BUILD-12-WEEK`) | Production-published on Field Manual (M9). Authored 12-week / 7-day concurrent block. | **Candidate dogfood / experienced hybrid.** Not a beginner product. Not launch-approved by this audit. |
| Spartan Physique v3 (`SPARTAN-PHYSIQUE`) | Production-published (M9). Repo Plan Package is **1 week / 6 days**. | **Incomplete as a launch family.** Keep as published founder content; do not sell as an 8-week product. |
| HYROX Base / Elite / Foundation | Planning names only. **No authored YAML or protocols in repo.** | **Not launch programmes.** |
| Founder Acceptance, COHORT-FOUNDATION-TEST | Development / seed | None |
| Minimal plan package, founder example YAML, S17 fixtures, SQL gates | Test / example | None |
| Discovery preview Apollo/Spartan fixtures | Preview-only invented metadata | None — **must not** be copied into catalogue rows |

Successful render or founder dogfood does **not** make a fixture a launch
programme.

---

## 5. Content-model capability

Two layers:

1. **Plan Package v1** — schedule, phases, week/day intent, slot
   references, adaptation/assessment *contracts*. No exercise IDs. No
   prescriptions.
2. **Executable protocols** — `session_blocks` + structured links +
   `WorkoutFormat` / `TimerConfiguration`. This is athlete execution
   truth.

| Capability | Verdict | First-library note |
|------------|---------|--------------------|
| Strength sets/reps/load | Supported on block links; compact Apollo JSON can drop top-level RIR and range rest | Quality: normalise prescriptions at author time |
| Run distance/duration/pace/zone | Partial (timer JSON + text; not first-class zone/pace fields) | Quality: prefer explicit duration + effort; avoid format overload |
| Intervals / recoveries | Supported on block path | Usable |
| Erg work | Supported when an `EX-*` + capture mode exist | HYROX stations remain incomplete |
| Circuits / mixed-modal | Partial; `WorkoutFormat.other` without capture **fails closed** | Blocker if authored as `other` |
| Supersets / rounds | Partial via execution groups | Quality |
| Warm-up / cooldown | Supported; Apollo required later structure migrations | Gate must render every distinct type |
| Coaching cues | Partial (protocol/block notes; Exercise Knowledge not production-composed) | Quality |
| Substitutions / equipment | Protocol strings + later adaptation; **not** in Plan Package v1 | Quality for first library; adaptation is later |
| Tests / benchmarks | Schema exists; Apollo package arrays empty | Quality: declare assessments in package when claiming tests |
| Rest days | Supported (`day_type: rest`) | Use for 3–4 day programmes |
| Week progression / deload | Authored as new protocol revisions + week `intent` | Not parametric — acceptable |
| Session intent | Supported | Required metadata |
| Completion evidence | Block capture modes exist; package evidence unused | Gate must prove Progress/History |

**Launch-library blockers** are missing **authored families** and
incomplete HYROX station identity — not the absence of a package
compiler. Apollo-shaped hybrid training is **model-viable** with known
encoding gaps.

---

## 6. Mandatory programme metadata contract

Every publishable catalogue version must carry authored facts on the
**same** `programme_versions` row that athletes enrol into. Facts must
not be invented in preview fixtures.

| Athlete label | Source field | Required |
|---------------|--------------|----------|
| Title | `name` | Yes — product title, not a code |
| Promise / goal | `primary_goal` | Yes — one sentence |
| Description | `description` | Yes — honest duration, audience, and what the weeks do |
| Duration | `duration_weeks` | Yes — matches scheduled weeks |
| Sessions / week | `sessions_per_week` | Yes — matches a typical training week, not marketing inflation |
| Intended level | `difficulty` | Yes — beginner / intermediate / advanced (or equivalent authored scale) |
| Equipment | `equipment_requirements` | Yes — truthful kit, including “full gym” vs “run + dumbbells” |
| Training domains | authored in description and/or later emphasis fields | Yes in prose until dedicated columns exist |
| Prerequisites | in description until a dedicated field exists | Yes — who should **not** start |
| Expected weekly time | optional until a column exists | Recommended in description |
| Contraindication / suitability | in description when the work is high-volume or race-specific | Required for 7-day or race programmes |

**Pin rule:** Programmes tab, Home completed card, Calendar, and
continuity copy must use the **pinned version**. Catalogue default may
explain that a newer version exists. It must not overwrite title, goal,
or duration on the pin.

Discovery / detail / comparison already display title, goal, duration,
frequency, level, equipment, and description. Optional slots
(`trainingEmphasis`, `sessionFormats`, `progression`, `recovery`) are
unwired. Do **not** redesign UI in this milestone. Two real programmes
compare honestly if facts differ; more than about four similar cards
will feel repetitive without filters (filters are later).

---

## 7. Founder-resolved launch catalogue (2026-09-25)

The 2026-09-25 audit recommendation (Hybrid Foundation first; Apollo as
a commercial advanced SKU; one later HYROX Foundation) is **superseded**
as strategy. Historical text remains in
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md)
§9.

### Positioning

Cohort is the **integrated performance platform for hybrid athletes**.
HYROX is the **initial acquisition wedge**. The athlete-facing product
goal is to unite high-quality strength, running, erg, conditioning, and
performance evidence in one coherent system.

Do **not** claim Garmin, Whoop, or other integrations before they are
implemented and verified.

### Intended families (content not authorised)

| Family | Duration | Audience / intent |
|--------|----------|-------------------|
| **A. HYROX Base** | 8 weeks | Physical preparation before race-specific training: aerobic development, running durability, foundational strength, tissue resilience, movement quality, erg technique, controlled race-specific introduction |
| **B. HYROX First Race** | 16 weeks | First or second race; beginner in HYROX experience, not necessarily sedentary; education, technique, conservative progression, pacing, completion confidence |
| **C. HYROX Performance** | 16 weeks | Experienced racer seeking a meaningful improvement; progressive running, strength, compromised running, station specificity, race execution |
| **D. HYROX Pro Performance** | 16 weeks | Experienced high-capacity athlete preparing for Pro / high performance; sub-60 **oriented**, never guaranteed; scale via benchmark-derived targets, zones, percentages, prerequisites; useful whether ~15 min or ~2 min from sub-60 |
| **E. Tactical Athlete 365** | 16 weeks (proposed) | Existing tactical professionals, year-round all-round fitness; **not** selection, recruitment, or generic “military fitness” |
| **F. Strength for Endurance** | 12 weeks (proposed add-on) | Runners, cyclists, triathletes; two core strength sessions; optional third only if optionality can be represented honestly; must not pretend to manage the full endurance plan |
| **G. Strength for Life 55+** | 12 weeks, 3 days (proposed) | Muscle, strength, movement, balance, resilience, independence; **later** because it needs distinct suitability, regression, accessibility, and safety treatment |

### Build order

1. HYROX Base
2. HYROX Pro Performance
3. HYROX First Race
4. HYROX Performance
5. Strength for Endurance
6. Tactical Athlete 365
7. Strength for Life 55+

The intended **public HYROX proposition** is the coherent
**four-programme family**. Families are authored and validated
**sequentially**.

### Catalogue exclusions (bound)

- **Apollo** remains a personal / internal programme and test case — not
  a commercial launch programme. Do not convert it in this milestone.
- **Spartan** is legacy and **withheld** from the launch catalogue. Do
  not delete or mutate it in this task.
- **No generic Hybrid Foundation** is currently planned.
- Programmes are intended to be **paid**. Trial / free utility belongs
  to later commercial / payments architecture.
- **Fixed authored programmes** remain product authority.
  Generated / bespoke plans are deferred.

### Build Your Own later

Launch families become the approved component library for a later BYO
engine. This milestone must not start a generator.

---

## 8. Authoring and publication workflow

1. **Author session bodies** as published protocols (Founder YAML import
   or protocol builder) using canonical `EX-*` identities.
2. **Author the Plan Package** schedule and metadata in YAML.
3. **Local compile** (`PlanPackageCompiler`) — fail closed on validation.
4. **Local / preview review** of every distinct prescription type.
5. **Founder coaching approval** against the quality gate (human).
6. **Trusted import** to a hidden draft (`service_role` RPC only).
7. **Publish**, then **approve** (or **replace** the lineage default).
8. **Derived M9 graph** only after the package hash is frozen.
9. **Correct unpublished:** mutate draft or re-import same version if
   still draft and graph-matches.
10. **Correct published:** new immutable version; replace default; do
    not rewrite pins.
11. **Withdraw:** archive / unapprove via replacement RPC so enrolled
    athletes keep the pinned version.

**Infrastructure (architecture only; not started):**

- Programme Studio Stage 1 — read-only review
  ([`Programme_Studio_v1.md`](./Programme_Studio_v1.md))
- Structured running workout + pace-calculation foundation
  ([`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md))
- Programme-version metrics profile
  ([`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md))

Compile/hash, import, and publish RPCs may remain command-line until
Studio Stage 3. Trusted import deployment verification remains a later
operational task.

---

## 9. Immutable version, default, and pin

- Published versions are immutable.
- One catalogue-eligible version per lineage.
- Enrolment binds `programme_version_id` exactly.
- Replacement is catalogue-default only.
- No automatic repin or version upgrade (Complete Athlete Experience
  exclusion, unchanged).
- Unpublished drafts must not leak into discovery.

---

## 10. Programme quality gate

A programme is **launch-ready** only when all of the following pass.
Compile/import/hash is necessary and **not sufficient**.

| Check | Automated | Founder / head-coach |
|-------|-----------|----------------------|
| Coaching / programming review (audience, volume, progression, honesty) | No | **Required** |
| Package schema validation | Yes | — |
| Deterministic compile + SHA-256 | Yes | — |
| Structural / semantic validation | Yes | Spot-check |
| Exercise / session reference integrity | Yes (import + local gates) | Confirm `EX-*` intent |
| Render every distinct prescription type | Partial (widget/SQL gates) | **Required** device pass |
| Materialisation | Yes (local gates) | Confirm start date / timezone |
| Calendar + Daily Journey execution | Partial | **Required** on production path |
| Completion | Yes / device | **Required** at least one full week + final-session pattern |
| Progress / History evidence | Partial | **Required** — failure ≠ empty |
| Narrow screen + large text | Existing discovery tests | Spot-check new copy |
| Pin vs default replacement | Yes (continuity + replacement tests) | Confirm copy |
| Forward-fix / rollback | RPC contracts exist | **Required** runbook before first new publish |

**Failure / recovery**

- Draft errors: fix and re-import; do not publish.
- Published error: new version + replace default; leave pins.
- Unsafe prescription: fail closed at prepare/start; do not invent a
  substitute session.
- Hash mismatch: refuse import/start.
- Catalogue leak: treat as a P0 integrity defect.

---

## 11. Implementation boundaries

**Strategy is approved. Infrastructure is not authorised by this
document.** A later founder task may authorise infrastructure sprints
only.

Those sprints may implement Studio Stage 1, the running workout model,
and metrics-profile **foundation**. They must **stop before** any real
HYROX Base (or other launch-family) session prescription, source file,
or metrics selection.

Implementation must **not**:

- author launch-programme content
- convert Apollo or withdraw/delete Spartan
- manufacture Plan Package exercise IDs
- publish or change hosted catalogue defaults
- implement Garmin or Whoop
- start payments, beta, BYO, or adaptation engine

**Hard stop:** no real launch-programme source, session prescription, or
metrics selection may be created until a later founder
**content-authoring** approval.

---

## 12. Acceptance gates

| Layer | Status |
|-------|--------|
| Strategy | **Approved** (this revision) |
| Infrastructure architecture | Defined; **not implemented**; awaits founder approval of the infrastructure docs |
| Programme content | **Not authorised** |
| Hosted publication | **Not authorised** |

The Cohort product remains not launch-ready.

---

## 13. Deferred work

- Any HYROX / Tactical / Strength family content
- Apollo commercial conversion
- Spartan launch inclusion or deletion
- Hybrid Foundation
- Studio Stage 2–3 implementation until separately authorised
- Garmin / Whoop / wearable provider adapters
- Payments, trial, beta, BYO, matching, adaptation
- Exercise Knowledge / media in athlete UI
- catalogue filters, imagery
- Final physiological pace formulas
- Final per-programme metric selections

---

## 14. Infrastructure-only slices (recommended)

Safer order than “Studio first” because HYROX Base cannot be authored
on ambiguous pace/zone encoding, and a metrics bind must exist before
any family claims outcomes. Studio Stage 1 can still proceed in
parallel as read-only over **existing** Apollo/Spartan.

| Sprint | Scope | Stops before |
|--------|-------|--------------|
| **A** | Programme Studio Stage 1 — read-only review / validation | Writes, publish, new content |
| **B** | Structured running workout + versioned pace-calculation **foundation** (no formulas without later approval; no Garmin) | Launch run prescriptions; provider APIs |
| **C** | Programme-version metrics-profile **foundation** (schema/bind description → later additive package or companion hash) | Selecting real HYROX metrics |
| **D** | Controlled structured authoring workflow (Studio Stage 2 emitting canonical YAML only) | Real launch-family prescriptions |

**Minimum before HYROX Base content authoring is even proposed:** A + B
+ C complete and founder-accepted; content still requires a **separate**
authoring approval.

Garmin provider implementation remains a separately approved future
integration. Sprint B may add a vendor-neutral DTO only.
