# Athlete Programme Discovery and Decision v1

**Status:** Binding Sprint 1 contract. Implementation authorised locally.
**Milestone:**
[`Complete_Athlete_Experience_v1.md`](./Complete_Athlete_Experience_v1.md)
**Audit:**
[`../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](../checkpoints/COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md)
**Base:** `origin/main` `3d2213940ae2d6f066fafc30dbd48f71fed2bf14`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=AUDITED_AWAITING_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This contract binds the production athlete journey. It is not a licence to
push, contact Field Manual, or start Sprint 2/3.

---

## 1. Journey

```text
Programmes
  → discover catalogue programmes
  → inspect authored programme detail
  → select exactly two candidates for comparison
  → compare aligned authored facts
  → inspect chosen programme
  → explicit enrolment decision
```

Production entry: `lib/main.dart` → `AuthGate` → `AthleteAppShell` →
Programmes (`AthleteProgrammeScreen` → `AthleteProgrammeSelectionScreen`).

---

## 2. Mutation authority

The only enrolment mutation is the existing RPC:

`enrol_athlete_in_catalogue_programme_version`

Sprint 1 must not add another enrolment, assignment, pin, or programme-
selection authority. `replace_active` is **not** a Sprint 1 product path.
The athlete selection controller must not pass `replaceActive: true` and
must refuse enrolment when an active assignment already exists (except
idempotent already-enrolled on the same version, without RPC).

Identity is `programme_versions.id`. Display names are never identity.
Catalogue-default changes must not move a pinned assignment.

---

## 3. Authored facts

Athlete UI may present only fields already on the published catalogue
entry (or assignment pin for current-programme status):

| Athlete label | Source | If missing |
|---------------|--------|------------|
| Title | `name` | Neutral “Programme” |
| Goal | `primaryGoal` | Omit from hero; glance/review use Not specified |
| Intended level | `difficulty` | Not specified in glance/review |
| Duration | `durationWeeks` | Not specified in glance/review |
| Sessions per week | `sessionsPerWeek` | Not specified in glance/review |
| Equipment | `equipmentRequirements` | Not specified in glance |
| Summary | `description` | Omit when absent |
| Catalogue status | published + approved + not archived | Honest unavailable |
| Current programme | assignment `programmeVersionId` equals entry `versionId` | — |

Do not invent training emphasis, session formats, progression, or rest
structure from names or session contents. Omit an optional section when
every field in it is unauthored. In comparison, hide a row when both
programmes lack that value. If only one lacks it, show **Not specified**.
Never present absence as a programme feature.

Never show internal IDs, hashes, lineage codes, graph terms, publisher
mechanics, or compiler language.

---

## 4. Enrolment

**No active assignment:** inspect, compare, review, confirm. Confirmation
names the exact programme and states that it becomes the current
programme. No mutation before confirm. No double submit. No silent
version fallback.

**Active assignment:** inspect and compare only. Current programme is
labelled. Other programmes show:

`Programme switching is not available here yet.`

No disabled unexplained Enrol button, dead CTA, or hidden switch.

---

## 5. Copy

Production journey must not contain “testing access”, “not a purchase”,
or implied payment, subscription, permanence, coach selection, matching,
or AI recommendation. Internal fixtures may be marked internal.

---

## 6. Explicit non-goals

Replacement, IANA timezone, pin-honesty redesign, programme-complete
Home, Progress/History corrections, coach-shell routing (unless this
route newly exposes it), library authorship, matching, adaptation,
payments, WOD Timer, Performance Portfolio, offline completion,
wearables, Android, blue brand, schema change.
