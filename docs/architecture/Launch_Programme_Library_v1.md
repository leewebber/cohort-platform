# Launch Programme Library v1

**Status:** Binding architecture for the launch programme library
milestone. Audited; **not** approved for implementation.
**Recorded:** 2026-09-25
**Audit:**
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md)
**Base:** `origin/main` `a2faba6740d55359822689e5cc8c907185ebc97c`

```text
LAUNCH_PROGRAMME_LIBRARY=AUDITED_AWAITING_APPROVAL
LAUNCH_PROGRAMME_LIBRARY_IMPLEMENTATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
```

This document defines the smallest excellent authored catalogue that can
make Cohort useful for beta and launch. It is **not** an implementation
licence. It does **not** mark any programme launch-ready. Compilation
alone is not launch approval.

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
- treat Apollo or HYROX planning names as approved inclusion
- implement coach-authoring product UI
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

## 7. Recommended launch catalogue

### Strategy

Choose a **small curated library**, not an 8–12 family first drop.
The product plan’s 8–12 table remains a **later horizon**, not the first
implementation slice.

Avoid title clones. Variants exist only when prescription, volume, or
equipment actually differ.

### Coverage target (first useful library)

| Goal / domain | Beginner–int. | Advanced | Duration | d/w | Equipment |
|---------------|---------------|----------|----------|-----|-----------|
| Concurrent hybrid | **Hybrid Foundation (new)** | Apollo Build (existing, experienced 7 d/w) | 12w | 4 vs 7 | Gym + run vs full concurrent kit |
| Race (HYROX-style) | **HYROX Foundation (later)** | — | 12w | 4–5 | Gym + run; stations or substitutes |
| Physique / relative strength | — | Spartan (complete or withhold) | ≥8w if sold | 4–6 | Gym |

**Do not** launch a running-only app. Hybrid Foundation must include
strength + running + at least one mixed-modal or conditioning session
type the execution path already captures.

### Recommendations (subject to founder decisions)

1. **Hybrid Foundation — first new family.** 12 weeks, 4 sessions/week,
   beginner–intermediate, gym or limited gym + run surface. This is the
   programme that makes beta useful. It does not exist in the repo.
2. **Apollo Build v2 — include as experienced concurrent hybrid**, not
   as the default beginner card. It is the only fully encoded 12-week
   hybrid. It is 7 days/week and founder-dogfood positioned. It needs a
   **launch-quality pass** (metadata honesty, prescription normalisation,
   assessment declaration) before it is sold as a product SKU.
3. **Spartan v3 — do not treat the current 1-week package as a launch
   family.** Either author a complete physique block or keep it
   founder-only and stop implying multi-week duration in athlete copy.
4. **HYROX Base and Elite — not launch programmes.** There is no
   authored source. Recommend **one** later HYROX Foundation family after
   Hybrid Foundation passes the gate — not two race SKUs at once.
5. Strength-for-runners, endurance-emphasis, and standalone mobility
   remain **horizon** families. Embed recovery inside Hybrid Foundation.

### Build Your Own later

Launch families become the **approved component library**. BYO may later
assemble sessions the quality gate has already seen. This milestone must
not start a generator.

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

**Missing tooling (recommend only what the first library needs):**

- a documented founder checklist (this gate)
- a local compile + hash command already implied by the package tests
- **not** a coach studio, catalogue CMS, or BYO builder

Trusted import deployment verification is a later operational task, not
this audit.

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

If later authorised, implementation may:

- author Hybrid Foundation (and optionally an Apollo quality pass)
- populate truthful catalogue metadata on the pinned version
- use existing import / publish / approve / replace RPCs
- add tests for the new family’s compile/hash and discovery facts

Implementation must **not**:

- manufacture Plan Package exercise IDs
- publish without the quality gate
- replace enrolled athletes onto a new default
- start HYROX station identity work as a silent Phase 3 reopen
- start BYO, adaptation engine, payments, or beta recruitment

---

## 12. Acceptance gates

Architecture is accepted when the founder records decisions in §13 of
the audit and sets
`LAUNCH_PROGRAMME_LIBRARY=ARCHITECTURE_APPROVED` in a later docs
task.

The **library** is not complete until at least Hybrid Foundation is
quality-gated and published, and Apollo (if included) has an honest
product pass.

The **Cohort product** remains not launch-ready.

---

## 13. Deferred work

- 8–12 family catalogue
- HYROX Base / Elite / Intermediate / sub-60
- Spartan multi-week completion (unless separately chosen)
- catalogue filters, imagery, family taxonomy
- wired emphasis / progression / recovery comparison rows
- parametric progression
- Exercise Knowledge / media in athlete UI
- adaptation, matching, BYO, coach authoring, B2B
- payments, wearables, Android, offline queue, blue brand
- hosted publication of any new version
