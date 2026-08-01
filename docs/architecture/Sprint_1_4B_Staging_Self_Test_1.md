# Sprint 1.4B Staging Self-Test 1

**Status:** Staging-verified on Cohort Staging  
**Branch:** `phase1-sprint1-4b-first-session-integration`  
**Project:** Cohort Staging (`tsbadngz…`, eu-west-2)

---

## Release scope

- No Sprint 1.4B database migration
- Local/remote migrations matched through `20260801150000`
- Gate L unnecessary
- Application run method: temporary staging `.env` (URL + anon key) +
  `lib/main_s14b_staging_verify.dart` via
  `CONFIRM_COHORT_STAGING=1 ./tool/staging/run_s14b_flutter_staging_verify.sh`
- No persistent staging app deploy; Chrome harness against staging anon API

---

## Fixture note

Athlete A materialisation authority was intact (exact version, hash, cursor
week 1 / day_1 / slot 1). The referenced bank protocol `PROT-S13-STAGING-1`
existed as a published shell but initially had **zero** `protocol_steps` /
`session_blocks`, so deterministic preparation fail-closed.

An additive staging-only seed inserted one synthetic `protocol_steps` row for
`PROT-S13-STAGING-1` (title: Staging Authored Movement). Athlete assignment /
version / hash / cursor were not changed.

---

## Harness

```bash
CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run
CONFIRM_COHORT_STAGING=1 ./tool/staging/run_s14b_flutter_staging_verify.sh
```

Requires `/tmp/s13b_dotenv_staging`, `/tmp/s13b_dotenv_prod_backup`,
`/tmp/s13b_athlete_creds.json`. Restores `.env` and secrets stub on exit.
Never commit real values into `lib/s14b_staging_secrets.g.dart`.

---

## Self-Test 1 outcome

Hosted Flutter assertions: **60 / 60 passed** (`ok: true`).

Covered: sign-in, persisted reconciliation, exact version/hash, cursor →
programme-shaped key, SessionExecutionLoader prepare, provenance, idempotent
restore, deterministic reconstruction, Athlete B isolation, Home prepared card,
non-advancement, no Coach Brain / commerce language.

Fingerprint (sanitised): `72dd74bbc8416dd4`  
Key form: `prog:{assignmentId}@{versionId}:w1:day_1:s1:PROT-S13-STAGING-1`

Staging read-only security probes: anon assignment empty/denied; anon
materialise RPC HTTP 401; completion_count 0; cursor/hash intact; protect fn
present. Gate K `guc_bypass_blocked` remains denied/denied on local DB gate.

Completion and cursor advancement remain deferred.
