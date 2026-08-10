# Authored Plan Package v1 — Sprint 1.1 foundation

**Status:** Binding for compiler and trusted import boundary
**Scope:** Parse → validate → canonicalise → SHA-256 → trusted draft import

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

## Trusted founder import runtime (Phase 3.1 first consumer)

The compiler has one pure-Dart implementation in
`packages/cohort_plan_package/`. Flutter preserves its existing import paths by
re-exporting that package; there is no second compiler.

The platform-neutral Shelf runtime in `server/trusted_plan_package_import/`
provides exactly:

```text
POST /v1/founder/plan-packages/import
```

It verifies the bearer token through Supabase Auth, applies Cohort's established
server-side founder email allowlist to the verified email, compiles bounded raw
YAML, derives provenance from the verified user ID, and calls only
`public.import_authored_plan_package(JSONB)` with server-held service-role
authority. Invalid packages make no RPC call. Success is accepted only as a
draft with `approved_for_global=false`; publication, catalogue approval,
athlete assignment and athlete-plan materialisation remain separate and are not
performed by this endpoint.

Configuration is injected through `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY` and `FOUNDER_EMAIL_ALLOWLIST`, with optional bind,
port and request-size values. Missing or malformed required configuration fails
closed. No values or environment file are committed.

The RPC, grants, RLS and package schema v1 are unchanged. Schema v1 still has no
exercise identities: the first consumer imports only its supported protocol,
session-lineage, revision, schedule, adaptation, invariant, assessment,
evidence and comparison contracts. The legacy founder importer is unchanged.

This runtime was implemented and tested locally without hosted contact or
deployment. Deployment readiness and isolated deployment require a separate
founder decision.

## Athlete catalogue enrolment (Sprint 1.3)

After catalogue approval, athletes enrol via the Sprint 1.3 contract documented in
`docs/architecture/Athlete_Catalogue_Enrolment_v1.md`. Enrolment pins an exact
`programme_version_id` (non-commercial test / closed-beta access). It does not
implement payment, subscription, or athlete-plan materialisation.

## Module

- shared compiler and pure import contracts: `packages/cohort_plan_package/`
- Flutter compatibility exports and client-side preview adapters:
  `lib/features/authored_plan_package/`
- trusted founder import runtime: `server/trusted_plan_package_import/`
