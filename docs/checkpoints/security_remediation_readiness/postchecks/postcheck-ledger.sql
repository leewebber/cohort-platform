SELECT count(*)=122 AS expected_ledger_count,max(version)='20261009120000' AS expected_latest,
 count(*) FILTER(WHERE version IN ('20261007120000','20261007130000','20261008120000','20261008121000','20261009120000'))=5 AS all_five_applied
 FROM supabase_migrations.schema_migrations;
