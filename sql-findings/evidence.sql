Here are all 5 queries with full comments, tailored for your Monday morning check:

Evidence 1 — Log file sizes
sql-- ============================================================
-- EVIDENCE 1: Log File Sizes
-- Server  : EW1D-MSSQL-01 (DEV)
-- Run by  : [Your Name]
-- Date    : Monday 17 June 2026
-- Purpose : Check current allocated size of every transaction
--           log file. Compare against yesterday (16 June):
--           KSDK_157_Dev = 139,648 MB | UDM_Rel = 85,172 MB
--           SSISDB = 10,667 MB | INVESTEC_Dev = 10,497 MB
--           TROWEPRICE = 7,537 MB
-- Action  : Flag any database that has grown overnight
-- ============================================================

SELECT
    DB_NAME(database_id)        AS database_name,
    name                        AS log_file_name,
    physical_name               AS file_location,
    size * 8 / 1024             AS allocated_size_mb,   -- Size in MB
    size * 8 / 1024 / 1024      AS allocated_size_gb,   -- Size in GB (rounded)
    GETDATE()                   AS checked_date,         -- Timestamp of this run
    @@SERVERNAME                AS server_name
FROM sys.master_files
WHERE type_desc = 'LOG'        -- Transaction logs only, exclude data files
ORDER BY size DESC              -- Largest files first

Evidence 2 — Actual space in use
sql-- ============================================================
-- EVIDENCE 2: Actual Log Space In Use
-- Server  : EW1D-MSSQL-01 (DEV)
-- Run by  : [Your Name]
-- Date    : Monday 17 June 2026
-- Purpose : Shows what % of each log file is actually being
--           used. Yesterday all databases were under 2% used.
--           KSDK_157_Dev = 0.03% | UDM_Rel = 0.71%
--           A large file with low % = wasted space
-- Action  : Flag any database suddenly showing high usage %
--           as that could mean an active refresh or long-
--           running transaction started over the weekend
-- ============================================================

DBCC SQLPERF(LOGSPACE)
-- Columns returned:
-- Database Name    = database
-- Log Size (MB)    = total allocated log size
-- Log Space Used % = how much is actually in use
-- Status           = always 0, can be ignored

Evidence 3 — Shrink blockers
sql-- ============================================================
-- EVIDENCE 3: Check for Shrink Blockers
-- Server  : EW1D-MSSQL-01 (DEV)
-- Run by  : [Your Name]
-- Date    : Monday 17 June 2026
-- Purpose : Confirms nothing is blocking a shrink operation.
--           Yesterday every database showed NOTHING meaning
--           all are clear and safe to shrink.
-- Action  : If any database shows something other than NOTHING
--           do NOT shrink it. Use the reference below:
--           LOG_BACKUP        = run a log backup first
--           ACTIVE_TRANSACTION = wait for it to complete
--           REPLICATION       = speak to senior DBA
--           Monday risk: weekend jobs may have left open
--           transactions — check this carefully today
-- ============================================================

SELECT
    name                    AS database_name,
    recovery_model_desc     AS recovery_model,  -- FULL or SIMPLE
    log_reuse_wait_desc     AS shrink_blocker,  -- NOTHING = safe
    state_desc              AS database_state   -- Should be ONLINE
FROM sys.databases
WHERE name NOT IN ('tempdb')  -- tempdb manages itself, exclude it
ORDER BY name

Evidence 4 — Backup health
sql-- ============================================================
-- EVIDENCE 4: Log Backup Health Check
-- Server  : EW1D-MSSQL-01 (DEV)
-- Run by  : [Your Name]
-- Date    : Monday 17 June 2026
-- Purpose : Confirms log backups ran over the weekend and
--           are still running this morning. Yesterday all
--           FULL recovery databases showed 24 backups in
--           24 hours (hourly schedule firing at HH:00:01).
-- Action  : Any FULL recovery database missing from results
--           means its log backups have stopped — this is
--           urgent and must be flagged to your manager
--           immediately before any other work is done.
--           NOTE: SIMPLE recovery databases (UDM_Rel,
--           KurtosysQA, Support_Dev) will NOT appear here
--           — that is normal and expected.
-- ============================================================

SELECT
    database_name,
    MAX(backup_start_date)          AS last_log_backup,       -- When did the last one run?
    DATEDIFF(MINUTE,
        MAX(backup_start_date),
        GETDATE())                  AS minutes_since_backup,  -- How long ago?
    COUNT(*)                        AS backups_last_24hrs     -- Should be ~24 for hourly jobs
FROM msdb.dbo.backupset
WHERE type = 'L'                            -- L = Log backup only
AND backup_start_date >= GETDATE() - 1      -- Last 24 hours only
GROUP BY database_name
ORDER BY last_log_backup DESC               -- Most recent first

Evidence 5 — Recoverable space
sql-- ============================================================
-- EVIDENCE 5: Recoverable Space Calculation
-- Server  : EW1D-MSSQL-01 (DEV)
-- Run by  : [Your Name]
-- Date    : Monday 17 June 2026
-- Purpose : Calculates exactly how much disk space can be
--           reclaimed per database by shrinking logs to
--           512 MB target. Yesterday's totals were:
--           KSDK_157_Dev  = ~135.5 GB recoverable
--           UDM_Rel       = ~82.5  GB recoverable
--           SSISDB        = ~9.9   GB recoverable
--           INVESTEC_Dev  = ~9.7   GB recoverable
--           TROWEPRICE    = ~6.9   GB recoverable
--           EW1D TOTAL    = ~244   GB recoverable
-- Action  : Compare recoverable_gb against yesterday.
--           Any database growing day-over-day while not
--           in active use should be flagged to manager.
-- ============================================================

SELECT
    @@SERVERNAME                        AS server_name,
    DB_NAME(database_id)                AS database_name,
    name                                AS log_file_name,
    size * 8 / 1024                     AS current_size_mb,    -- What it is now
    512                                 AS target_size_mb,     -- What we want to shrink to
    (size * 8 / 1024) - 512             AS recoverable_mb,     -- Difference = wasted space
    CAST(((size * 8 / 1024) - 512)
        / 1024.0 AS DECIMAL(10,2))      AS recoverable_gb      -- Same in GB, 2 decimal places
FROM sys.master_files
WHERE type_desc = 'LOG'        -- Transaction logs only
AND size * 8 / 1024 > 512      -- Only show databases larger than target
ORDER BY recoverable_mb DESC   -- Biggest opportunity first