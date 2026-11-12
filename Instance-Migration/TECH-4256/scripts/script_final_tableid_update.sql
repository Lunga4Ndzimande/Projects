-- ============================================
--  Run this ONCE only — AFTER all client scripts have been executed
--  ClientLink TableId is intentionally NOT updated here
--     (not used by the application on this path — confirmed in peer review)
-- ============================================

SET @tableid = (SELECT COALESCE(MAX(clientConfigurationId), 0) + 1 FROM ClientConfiguration);
UPDATE TableId SET nextId = @tableid WHERE tableName LIKE 'ClientConfiguration';
