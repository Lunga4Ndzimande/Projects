/* =====================================================================
   TECH-4399 / KSYS-12922 - REL - PART 5: UPGRADE + VERIFY + EVIDENCE
   Host ew1r-kapp-db-primary.rel.kurtosys-internal.net (master aggregator ew1r-aggr-03)
   DB UDM__ | Jumpbox ew1r-jump-01.rel.kurtosys-internal.net
   STATUS: NOT started. Prereq: Parts 2 (A and B), 3 (B and C) complete and verified.
   RULES: ONE statement at a time. Paste one command at a time, single line, no
   prompt or output text. mysql> = SQL only; shell prompt = shell only.
   A new shell (sudo su) loses DBHOST/TS: re-set and check  echo "[$TS] [$DBHOST]"
   Passwords only at the prompt. Writes are commented out and tagged [WRITE].
   ===================================================================== */


-- ===== STEP 1. Deploy the upgrade (NOT by hand) =====
-- Through the usual DB upgrade path, branch
--   feature/KSYS-12922-drop-aiprovider-tables-and-module-seeds
-- file udm_db/artifacts/upgrades/2026-09-15-drop-ai-provider-tables.sql
-- It drops AIProviderCall, then AIProvider; removes module AIProviders, 4 permissions,
-- RolePermission grants, CREATE/UPDATE/DELETE activity types, TableId rows.
-- It does NOT touch Client.modules (done in Part 3) and NOT the Roles table.
-- Review the file first: confirm its DELETE conditions match the Part 1 step 8 queries.

-- ===== STEP 2. Verify (one statement at a time) =====
-- 2a. Tables gone (expect NO rows)
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 2b. Module token gone; ChartAI unchanged (0 and 17)
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_17;

-- 2c. Secrets gone (expect 0; AIProvider no longer exists so use IDs). Total expect 2200.
SELECT COUNT(*) AS should_be_0 FROM Secrets
WHERE id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573',
             '7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42',
             '25b6b4fc-1367-42e0-a949-47f902060ff2');
SELECT COUNT(*) AS total_secrets_expect_2200 FROM Secrets;

-- 2d. Seed rows: all six must be 0 (ONE statement)
SELECT
  (SELECT COUNT(*) FROM Modules WHERE moduleId = 'AIProviders') AS modules_left,
  (SELECT COUNT(*) FROM Permissions WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS permissions_left,
  (SELECT COUNT(*) FROM RolePermission WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS role_permissions_left,
  (SELECT COUNT(*) FROM ActivityType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_types_left,
  (SELECT COUNT(*) FROM ActivityCategoryType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_category_left,
  (SELECT COUNT(*) FROM TableId WHERE tableName IN ('AIProvider','AIProviderCall')) AS tableid_left;

-- 2e. Roles intact and history kept (Activity rows stay: expect the same 4)
SELECT COUNT(*) AS activity_rows_kept FROM Activity
WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE');

-- ===== STEP 3. Evidence for the ticket =====
-- Hostname line; Part 1 counts and step 8 "before"; checksums_*.txt (NOT the Secrets dump);
-- Part 3 B3, C1, C4; Part 5 2a-2e. Note: Postgres not covered.
-- After sign-off: delete dump files (esp. Secrets) from /tmp/KSYS-12922-rel; unset MYSQL_PWD.
