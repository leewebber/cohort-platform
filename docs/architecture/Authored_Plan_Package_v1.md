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

Raw YAML text is not canonical programme meaning. Hash is **not** persisted in
Sprint 1.1.

## Module

`lib/features/authored_plan_package/`
