

-- 1. Confirm environment: host must contain 'rel', DB = UDM__
SELECT @@hostname, DATABASE(), CURRENT_USER();

-- 2. Do the tables exist? (2 rows)
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 3. Counts + ChartAI baseline. RECORDED: 3 | 85 | 3 | 15 | 17 | 2203
SELECT
  (SELECT COUNT(*) FROM AIProvider)     AS providers,
  (SELECT COUNT(*) FROM AIProviderCall) AS calls,
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_secrets,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS clients_with_module,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_baseline,
  (SELECT COUNT(*) FROM Secrets) AS total_secrets;

-- 4. Providers and credentials (no secret values)
SELECT p.aiProviderId, p.clientId, p.name, p.credentialId, s.id AS secret_id
FROM AIProvider p LEFT JOIN Secrets s ON s.id = p.credentialId;

-- 5. Owning client (expect 53 kurtovest_demo)
SELECT DISTINCT c.clientId, c.clientName, c.s3Folder
FROM AIProvider p JOIN Client c ON c.clientId = p.clientId
ORDER BY c.clientId;



-- 7. Token position (15 rows, pos > 0 on every row)
SELECT clientId, JSON_LENGTH(modules) AS n,
       LOCATE('AIProviders', CAST(modules AS CHAR)) AS pos
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
ORDER BY clientId;

-- 8. SEED ROWS the upgrade removes: "before" snapshot (ONE statement).
--    Seen so far: permissions 4, role_permissions 12, activity_types 3.
--    RECORD all six (modules, activity_category, tableid still to fill in).
SELECT
  (SELECT COUNT(*) FROM Modules WHERE moduleId = 'AIProviders') AS modules,
  (SELECT COUNT(*) FROM Permissions WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS permissions,
  (SELECT COUNT(*) FROM RolePermission WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL')) AS role_permissions,
  (SELECT COUNT(*) FROM ActivityType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_types,
  (SELECT COUNT(*) FROM ActivityCategoryType WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE')) AS activity_category,
  (SELECT COUNT(*) FROM TableId WHERE tableName IN ('AIProvider','AIProviderCall')) AS tableid;

-- 9. Historical Activity rows (these STAY; upgrade does not delete them). Seen: 4.
SELECT COUNT(*) AS activity_rows_kept FROM Activity
WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE');
