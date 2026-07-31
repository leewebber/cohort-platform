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

## Known limitations / product gates (not fixed here)

1. **Catalogue SELECT grants** remain a separate deployment/integration gate (Gate I). This harness does **not** add production grants or treat local privilege defaults as hosted parity.
2. RLS policy semantics are tested only after **temporary disposable GRANT SELECT**, then revoked.
3. Concurrency overlap uses `pg_sleep` plus the production import advisory lock (documented in Gate G output).
4. Role probes use `set_config('role', …)` (direct PostgreSQL role simulation), not full athlete JWT HTTP flows, except a PostgREST privilege-denial check.

## Cleanup

- Orchestrator stops **only** the disposable `--workdir` stack (`supabase stop` without `--all`)
- Removes temporary workdir
- Must leave production `supabase/migrations/` free of the test baseline
