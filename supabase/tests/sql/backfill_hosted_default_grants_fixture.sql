-- Disposable-only: appended to the copied baseline BEFORE production replay.
-- Reproduce observed postgres/public function defaults; never hosted SQL.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
