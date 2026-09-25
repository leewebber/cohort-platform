# Programme Studio Stage 1 — implementation contract

**Status:** Local implementation contract for authorised Sprint A.
**Parent:** [`Programme_Studio_v1.md`](./Programme_Studio_v1.md)
**Strategy:** [`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Base:** `origin/main` `3df1442ce035df5d45370cd0a528cc18f14bdfe3`

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=APPROVED_NOT_STARTED
PROGRAMME_STUDIO_STAGE_1=APPROVED_NOT_STARTED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This contract is local implementation authority only. It does not reopen
approved strategy, authorise programme content, or licence push, hosted
access, Sprint B–D, pace formulas, metrics selection, Garmin work, or
catalogue publication.

---

## Canonical inputs

Read-only, committed artifacts only:

| Fact | Authority |
|------|-----------|
| Programme / version identity, metadata, duration, schedule, week/day/session order | Plan Package v1 YAML via `PlanPackageCompiler` |
| Package validation, canonical JSON, SHA-256 | Same compiler (parse → validate → canonicalise) |
| Spartan session bodies | Founder programme YAML via `FounderProgrammeYamlParser` |
| Apollo session bodies | Committed executable-protocol SQL `INSERT` artifacts for `performance_protocols`, `session_blocks`, and `session_block_exercises` |
| Publication / version UUID / package-hash evidence | Committed M9 publication JSON (not a live hosted SELECT) |

SQL seeds, discovery previews, tests, and documentation examples are
**not** canonical programmes. Later Apollo correction migrations that
cannot be replayed without a database are **findings**, not silent
rewrites.

## Derived review model

One deterministic projector maps the inputs above into an in-memory
review catalog. If a generated snapshot is required for preview, it is:

- ordered stably
- identity-preserving (lineage, version, hash)
- source-reporting
- fail-closed on malformed package YAML
- marked **derived / non-authoritative**
- excluded from publication, import, and compile inputs

Identical authoritative input must produce byte-for-byte equivalent
canonical review JSON.

## UI boundary

Internal, desktop-first, read-only Programme Studio. Inventory,
overview, week/day/session inspection, validation/identity, athlete
metadata preview, and quality/readiness. Version comparison only when
two genuine authoritative versions of the **same** lineage exist.

## Production isolation

Not reachable from athlete or coach navigation. Not imported by
`lib/main.dart` (directly or transitively). Dedicated preview entry
`lib/main_programme_studio_preview.dart` only. No hosted auth, SELECT,
RPC, or mutation.

## Allowed fixtures

Preview/test fixtures may cover malformed source, validation failure,
unsupported prescription, empty inventory, missing protocol, narrow
viewport, and large text. They must be labelled and excluded from the
default real-programme inventory unless an explicit developer filter is
on.

## Mutation prohibitions

No Save, Publish, Approve, Replace default, enrol, materialise, or
database controls. No edits to canonical YAML, SQL, or M9 artifacts. No
invented sessions, weeks, pace zones, or metrics.

## Acceptance gates

Deterministic projection; honest classification; fixtures excluded by
default; no silent block omission; compiler success ≠ launch approved;
running/pace/metrics/device shown missing/not implemented; production
entry scan; focused + compiler + publication + safety gate + full
`flutter test`. Visual founder review is required before Stage 1 is
complete.

## Stop conditions

Stop before editing a real programme source, inventing prescriptions,
changing package schema, adding SQL/migrations, contacting hosted
systems, creating a second programme authority, implementing pace
formulas, selecting metrics, or implementing Garmin/provider behaviour.
