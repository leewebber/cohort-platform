# M10 Sprint 1 handoff — publisher-scoped athlete membership

**Recorded:** 2026-09-19  
**Status:** Local Sprint 1 complete. **Paused for founder architectural and visual approval.**  
**Branch:** `feat/m10-sprint-1`  
**Base:** `origin/main` `78076a1a36e950e415b41f3af46d0c4ff9f03b2f`

```text
M10_STARTED=true
M10_SPRINT_1_LOCAL=true
M10_SPRINT_2_STARTED=false
HOSTED_MUTATIONS=0
PHONE_BUILD_REQUIRED=false
PLAN_PACKAGE_V1_CHANGED=false
```

**Do not:** push, apply hosted migrations, mutate Field Manual, publish
manifests, repin assignments, rebuild the phone, or start Sprint 2.

Binding:
[`../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md`](../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md).

---

## Confirmed M10 definition

**Exact name:** M10 Athlete/Coach Management and Isolation

**Sources (authority order):**

1. M9 closeout — next milestone is M10; M10 had not started
2. Delivery roadmap — **M10 Athlete/Coach Management and Isolation**
3. AGENTS.md — “M10 isolation”
4. Architecture freeze 51 — “Coach and athlete management”
5. M9 external-author boundary — publisher namespaces; no coach accounts yet

**Product capability:** A publisher principal can see only the athletes
belonging to their namespace, together with the athlete’s **pinned** programme
version and the M9 graph facts for that pin. They cannot see another
publisher’s athletes or rewrite a pin / published manifest.

**First persona:** founder / internal operator (preview). Publisher/coach is
the intended later consumer. Athletes get no new production UI.

**Sprint 1 complete means:** local domain + tests + internal preview proving
ready / empty / unauthorised / invalid / stale / pin-immutable behaviour.
No hosted schema. No phone build.

---

## Source-of-truth hierarchy

Authoritative: programmes, versions, pins, `EX-*`, M9 published manifests.  
M10 authoritative (local): publisher-scoped membership.  
Derived: roster, used-by count, composite snapshot.

Historical `07 Documentation/60–63` “M10.1–4” programme intelligence is
**already implemented** and is not this milestone. Catalogue/enrolment is a
separate earlier roadmap item (primitives exist).

---

## Implementation audit (relevant)

| Capability | Class |
|------------|--------|
| M9 `ContentPublisher` / principals / graph / pins | 1 canonical reusable |
| M9 used-by / diff / publication artifacts | 1 canonical reusable |
| V2.0 `CoachAthleteService` + invites | 2 correct but incomplete (profile coach_id, no publisher) |
| Coach Studio intelligence UI | 1 for impact/compare; not M10 isolation |
| Join-coach athlete Home card | 2 existing product; **out of Sprint 1** |
| Founder “Athletes” workspace | 2 client UX only |
| Publisher-scoped membership | 5 missing → added locally |
| Hosted membership table | 5 missing; **not this sprint** |

Duplicate decision risk: do not let `CoachAthleteService` and M10 both assign
programmes. Sprint 1 does not assign.

Display-name matching: refused (`display_name_is_not_identity`).  
Mutable published content: none.  
Build 7: no production import of M10 fixtures; capability RPC unchanged.

---

## Architecture decisions

See the contract decision requirements. Defaults used:

- Reuse M9 graph/pins; do not replace V2.0 tables
- Domain-owned isolation; no Sprint 1 hosted persistence
- No new schema
- Consume M9 compile/used-by by id
- Pins immutable (`assignmentPinned`)
- Tenant key is `publisher_id`, not coach display name
- Athlete UI out of scope
- Plan Package v1 unchanged

---

## First vertical slice

`PublisherAthleteIsolationService` + in-memory store + fixtures.

Preview:

```bash
flutter run -d chrome --web-port 4190 -t lib/main_m10_isolation_preview.dart
```

http://localhost:4190 — internal preview, fixtures only.

---

## Later sprints (proposed)

2. Bind V2.0 invite accept to a publisher principal (proposal + local tests)
3. Additive hosted membership table + RLS (founder approval)
4. Internal/founder roster UI over hosted rows
5. Audited repin (separate authority)

---

## Hosted / phone

Neither required for Sprint 1.

---

## Untouched

Field Manual, published Apollo v2 / Spartan v3 manifests, assignments, repo
`.env`, founder phone build 7, Plan Package v1, M9 migrations.
