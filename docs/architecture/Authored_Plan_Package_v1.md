# Authored Plan Package v1 — Sprint 1.1 foundation

**Status:** Binding for compiler foundation  
**Scope:** Parse → validate → canonicalise → SHA-256 (no persistence)

---

## Authority

Production programme development uses:

- `ProgrammeLineage` — stable programme identity
- Immutable `ProgrammeVersion` — versioned programme snapshot
- Session Revisions (`protocol_id` + `session_lineage_id` + `revision_number`)

The Authored Plan Package is the interchange + content-hash boundary for
expert-authored programmes. It does **not** generate training.

## Explicit non-authority (legacy quarantine)

| Pathway | Status |
|---------|--------|
| `PlanDefinition` + Plan Library MVP | Legacy / prototype — philosophy-only; Coach Brain generates workouts |
| Coach Brain generative daily planning | Not authoritative Plan Package architecture |
| `ProgrammeLineage` / `ProgrammeVersion` | Production direction |

New Plan Package code under `lib/features/authored_plan_package/` **must not**
import or depend on `lib/features/plans/` generative models or Coach Brain
workout generation.

Existing legacy Plan Library behaviour remains temporarily supported pending a
separately approved migration/removal sprint. Do not delete or disable it in
this foundation sprint.

## Compiler pipeline

```
YAML input
  → parsed untrusted data (strict field allowlists)
  → semantic validation
  → typed PlanPackageManifest
  → normalised canonical JSON (UTF-8)
  → SHA-256 content hash (lowercase hex)
```

Raw YAML text is not canonical programme meaning.

## Import + publication (Sprint 1.2)

```
Successful compile result
  → side-effect-free import preview
  → service-role-only SECURITY DEFINER import RPC
  → hidden Cohort Global draft (never auto-publish)
  → explicit publish RPC (approved_for_global stays false)
  → explicit catalogue-approval RPC (separate gate)
```

Import execution is granted only to `service_role`. Flutter/client code must
never embed service-role credentials. Ordinary authenticated users cannot read
Cohort Global drafts or published-but-unapproved globals.

## Athlete catalogue enrolment (Sprint 1.3)

After catalogue approval, athletes enrol via the Sprint 1.3 contract documented in
`docs/architecture/Athlete_Catalogue_Enrolment_v1.md`. Enrolment pins an exact
`programme_version_id` (non-commercial test / closed-beta access). It does not
implement payment, subscription, or athlete-plan materialisation.

## Module

`lib/features/authored_plan_package/`
