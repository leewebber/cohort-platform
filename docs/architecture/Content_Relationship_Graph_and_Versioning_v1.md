# Content Relationship Graph and Versioning v1

**Status:** Binding. Sprint 1 local domain approved. Sprint 2 local persistence
implemented, **not applied to Field Manual**.
**Baseline:** `origin/main` `c50530db195bf4ed57393ebb66e0e404bfacec26`  
**Does not rewrite:** [`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md), Plan Package v1, Phase 1 athlete runtime.

M9 is an architecture and content-platform milestone. It is not a founder
phone-build milestone. Apollo production dogfood, Lee’s assignment, and
published Apollo programme versions stay unchanged.

## Why this exists

Cohort must support a growing first-party catalogue, reusable authored
sessions, “used by” impact, immutable published programme versions, athletes
pinned to the version they enrolled in, new athletes receiving the intended
latest published version, future plan assembly from approved authored content,
and future external publishers — with acquisition-grade lineage and audit.

M9 does **not** build: bespoke-plan questionnaires, automatic generation,
public coach UI, coach-client management, payments, wearables, exercise video,
adaptation automation, public catalogue launch, or social features.

## Existing production authorities (do not rename yet)

| Concept | Production identity | Notes |
|---------|---------------------|--------|
| Stable programme | `programme_lineages.id` / `code` | Human code ≠ PK |
| Programme version | `programme_versions.id` | `UNIQUE (lineage_id, version_number)` |
| Session lineage | `session_lineages.id` | M9.1 |
| Session revision | `performance_protocols.protocol_id` | Programme slots pin this TEXT, not lineage+revision |
| Exercise | `exercises_v2.exercise_id` (`EX-*`) | Plan Package v1 has **no** exercise IDs |
| Assignment pin | `programme_assignments.programme_version_id` | Enrolment never means “latest” |
| Package integrity | `programme_versions.package_content_hash` | SHA-256 of Plan Package v1 canonical JSON |
| Session templates | `performance_protocols.content_kind='session_template'` | `TMP-*` forbidden in live slots |

Competing names that **must not be silently merged**: session template vs
programme session; programme ID vs programme-version ID; protocol ID vs
training session ID; exercise name vs `EX-*`; block definition vs execution
block; source package vs materialised assignment snapshot.

## 1. Content node types (minimum useful graph)

| Node | Stable identity | Version identity |
|------|-----------------|------------------|
| Exercise | `EX-*` | No exercise-row versioning in Sprint 1 |
| Session template | session lineage UUID | Session revision / `protocol_id` |
| Programme | lineage UUID / code | `programme_versions.id` |
| Programme placement | slot UUID | Exists only inside one programme version |
| Authored block | block UUID | Exists only inside one session revision |
| Equipment requirement | token on version | Copied into published snapshot |
| Capability/domain tag | token | Copied into published snapshot |
| Publisher | namespace id | Not versioned |

No extra node types for theoretical completeness.

## 2–3. Stable vs version identity

Stable identity answers “what conceptual content is this?”  
Version identity answers “which immutable published definition is this?”

Example: Apollo Strength A is a stable session template; r1 and r2 are
immutable revisions. Apollo 12 Week is a stable programme; v1 and v2 are
immutable programme versions. An assignment references **one** programme
version.

## 4. Relationship types

See [`Content_Relationship_Type_Registry_v1.md`](./Content_Relationship_Type_Registry_v1.md).
Foreign keys are IDs, never display names.

## 5. Ownership and namespace

`library_scope` / `owner_type` / `owner_id` / `organisation_id` already exist
on `programme_versions`. M9 treats publisher namespace as the isolation
boundary: first-party `cohort_global` vs external coach/org. No external
author may reference or mutate another namespace’s private content.

## 6–7. Lifecycle and published immutability

States: `draft` → `published` → `retired`. Catalogue visibility is a **separate
flag** (`approved_for_global` / catalogue default) and is not a lifecycle.

Once published:

- compiled canonical content, ordered placements, exercise/session references,
  and package/graph hashes are immutable
- existing assignments stay pinned
- active occurrences are not silently regenerated
- there is **no** “edit published programme in place” escape hatch

To change content: clone draft → edit → validate → diff → publish new version →
choose new-enrolment default → leave existing assignments unchanged.

Emergency safety corrections still create an auditable replacement unless a
later metadata-only contract is separately approved.

## 8–9. Replacement, retirement, deletion

Catalogue replacement already exists as
`replace_approved_cohort_global_programme_version` (archives retiring, approves
replacement, does not rewrite assignments). Retirement hides a version from
new enrolment while remaining readable for pinned assignments. Hard delete of
published, referenced content is forbidden.

## 10–11. Assignment pinning and materialisation

Enrolment and materialisation already pin `programme_version_id` and snapshot
`materialised_package_content_hash`. “Latest” is resolved only at
catalogue-selection / enrolment time. Execution loaders must continue to use
the assignment’s exact version. M9 adds a local invariant service proving this
and a later additive DB check if hosted schema is approved.

**Do not repin Lee’s Apollo assignment.**

## 12–13. Impact analysis and diff

Used-by is derived from authored relationships (exercise → block → session
revision → placement → programme version → assignments). It must not scan
performance result rows. Diffs are structural, not display-string diffs.
Classes: breaking execution, material training, metadata/presentation.

## 14. Package integrity / compiler

**Decision:** Plan Package schema **v1 is frozen**. M9 adds Content Graph
manifest format **v1** as a **derived** integrity/read-model. It must be bound
to the exact source package hash plus, for v1 content, a separately versioned
supplemental relationship source. Apollo’s published Plan Package hash must not
change. See [`M9_Manifest_Authority_and_Binding_v1.md`](./M9_Manifest_Authority_and_Binding_v1.md).

## 15. Existing-content migration

Backfill is **deterministic and reviewable**, not applied to Field Manual in
Sprint 1. Apollo lineage/version, `protocol_id` slots, and `EX-*` block links
are recoverable. Name-only or missing FKs are marked `unresolved/legacy`.
Do not fabricate authorship.

## 16–17. Future boundaries

Plan-builder and external-author UIs are out of scope. M9 only provides
stable session-template versions, tags, equipment, duration/load metadata,
source lineage, namespaces, and publication authorization hooks.

## 18–19. Authorization, isolation, read models

Mutations: authenticated, authorized, idempotent where applicable, audited,
transactional. Sprint 1 implementations are local-repository only — no hosted
mutation path. Used-by queries are indexed by source/target IDs.

## Sprint 1 delivery

- Binding docs (this file + audit, schema proposal, registry, lifecycle,
  migration plan, compiler decision, pinning proof, exercise-identity review,
  future boundaries, checkpoint)
- Local `lib/domain/content_graph/` services and fixtures
- Developer explorer `lib/main_m9_content_graph_preview.dart` (not production)
- Tests for identity, used-by, compiler hash, pinning, diff, auth

Hosted migrations, Field Manual contact, phone install, and M10 wait for
founder architectural approval.
