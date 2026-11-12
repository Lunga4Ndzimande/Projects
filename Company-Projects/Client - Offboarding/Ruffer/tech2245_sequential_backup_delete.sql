-- =============================================================================
-- TECH-2245 / TECH-3948 — SEQUENTIAL BACKUP + VERIFY + DELETE
-- Scope confirmed by Ronelle Griffiths (see ticket comment): Workflow 4405,
-- WorkflowRun 44575, WorkflowRunItem 6392624 only.
-- Jupiter AM, clientId 2215, Production APP UK. Engine: SingleStore.
--
-- Flow for EACH table, in order:
--   1. Backup the affected rows into a tech2245_bak_* table
--   2. Verify: source count vs backup count (must match before deleting)
--   3. Delete the affected rows from the live table
--   4. Confirm: source count is now 0
--
-- Run one table's block at a time. Check the verify output before deleting
-- that table. Do not skip ahead if a count doesn't match.
-- =============================================================================


-- =============================================================================
-- TABLE 1: WorkflowRunItemEmail
-- Note: this table has NO clientId column (confirmed via SHOW COLUMNS) —
-- scoped by workflowItemId + workflowRunId only.
-- =============================================================================

-- Backup

CREATE TABLE tech2245_bak_WorkflowRunItemEmail AS
SELECT *
FROM WorkflowRunItemEmail
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575;

-- Verify (expect source_count = backup_count = 1)

SELECT 'WorkflowRunItemEmail' AS table_name,
  (SELECT COUNT(*) FROM WorkflowRunItemEmail
     WHERE workflowItemId = 6392624 AND workflowRunId = 44575) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_WorkflowRunItemEmail) AS backup_count;

--Delete (only after 1b confirms counts match)
DELETE FROM WorkflowRunItemEmail
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575;

Confirm zero
SELECT 'WorkflowRunItemEmail' AS table_name,
  COUNT(*) AS remaining
FROM WorkflowRunItemEmail
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575;

-- Expect: remaining = 0


=============================================================================
-- TABLE 2: WorkflowRunItemStatusHistory

=============================================================================

--  Backup
CREATE TABLE tech2245_bak_WorkflowRunItemStatusHistory AS
SELECT *
FROM WorkflowRunItemStatusHistory
WHERE workflowItemId = 6392624
  AND clientId = 2215;

-- Verify (expect source_count = backup_count = 6)
SELECT 'WorkflowRunItemStatusHistory' AS table_name,
  (SELECT COUNT(*) FROM WorkflowRunItemStatusHistory
     WHERE workflowItemId = 6392624 AND clientId = 2215) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_WorkflowRunItemStatusHistory) AS backup_count;

-- Delete (only after 2b confirms counts match)
DELETE FROM WorkflowRunItemStatusHistory
WHERE workflowItemId = 6392624
  AND clientId = 2215;

-- Confirm zero
SELECT 'WorkflowRunItemStatusHistory' AS table_name,
  COUNT(*) AS remaining
FROM WorkflowRunItemStatusHistory
WHERE workflowItemId = 6392624
  AND clientId = 2215;
-- Expect: remaining = 0


=============================================================================
-- TABLE 3: WorkflowRunItem
-- Composite key (workflowItemId + workflowRunId) — both required.

=============================================================================

-- Backup
CREATE TABLE tech2245_bak_WorkflowRunItem AS
SELECT *
FROM WorkflowRunItem
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575
  AND clientId = 2215;

-- Verify (expect source_count = backup_count = 1)
SELECT 'WorkflowRunItem' AS table_name,
  (SELECT COUNT(*) FROM WorkflowRunItem
     WHERE workflowItemId = 6392624 AND workflowRunId = 44575 AND clientId = 2215) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_WorkflowRunItem) AS backup_count;

-- Delete (only after 3b confirms counts match)
DELETE FROM WorkflowRunItem
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575
  AND clientId = 2215;

-- Confirm zero
SELECT 'WorkflowRunItem' AS table_name,
  COUNT(*) AS remaining
FROM WorkflowRunItem
WHERE workflowItemId = 6392624
  AND workflowRunId = 44575
  AND clientId = 2215;
  
-- Expect: remaining = 0

=============================================================================
-- TABLE 4: WorkflowRun
-- Only run 44575 — runs 44636/45037/45063 are OUT OF SCOPE, confirmed to have
-- zero items under them, and must NOT be touched here.

=============================================================================

-- Backup
CREATE TABLE tech2245_bak_WorkflowRun AS
SELECT *
FROM WorkflowRun
WHERE workflowRunId = 44575
  AND workflowId = 4405
  AND clientId = 2215;

-- 4b. Verify (expect source_count = backup_count = 1)
SELECT 'WorkflowRun' AS table_name,
  (SELECT COUNT(*) FROM WorkflowRun
     WHERE workflowRunId = 44575 AND workflowId = 4405 AND clientId = 2215) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_WorkflowRun) AS backup_count;

-- 4c. Delete (only after 4b confirms counts match)
DELETE FROM WorkflowRun
WHERE workflowRunId = 44575
  AND workflowId = 4405
  AND clientId = 2215;

-- 4d. Confirm zero
SELECT 'WorkflowRun' AS table_name,
  COUNT(*) AS remaining
FROM WorkflowRun
WHERE workflowRunId = 44575
  AND workflowId = 4405
  AND clientId = 2215;
-- Expect: remaining = 0

-- 4e. Sanity check — the 3 out-of-scope runs must still be present
SELECT workflowRunId, workflowId
FROM WorkflowRun
WHERE workflowRunId IN (44636, 45037, 45063)
  AND clientId = 2215;
-- Expect: 3 rows returned, unchanged



=============================================================================
-- TABLE 5: WorkflowEmailTemplate
-- Composite key (workflowId + emailType) — both required.

=============================================================================

-- 5a. Backup
CREATE TABLE tech2245_bak_WorkflowEmailTemplate AS
SELECT *
FROM WorkflowEmailTemplate
WHERE workflowId = 4405
  AND emailType = 'email_distribution'
  AND clientId = 2215;

-- 5b. Verify (expect source_count = backup_count = 1)
SELECT 'WorkflowEmailTemplate' AS table_name,
  (SELECT COUNT(*) FROM WorkflowEmailTemplate
     WHERE workflowId = 4405 AND emailType = 'email_distribution' AND clientId = 2215) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_WorkflowEmailTemplate) AS backup_count;

-- 5c. Delete (only after 5b confirms counts match)
DELETE FROM WorkflowEmailTemplate
WHERE workflowId = 4405
  AND emailType = 'email_distribution'
  AND clientId = 2215;

-- 5d. Confirm zero
SELECT 'WorkflowEmailTemplate' AS table_name,
  COUNT(*) AS remaining
FROM WorkflowEmailTemplate
WHERE workflowId = 4405
  AND emailType = 'email_distribution'
  AND clientId = 2215;
-- Expect: remaining = 0


=============================================================================
-- TABLE 6: Workflow
--Last step — the parent record itself.
=============================================================================

--Backup
CREATE TABLE tech2245_bak_Workflow AS
SELECT *
FROM Workflow
WHERE workflowId = 4405
  AND clientId = 2215;

--Verify (expect source_count = backup_count = 1)
SELECT 'Workflow' AS table_name,
  (SELECT COUNT(*) FROM Workflow
     WHERE workflowId = 4405 AND clientId = 2215) AS source_count,
  (SELECT COUNT(*) FROM tech2245_bak_Workflow) AS backup_count;

--Delete (only after 6b confirms counts match)
DELETE FROM Workflow
WHERE workflowId = 4405
  AND clientId = 2215;

--Confirm zero
SELECT 'Workflow' AS table_name,
  COUNT(*) AS remaining
FROM Workflow
WHERE workflowId = 4405
  AND clientId = 2215;
--Expect: remaining = 0

--Sanity check — live workflows must be untouched
SELECT workflowId
FROM Workflow
WHERE workflowId IN (4430, 4431, 4432, 4433)
  AND clientId = 2215;
-Expect: 4 rows returned, unchanged


-- =============================================================================
-- DONE. All six backup tables (tech2245_bak_*) remain in place for rollback
-- per the ticket's instructions ("restore the backed up rows in reverse
-- order"). Leave them as regular tables — do not drop them yet. Drop only
-- once the team is fully confident the deletion is correct and no rollback
-- will be needed.
-- =============================================================================
