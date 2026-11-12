
/* =====================================================================
   STAGE 8 - VERIFY ACCEPTANCE CRITERIA
   ===================================================================== */

-- 8a. Tables gone (expect NO rows)
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 8b. Module token gone; ChartAI unchanged (0 and the baseline from 2b)
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai;

-- 8c. Provider secret(s) gone (expect 0). Uses IDs because AIProvider no longer exists.
SELECT COUNT(*) AS should_be_0 FROM Secrets
WHERE id IN ('57a3e32b-50fa-4005-b05b-30164a9ba7c6');

-- 8d. Seed rows removed by the upgrade: each should be 0.


SELECT
  (SELECT COUNT(*) FROM Modules WHERE moduleId = 'AIProviders') AS modules_left,
  (SELECT COUNT(*) FROM Permissions WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS permissions_left,
  (SELECT COUNT(*) FROM RolePermission WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS role_permissions_left,
  (SELECT COUNT(*) FROM ActivityType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_types_left,
  (SELECT COUNT(*) FROM ActivityCategoryType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_category_left,
  (SELECT COUNT(*) FROM TableId WHERE tableName IN ('AIProvider','AIProviderCall')) AS tableid_left


