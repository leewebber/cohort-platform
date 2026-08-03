# Sprint 1.7 Athlete D Staging Harness

**Status:** B4a local harness implemented. Hosted Athlete D creation and journey
execution remain separately authorised (B4b).

**Base:** `fe7576d` Phase 1 closeout tip  
**Branch (local):** `codex/b4a-staging-harness`

## Purpose

Provide a fail-closed, repository-supported path to:

1. create one isolated staging identity **Athlete D**;
2. enrol/materialise against immutable catalogue fixture `PROG-S13-ELIG`;
3. launch Flutter verification via private `--dart-define-from-file` config;
4. report Phase 1.6 / Sprint 1.7 journeys A–K as `PASS` / `FAIL` / `BLOCKED` /
   `NOT RUN`.

## What B4a does **not** do

- create Athlete D on staging;
- contact staging or production databases;
- swap shared `.env`;
- overwrite tracked `lib/*_staging_secrets.g.dart` stubs;
- apply migrations;
- delete Athlete C or any existing athlete.

## Prerequisites for later B4b

1. Staging identity: Cohort Staging (`tsbadngz…`, `eu-west-2`, `ACTIVE_HEALTHY`).
2. Migration tip `20260803180000` with zero pending.
3. Operator-local API env (never committed), typically `/tmp/s13b_api.env`,
   containing staging URL, anon key, and service role for Admin Auth setup only.
4. Work only from a staging-linked operations worktree for hosted steps.

## Commands

### Dry-run creator (no hosted write)

```bash
CONFIRM_COHORT_STAGING=1 \
  ./tool/staging/create_s17_athlete_d_fixture.sh --dry-run
```

For offline local tests only:

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_PROJECTS_JSON_FILE=/path/to/projects_fixture.json \
  ./tool/staging/create_s17_athlete_d_fixture.sh --dry-run
```

### Creator (hosted — B4b only)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_API_ENV=/tmp/s13b_api.env \
  ./tool/staging/create_s17_athlete_d_fixture.sh
```

Writes a private directory under `/tmp/cohort_s17_athlete_d.*` with mode `700`
and credential/config files mode `600`:

- `athlete_d_credentials.json`
- `flutter_dart_defines.json`
- `redacted_manifest.json`
- `creation_state.json`

### Runner dry-run (no Flutter launch)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=/private/tmp/.../flutter_dart_defines.json \
  ./tool/staging/run_s17_flutter_staging_verify.sh --dry-run
```

### Runner (hosted Flutter — B4b only)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=/private/tmp/.../flutter_dart_defines.json \
  ./tool/staging/run_s17_flutter_staging_verify.sh
```

Only the file path is passed to Flutter. No service-role key is included in
dart-defines.

## Redacted expected dry-run output

```text
STAGING_CONFIRMED name=Cohort Staging ref_prefix=tsbadngz… region=eu-west-2 status=ACTIVE_HEALTHY
ATHLETE_D_PLAN_OK run_marker=s17_stage_…
PRIVATE_DIR=/private/tmp/cohort_s17_athlete_d.…
PROGRAMME=PROG-S13-ELIG
DRY_RUN=1
DRY_RUN_OK: staging identity confirmed; Athlete D not created; no hosted write.
```

## Partial creation

If a hosted create stage fails after Auth user creation, the private
`creation_state.json` records a partial-state classification. No automatic
cleanup or deletion is performed. Retain the private directory for founder
review / separately authorised cleanup.

## Journey matrix

| Code | Journey |
|------|---------|
| A | Identity and isolation |
| B | Catalogue, assignment, prepared execution |
| C | Previous-performance reference |
| D | Phase 1.6 adaptation |
| E | Initial schedule projection |
| F | Move + invalid Move |
| G | Swap + invalid Swap |
| H | Push + invalid Push |
| I | Skip |
| J | Undo + horizon |
| K | Completion and advancement |

## Retention and cleanup

Retain until separately authorised:

- Athlete D private credential directory;
- redacted manifests / Flutter reports under `/tmp`;
- B3a logical backup;
- staging operations worktree.

Do not treat Athlete D data as production data. Do not delete Athlete C.

## Production rejection

Any project ref beginning `otnhhdxs`, project name `Cohort Field Manual`, or URL
containing that production marker is refused.
