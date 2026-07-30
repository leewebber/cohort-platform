# Plan Assessments Vision

**Status:** Vision / architecture planning only — **not implemented** in Phase 6 Sprint 3  
**Constraint:** No assessment UI, no production assessment engine, no fabricated benchmarks in this sprint.

---

## Concept

Each PlanDefinition (or Plan category) may define a relevant **assessment framework**. Assessments feed capability evidence and Progress — they are not a fifth navigation destination.

---

## Example frameworks (illustrative only — do not hardcode into production models yet)

### HYROX-oriented
- 5 km · threshold pace · 2 km row · SkiErg · wall balls · burpee broad jumps · loaded carries · grip / pulling strength

### Tactical-oriented
- Loaded running / marching · 2.4 km / relevant run · pull-ups / weighted pull-ups · lower-body strength · loaded carry · work capacity · swimming where applicable

### Longevity-oriented
- Aerobic capacity · grip strength · balance · gait / walking speed · chair stand · mobility · body composition where available

---

## Candidate domain concepts

| Concept | Role |
|---------|------|
| `AssessmentDefinition` | Named test protocol for a plan category |
| `AssessmentAssignment` | When the athlete should take / retake it |
| `AssessmentResult` | Typed outcome of one attempt |
| `MetricDefinition` | Stable metric id + units |
| `BenchmarkBand` | Age / sex / experience bands (evidence-backed only) |
| `RetestPolicy` | Cadence and eligibility for retest |

---

## Design requirements (future)

- Category-specific metrics per Plan family
- Age / sex / experience benchmark support without inventing norms
- Objective vs estimated metrics (transparent evidence state)
- Manual entry vs wearable import (import is out of scope until integrations sprint)
- Plan-entry assessment and scheduled reassessment
- Mapping into capability radar dimensions
- Avoid excessive test burden (few high-signal assessments)
- **No fabricated benchmark data**

---

## Product constitution fit

Assessments answer Progress (*Am I improving?*) with evidence — not Home clutter, not a new bottom-nav item.
