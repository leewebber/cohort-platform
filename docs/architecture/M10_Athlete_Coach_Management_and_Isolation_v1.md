# M10 Athlete/Coach Management and Isolation v1

**Status:** Binding Sprint 1 contract  
**Recorded:** 2026-09-19  
**Milestone:** M10 Athlete/Coach Management and Isolation  
**Does not start:** Sprint 2, hosted apply, phone release, Plan Package v2

```text
M10_MILESTONE=Athlete/Coach Management and Isolation
M10_SPRINT_1=publisher-scoped athlete membership isolation
PLAN_PACKAGE_V1_CHANGED=false
HOSTED_MIGRATION_REQUIRED=false
PHONE_BUILD_REQUIRED=false
ATHLETE_PRODUCTION_UI_IN_SCOPE=false
```

Binding parents:
[`../checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](../checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md),
[`../planning/Delivery_Roadmap_v1.md`](../planning/Delivery_Roadmap_v1.md),
[`Content_Relationship_Graph_and_Versioning_v1.md`](./Content_Relationship_Graph_and_Versioning_v1.md),
[`M9_External_Author_Boundary_v1.md`](./M9_External_Author_Boundary_v1.md),
[`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md).

This document does not rewrite the Phase 1 architecture freeze.

---

## 1. Problem statement

M9 gave Cohort an immutable, publisher-namespaced content graph and pinned
programme assignments. Membership of athletes to a publisher is still a
profile-to-profile link (`coach_athlete_relationships.coach_id` =
`profiles.id`) with one active coach per athlete and no M9 publisher key.

Without publisher-scoped membership, Cohort cannot safely add a second
publisher, cannot keep roster visibility inside a namespace, and cannot
consume M9 used-by / pin facts as tenant context. M10 exists to add that
isolation boundary — not to invent a generic CMS, not to reopen programme
intelligence already delivered as M9 + V2.0 impact services, and not to
change athlete execution.

---

## 2. Actors and authorization

| Actor | Identity | Sprint 1 rights |
|-------|----------|-----------------|
| Publisher principal | `principal_id` bound to one `publisher_id` / namespace | Read own roster; activate membership in own namespace when write-capable |
| First-party operator | principal on `cohort_global` | Same rules; no global bypass |
| Coach profile (legacy V2.0) | `profiles.id` + `is_coach` | **Out of Sprint 1 writes.** Existing `CoachAthleteService` remains the pre-M10 path |
| Assigned athlete | `athlete_id` | No new production UI. May appear as a roster subject only |
| Anonymous / reader | none | Deny |
| Other publisher | different `publisher_id` | Deny all foreign memberships, pins, and graph context |

Fail closed: missing capability, missing publisher, missing principal, or
mismatched publisher on the actor **unauthorised**. Empty namespace is
**empty**, not an error.

---

## 3. Authoritative vs derived

**Authoritative (unchanged; M10 does not write these):**

- authored programmes / programme versions
- session revisions / protocols / authored blocks
- canonical `EX-*` identities
- programme placements
- Plan Package v1 bytes
- published content-graph manifests
- `programme_assignments.programme_version_id` pins

**Authoritative for M10 Sprint 1 (local domain only):**

- publisher-scoped athlete membership (`publisher_id` + `athlete_id` +
  `coach_principal_id`)

**Derived:**

- roster projection
- pin snapshot (assignment id + programme version id)
- M9 used-by / composite identity shown beside a pin
- impact counts (existing M9 / `ProgrammeVersionImpactService`; not
  reimplemented)

Display names are labels only. They are never identity, membership, or
relationship keys.

---

## 4. Identifiers

| Concept | ID shape | Notes |
|---------|----------|--------|
| Publisher | M9 `ContentPublisher.id` | Namespace is `cohort_global` / `coach.*`; not a display name |
| Principal | opaque principal id | Must match an active principal of that publisher |
| Athlete | opaque athlete id | Not email, not display name |
| Membership | `membership.{publisher_id}.{athlete_id}` | Deterministic; idempotent activate |
| Assignment | M9 `PinnedAssignment.id` | Read-only in M10 |
| Programme version | M9 / production version id | Read-only |
| Graph composite | M9 `composite_identity` | Compared exactly when declared |

Forbidden: matching athletes, coaches, publishers, or exercises by display
name, alias, or string similarity.

---

## 5. Lifecycle

```text
membership: absent → active → ended
invite (legacy V2.0): pending → accepted | revoked   [not Sprint 1]
assignment pin: created at enrolment → immutable through ordinary update
manifest: published → immutable
```

Sprint 1 commands never end a membership in production and never rewrite a
published version. `ended` exists so later sprints can retire a link without
deleting history.

---

## 6. Commands and queries

### Query `inspectRoster(actor)`

Returns typed status:

| Status | Meaning |
|--------|---------|
| `ready` | One or more active memberships in the actor’s publisher |
| `empty` | Authorised; zero active memberships |
| `unauthorised` | No capability, wrong publisher, or no principal |
| `unavailable` | Publisher missing / retired |
| `invalidInput` | Malformed ids |
| `staleManifest` | A membership declares a composite that does not match the compiled graph |

Each ready row may include pin + used-by facts from the M9 store. Missing pin
is allowed (athlete linked, not yet assigned).

### Command `activateMembership(actor, athleteId, …)`

Local-only. Idempotent on `(publisher_id, athlete_id, coach_principal_id)`
while `active`.

| Outcome | When |
|---------|------|
| `activated` | First insert |
| `already_active` | Exact triple already active |
| `unauthorised` | Capability / publisher mismatch |
| `conflict` | Athlete already active under a different publisher |
| `invalidInput` | Blank ids or name-key attempted |
| `staleManifest` | Declared composite ≠ compiled M9 graph |
| `assignmentPinned` | Caller asked to change an existing pin (forbidden) |

No hosted RPC in Sprint 1.

---

## 7. Versioning and immutability

- Published programme versions and manifests remain immutable.
- A training-meaning change still requires a **new** programme version (M9).
- M10 must not UPDATE `programme_assignments.programme_version_id`.
- Showing a later published version on a roster is informational; execution
  stays on the pin.
- Sprint 1 does not implement audited repin (M9 remaining work).

---

## 8. Audit and idempotency

Local command results are typed and deterministic. Repeat
`activateMembership` with the same ids returns `already_active` and the same
membership id. No silent create-another-row.

Hosted audit tables are a later sprint.

---

## 9. Capability gating

Sprint 1 uses an explicit local capability object:

- `athlete_coach_isolation_read`
- `athlete_coach_isolation_write`

Absent / false → fail closed. Hosted
`cohort_athlete_runtime_capabilities` **schema version 2 is unchanged**.
Build 7 must keep parsing unknown/missing keys as unavailable. Do not add
M10 flags to the hosted RPC in this sprint.

---

## 10. Security / RLS expectations

Future hosted RLS (not applied now) must:

- deny anonymous
- restrict membership rows to the caller’s publisher principal
- deny coaches a global roster
- keep assignment pin immutable
- keep published manifests immutable
- not grant graph impact by being a coach profile alone (M9 rule)

Sprint 1 proves the same rules in domain tests.

---

## 11. Performance

Roster inspect is an indexed membership scan plus pin/graph lookups by id.
Target: 200 active memberships + one published fixture graph compile in
well under one second on a developer machine. No N×N display-name scan.

---

## 12. Compatibility

**M9:** consume `ContentGraphStore` / `ContentGraphService` for publisher,
pin, used-by, and composite. Do not compile a second graph, do not infer
edges by name, do not publish manifests.

**Build 7:** no production athlete navigation, no new required payload on
Home / Train / completion, no capability-RPC change.

**Plan Package v1:** frozen. M10 does not require v2.

**V2.0 `CoachAthleteService`:** remains the existing invite/roster product
path. Sprint 1 does not delete it and does not route production Home through
the new domain.

---

## 13. Migration strategy

None hosted. Sprint 1 is in-memory + fixtures. A later sprint may propose
additive `publisher_athlete_memberships` keyed by `publisher_id`, without
rewriting `coach_athlete_relationships` in place.

---

## 14. Explicit non-goals (Sprint 1 and M10 product)

- Athlete-facing graph UI
- Production athlete Join-coach redesign
- Publisher authoring / impact UI (already exists as Coach Studio intelligence)
- Audited assignment repin
- Plan Package v2
- Organisations, billing, seats, SSO
- Email / QR / deep-link invites
- Multi-coach active membership (V2.0 one-active-coach remains until a later
  authorised change)
- Hosted reconstruction or new Field Manual rows
- Phone build 8
- Generic enterprise CMS

---

## 15. Decision log

| Decision | Alternatives | Evidence | Why | Reversal cost |
|----------|--------------|----------|-----|---------------|
| Reuse M9 publisher + pin + used-by | New parallel graph | M9 closeout; `ContentGraphService` | Avoid second content authority | Low if later wrap only |
| Do not replace V2.0 `CoachAthleteService` | Rewrite invites now | Doc 65 implemented; one-coach index | Isolation is the missing axis | Medium later if dual-write |
| Domain-owned, no Sprint 1 persistence | Hosted table now | No approved membership schema | Demonstrable without Field Manual | Add table later |
| No new migration | Additive SQL now | M9 remaining work; user forbid hosted apply | Fail-closed locally first | Proposal-only later |
| Consume M9 compile by version id | Re-bind Apollo SQL | Frozen artifacts | Exact composite compare | None |
| Pin immutable | Allow coach reassign in slice | M9 trigger + remaining “audited repin” | Execution meaning stays pinned | Separate command later |
| Tenant = `publisher_id` | Tenant = coach profile | M9 namespace; B2B2C | Second coach can share a publisher later | High if we key only on profile |
| Athlete UI out | Ship Join-coach v2 | Build 7; constitution | Isolation is not an athlete feature yet | UI later |
| Plan Package v1 unchanged | Start v2 | M9 compiler decision | M10 does not need package exercise IDs | Proposal only |

## 16. Later-version extension points

- Persist memberships with RLS
- Bind V2.0 invite accept to a publisher principal
- Org → many principals
- Audited repin using M9 impact
- B2B2C: first-party catalogue athlete vs publisher-roster athlete
- Coach UI over the isolated roster (founder/internal first)
