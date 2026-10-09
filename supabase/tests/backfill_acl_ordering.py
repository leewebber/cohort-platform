"""Disposable-only exact ACL replay/replacement and fail-closed controls."""
import json
import os
from pathlib import Path
import subprocess

container = os.environ["SPRINT12_DB_CONTAINER"]
assert container == "supabase_db_" + os.environ["SPRINT12_PROJECT_ID"]
root = Path(__file__).resolve().parents[2]
migration = (root / "supabase/migrations/20261009120000_backfill_authenticated_execute.sql").read_text()
# Preserve the production statements verbatim; omit only transaction boundaries
# so destructive recurrence/authority probes can be rolled back together.
body = "\n".join(line for line in migration.splitlines() if line not in ("BEGIN;", "COMMIT;"))
signature = "public.complete_backfilled_fixed_programme_occurrence(jsonb)"


def sql(text, denied=False):
    result = subprocess.run(
        ["docker", "exec", "-i", container, "psql", "-X", "-qAt", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
        input=text, text=True, capture_output=True, check=False,
    )
    if denied:
        assert result.returncode != 0 and "backfill_authenticated_execute_contract_mismatch" in result.stderr
    else:
        assert result.returncode == 0, result.stderr
    return result.stdout.strip()


snapshot = """SELECT jsonb_build_object(
 'functions',(SELECT jsonb_agg(jsonb_build_array(oid,md5(pg_get_functiondef(oid)),proacl::text) ORDER BY oid)
 FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind='f'),
 'defaults',(SELECT jsonb_agg(to_jsonb(d) ORDER BY oid) FROM pg_default_acl d),
 'memberships',(SELECT jsonb_agg(to_jsonb(m) ORDER BY roleid,member) FROM pg_auth_members m),
 'evidence',public.completion_security_digest());"""
before = json.loads(sql(snapshot))
assert sql(f"SELECT has_function_privilege('authenticated','{signature}','EXECUTE') AND NOT has_function_privilege('service_role','{signature}','EXECUTE');") == "t"

# CREATE OR REPLACE retains the corrected ACL even under broad defaults.
sql(f"""BEGIN;
DO $$ BEGIN EXECUTE pg_get_functiondef('{signature}'::regprocedure); END $$;
DO $$ BEGIN IF has_function_privilege('service_role','{signature}','EXECUTE')
 THEN RAISE EXCEPTION 'replacement_restored_service_execute'; END IF; END $$;
{body}
ROLLBACK;""")
assert json.loads(sql(snapshot)) == before
print("BACKFILL_CREATE_OR_REPLACE_ACL_STABLE=PASS")

# Dropping/recreating this exact public signature DOES inherit hosted defaults.
# Reproduce the original wrapper's PUBLIC/anon revokes, then run the actual fix.
sql(f"""BEGIN;
DO $$ DECLARE definition text := pg_get_functiondef('{signature}'::regprocedure);
BEGIN
 EXECUTE 'DROP FUNCTION {signature}'; EXECUTE definition;
 IF NOT has_function_privilege('service_role','{signature}','EXECUTE')
 THEN RAISE EXCEPTION 'drop_create_recurrence_not_reproduced'; END IF;
END $$;
REVOKE ALL ON FUNCTION {signature} FROM PUBLIC, anon;
{body}
DO $$ BEGIN IF has_function_privilege('service_role','{signature}','EXECUTE')
 OR NOT has_function_privilege('authenticated','{signature}','EXECUTE')
 THEN RAISE EXCEPTION 'recreated_wrapper_contract_failed'; END IF; END $$;
ROLLBACK;""")
assert json.loads(sql(snapshot)) == before
print("BACKFILL_DROP_CREATE_RECURRENCE_AND_EXACT_FIX=PASS")

# These are adverse LOCAL controls, not proposals to change hosted roles. A
# direct revoke must not silently claim safety when membership/PUBLIC bypass it.
for adverse in (
    f"GRANT EXECUTE ON FUNCTION {signature} TO PUBLIC;",
    "GRANT authenticated TO service_role WITH INHERIT TRUE;",
    f"REVOKE EXECUTE ON FUNCTION {signature} FROM authenticated;",
):
    sql("BEGIN;\n" + adverse + "\n" + body, denied=True)
    assert json.loads(sql(snapshot)) == before
print("BACKFILL_PUBLIC_INHERITANCE_MISSING_AUTH_FAIL_CLOSED_ZERO_RESIDUE=PASS")

# Actual migration replays, after replacement and all earlier security files,
# preserve the corrected ACL, every function/default/membership and evidence.
sql(migration)
sql(migration)
assert json.loads(sql(snapshot)) == before
print("BACKFILL_REPEAT_MIGRATION_ORDERING_AND_PRESERVATION=PASS")
