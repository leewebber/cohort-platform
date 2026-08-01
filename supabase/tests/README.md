# Sprint 1.2 local disposable database gate

Uncommitted test infrastructure. **Does not authorise staging or production.**

## Classification

| Kind | Location |
|------|----------|
| Live PostgreSQL behavioural proof | `sql/gates_c_to_i.sql` |
| True multi-session concurrency | `concurrency/gate_g.sh` (G1/G2 only) |
| Sequential duplicate validation | Gate E in `sql/gates_c_to_i.sql` (includes former G3) |
| Helper/setup | `sql/helpers.sql`, `lib/*`, `fixtures/*` |
| Baseline fidelity (separate) | `sql/baseline_fidelity.sql` → `sprint12_baseline_fidelity_results` |
| Orchestrator | `run_local_db_gate.sh` |
| Dart / static SQL contracts | existing `test/` (unchanged) |

Behavioural assertions are **custom SQL** (`sprint12_gate_results`), not pgTAP.
Baseline-fidelity assertions use a separate table and are not mixed into C–I totals.

Gate D reporting:
- **Setup/helper assertions** (e.g. `setup_seed_complete_import`) are labelled and are not counted as malformed-state completeness cases.
- **Substantive malformed-state cases** each prove pre-persisted counterexample + `partial_state_conflict` + post-conflict no-repair (frozen counts/identities; no recreate/restore/delete of the counterexample; single lineage/version).

## Prerequisites

- Docker Desktop running
- Supabase CLI (`supabase --version`)
- Repository on the Sprint 1.2 branch with production migrations unchanged
- No hosted credentials / no `--linked`
- No `SUPABASE_ACCESS_TOKEN` in the environment (local harness never consumes hosted auth tokens)

## Test-only baseline

- Fixture: `fixtures/local_test_baseline_prereq.sql`
- Derived from the authorised hosted **schema-only** dump
  (`SHA256 25be877b2acfaa69ee4b3db28a2e9a03419259a362ca143fa6f2c01c7f787d90`)
- **Never** placed under the repository’s production `supabase/migrations/`
- Copied only into an isolated temporary workdir created under `$TMPDIR`
- Temporary workdir also receives **copies** of real production migrations in order
- Unique `project_id` + ports; no copy of repository `.temp` / linked metadata
- Trap cleanup removes the workdir after the run
- Deliberate local accommodations (unique / programme_version FK / privileges) are
  documented in the fixture header — not claimed as hosted grant parity
- Orchestrator rejects `INSERT`/`COPY` in the baseline fixture file

## Target safety

Runners abort unless:

- Container resolves to the **exact** name `supabase_db_<disposable_project_id>` (no `s12g*` fuzzy match)
- Exact container is present exactly once; missing/ambiguous resolution fails before SQL
- No `--linked`
- No hosted/`supabase.co` URL
- No `SUPABASE_ACCESS_TOKEN`
- Loopback API URL for HTTP checks

Negative controls:

```bash
./supabase/tests/run_local_db_gate.sh guard-invalid
./supabase/tests/run_local_db_gate.sh url-invalid
./supabase/tests/run_local_db_gate.sh container-missing
./supabase/tests/run_local_db_gate.sh container-cross
./supabase/tests/run_local_db_gate.sh token-invalid
```

## Exact execution

```bash
# From repository root
chmod +x supabase/tests/run_local_db_gate.sh \
         supabase/tests/concurrency/gate_g.sh

# Full gate (starts disposable stack, runs C–I, G1/G2, negative controls, stops)
./supabase/tests/run_local_db_gate.sh full
```

Expected: process exits **non-zero** if any assertion fails (`sprint12_fail_if_any_failed`) or concurrency expectations fail.

Gate G negative control uses a **fresh unique lineage**, proves a real import+replay concurrent pair, then deliberately inverts one expected outcome and exits non-zero for that reason (not stale G1 state).

## Athlete catalogue enrolment (Sprint 1.3)

Installed by `20260801120000_athlete_catalogue_enrolment.sql`:

- Extends `programme_assignments` with `enrolment_source` (not a payment record)
- RPC `enrol_athlete_in_catalogue_programme_version` for authenticated athletes
- Temporary non-commercial authorisation seam for Self-Test / closed-beta
- Exact `programme_version_id` pin; draft/unapproved/private denied
- Gate J in `sql/gate_j_catalogue_enrolment.sql` (run after Gates C–I)

## Catalogue permission contract (Sprint 1.2)

Installed by `20260731120000_authored_plan_package_import.sql`:

- `authenticated`: `SELECT` on `programme_versions` and `programme_lineages` (Sprint 1.2)
- `anon` / `PUBLIC`: no catalogue `SELECT`
- RLS: published + `cohort_global` + `approved_for_global` (versions and lineage helper)
- Sprint 1.2 does not grant catalogue writes; pre-existing coach-authoring table
  privileges (if any) remain RLS-gated and are not blanket-revoked here
- Import / publish / approve RPCs: `service_role` `EXECUTE` only
- Package-internal tables: no direct client grants

Harness checks:

- Gate I privilege + RLS assertions under the permanent grant
- Anon Data API catalogue negative (401/403, no rows)
- Authenticated Data API catalogue positive (embed `programme_lineages!inner(code)`)

## Known limitations / product gates (not fixed here)

1. Concurrency overlap uses `pg_sleep` plus the production import advisory lock (documented in Gate G output).
2. Most role probes use `set_config('role', …)` (direct PostgreSQL role simulation); catalogue HTTP uses a disposable-stack signed JWT.
3. Optional column-selection hardening for `select('*')` is out of scope for Sprint 1.2.

## Cleanup

- Orchestrator stops **only** the disposable `--workdir` stack (`supabase stop` without `--all`)
- Removes temporary workdir
- Must leave production `supabase/migrations/` free of the test baseline
