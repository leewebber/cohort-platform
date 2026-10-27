#!/usr/bin/env bash
# Disposable local authenticated M1.2 proof. Never links a hosted project.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup(){ local ec=$?; set +e
 [[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1
 if [[ "$ec" -ne 0 && -f "$SPRINT12_WORKDIR/start-private.log" ]]; then cp "$SPRINT12_WORKDIR/start-private.log" /private/tmp/cohort_m12_start_failure.log; fi
 [[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR"
 exit "$ec"; }
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
# Prove independence from the deferred producer schema. Leave its repository
# file byte-identical; omit exactly that prospective file in this local copy.
rm "$SPRINT12_WORKDIR/supabase/migrations/20261026120000_durable_publication_approval_events.sql"
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
cat >> "$SPRINT12_WORKDIR/supabase/config.toml" <<'LOCAL_AUTH'

[auth.email]
enable_signup = true
enable_confirmations = false
max_frequency = "0s"
LOCAL_AUTH
cat > "$SPRINT12_WORKDIR/supabase/migrations/20261026105900_m12_local_acl_witness.sql" <<'LOCAL_ACL'
-- Disposable witness only. Never placed in repository migrations.
CREATE TABLE public.m12_pre_acls AS SELECT oid,proacl,proowner FROM pg_proc WHERE pronamespace='public'::regnamespace;
LOCAL_ACL
umask 077
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check > "$SPRINT12_WORKDIR/start-private.log" 2>&1
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
dart run "$TESTS_DIR/fixtures/c2_programme_publication_fixture.dart" "$SPRINT12_WORKDIR/fixture.sql"
for pass in fresh repeat; do
 if [[ "$pass" == repeat ]]; then supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" > "$SPRINT12_WORKDIR/reset-private.log" 2>&1; fi
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$SPRINT12_WORKDIR/fixture.sql" >/dev/null
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$ DECLARE p jsonb;r jsonb;BEGIN
 FOR p IN SELECT payload FROM public.c2p_payload LOOP
 r:=public.publish_private_exact_programme_version_retained_v1(p);
 IF r->>'status'<>'published' THEN RAISE EXCEPTION 'M12 synthetic publication refused: %',r;END IF;
 END LOOP;
END $$;
SQL
 supabase status -o json --workdir "$SPRINT12_WORKDIR" 2>/dev/null > "$SPRINT12_WORKDIR/status-private.json"
 ruby -rjson -e 'p=ARGV[0]; d=JSON.parse(File.read(p));d["CONTAINER"]=ARGV[1];File.write(p,JSON.generate(d))' "$SPRINT12_WORKDIR/status-private.json" "$SPRINT12_DB_CONTAINER"
 COHORT_M12_CONFIG="$SPRINT12_WORKDIR/status-private.json" flutter test --no-pub "$REPO_ROOT/test/programme_acquisition/authenticated_local_test.dart"
 echo "M12_AUTHENTICATED_${pass}=PASS"
done
