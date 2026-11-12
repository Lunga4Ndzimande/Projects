
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 2b. Counts + ChartAI baseline. RECORD: providers | calls | matching_secrets |
--     clients_with_module | chartai_baseline | total_secrets
SELECT
  (SELECT COUNT(*) FROM AIProvider)     AS providers,
  (SELECT COUNT(*) FROM AIProviderCall) AS calls,
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_secrets,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS clients_with_module,
  (SELECT COUNT(*) FROM Secrets) AS total_secrets;

-- 2c. Providers and their credential IDs. THESE IDs (not the stale ones in the
--     header) go into the dump and delete commands below.
SELECT p.aiProviderId, p.clientId, p.name, p.credentialId, s.id AS secret_id
FROM AIProvider p LEFT JOIN Secrets s ON s.id = p.credentialId;

-- 2d. Owning clients (expect the Kurtosys demo client, 109)
SELECT DISTINCT c.clientId, c.clientName, c.s3Folder
FROM AIProvider p JOIN Client c ON c.clientId = p.clientId
ORDER BY c.clientId;


-- 2g. Does any Secret match by clientId but NOT by credentialId? Informational only:
--     these are NOT deleted by this ticket.

SELECT COUNT(*) AS other_secrets_for_owning_clients FROM Secrets
WHERE clientId IN (SELECT clientId FROM AIProvider)
  AND id NOT IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);


