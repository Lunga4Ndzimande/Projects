/* =====================================================================
   TECH-4399 / KSYS-12922 - REL - PART 4: RESTORE / ROLLBACK TESTS (root)
   Host ew1r-kapp-db-primary.rel.kurtosys-internal.net (master aggregator ew1r-aggr-03)
   DB UDM__ | Jumpbox ew1r-jump-01.rel.kurtosys-internal.net
   STATUS: Secrets restore TESTED and PASSED. Seed-row restore tests TO DO. Restores DATA only, not app code or udm_ai.
   RULES: ONE statement at a time. Paste one command at a time, single line, no
   prompt or output text. mysql> = SQL only; shell prompt = shell only.
   A new shell (sudo su) loses DBHOST/TS: re-set and check  echo "[$TS] [$DBHOST]"
   Passwords only at the prompt. Writes are commented out and tagged [WRITE].
   ===================================================================== */


-- ===== RESTORE 1. Secrets (TESTED, passed) =====
-- [SHELL] cd /tmp/KSYS-12922-rel
-- [SHELL] TS=20261110-112806   then   echo "[$TS] [$DBHOST]"   (empty TS => "No such file")
-- [SHELL] ls -l Secrets_aiprovider_backup_$TS.sql
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Secrets_aiprovider_backup_$TS.sql
-- Check: matching_left 3, total_now 2203. Then repeat the delete (Part 3 B2) so REL ends clean.
SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets) AS total_now;
-- Final clean state expected: 0 | 2200 | providers 3  (still to confirm after the test)

-- ===== RESTORE 2. Seed rows: LEVEL A (safe replay, changes nothing) =====
-- Dumps use REPLACE INTO, so loading them re-writes the same rows. Run Part 1 step 8
-- before and after: the six counts must be identical. Needs root (CSE cannot insert).
-- [SHELL] (TS2 = timestamp of the Seed_ files)
--   for t in Modules Permissions RolePermission ActivityType ActivityCategoryType TableId; do echo "== $t"; mysql -h "$DBHOST" -u root -p UDM__ < Seed_${t}_$TS2.sql || break; done

-- ===== RESTORE 3. Seed rows: LEVEL B (delete then restore; REL ONLY, never prod) =====
-- Child first, then parent. Optional; Level A is enough to prove the files load.
-- [WRITE] 
-- DELETE FROM RolePermission WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL');
-- DELETE FROM Permissions    WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL');
--   Check Part 1 step 8: permissions 0, role_permissions 0. Then restore parent first:
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Seed_Permissions_$TS2.sql
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Seed_RolePermission_$TS2.sql
--   Check Part 1 step 8: permissions 4, role_permissions 12 (as before).

-- ===== FULL ROLLBACK (only if something goes wrong; reverse order) =====
-- [SHELL] cd /tmp/KSYS-12922-rel   (re-set TS, DBHOST)
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < AIProvider_tables_backup_$TS.sql   # DROP/CREATE + data (needs DDL rights)
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Client_modules_backup_$TS.sql      # REPLACE INTO, whole rows
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Secrets_aiprovider_backup_$TS.sql  # if rows exist: delete first
-- [SHELL] seed rows: Modules, Permissions, RolePermission, ActivityType, ActivityCategoryType, TableId
-- Then re-run Part 1 steps 3 and 8 and compare with the recorded numbers.
-- LIMITS: Roles table is untouched by this ticket. Postgres not covered.
