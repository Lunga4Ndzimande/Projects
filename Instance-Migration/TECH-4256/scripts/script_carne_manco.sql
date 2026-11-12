-- ============================================
-- TECH-4256: Instance Migration | Client Linking
-- Client: Carne - ManCo (UK)
-- Peer Reviewed: Tashvir Babulal, Yogeshwar Phull
-- Reference: TECH-4533, TECH-1720
-- ============================================

SET @developmentClientId = 2232;
SET @stagingClientId     = 2233;
SET @productionClientId  = 2234;

-- STEP 1: Pre-validation — should return NO rows
SELECT * FROM ClientLink
WHERE clientId IN (@developmentClientId, @stagingClientId, @productionClientId);

-- STEP 2: Link clients
SET @nextLinkId = (SELECT MAX(linkId) + 1 FROM ClientLink);

INSERT INTO ClientLink (linkId, clientId, linkLabel)
VALUES
    (@nextLinkId, @developmentClientId, 'Development'),
    (@nextLinkId, @stagingClientId,     'Staging'),
    (@nextLinkId, @productionClientId,  'Production');

-- STEP 3: Check current feature flag status
SELECT
    clientId,
    COALESCE(configurationItem::FEATURE_INSTANCE_MIGRATION, false) AS instanceMigrationEnabled,
    CASE
        WHEN clientId = @developmentClientId THEN 'Development'
        WHEN clientId = @stagingClientId     THEN 'Staging'
        WHEN clientId = @productionClientId  THEN 'Production'
    END AS environment
FROM ClientConfiguration
WHERE code = 'flags'
    AND clientId IN (@developmentClientId, @stagingClientId, @productionClientId)
ORDER BY clientId;

-- STEP 4: Enable FEATURE_INSTANCE_MIGRATION
SET @nextId = (SELECT COALESCE(MAX(clientConfigurationId), 0) + 1 FROM ClientConfiguration);

INSERT INTO ClientConfiguration (clientConfigurationId, clientId, code, configurationItem, lastModified)
VALUES
    (@nextId,     @developmentClientId, 'flags', '{"FEATURE_INSTANCE_MIGRATION": true}', CURRENT_TIMESTAMP),
    (@nextId + 1, @stagingClientId,     'flags', '{"FEATURE_INSTANCE_MIGRATION": true}', CURRENT_TIMESTAMP),
    (@nextId + 2, @productionClientId,  'flags', '{"FEATURE_INSTANCE_MIGRATION": true}', CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    configurationItem = JSON_SET_JSON(configurationItem, 'FEATURE_INSTANCE_MIGRATION', 'true'),
    lastModified = CURRENT_TIMESTAMP;

-- STEP 5: Verify feature flag
SELECT
    clientId,
    configurationItem::FEATURE_INSTANCE_MIGRATION AS instanceMigrationEnabled,
    CASE
        WHEN clientId = @developmentClientId THEN 'Development'
        WHEN clientId = @stagingClientId     THEN 'Staging'
        WHEN clientId = @productionClientId  THEN 'Production'
    END AS environment,
    configurationItem,
    lastModified
FROM ClientConfiguration
WHERE code = 'flags'
    AND clientId IN (@developmentClientId, @stagingClientId, @productionClientId)
ORDER BY clientId;
