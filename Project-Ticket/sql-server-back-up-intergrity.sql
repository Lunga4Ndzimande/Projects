Step 1 — Check all three backup types ran recently
This is Evidence 4 expanded. Instead of just LOG backups, you check FULL, DIFFERENTIAL, and LOG all in one query.
sql-- ============================================================
-- TICKET: Review and Validate SQL Server Backup Integrity
-- STEP 1: Confirm all backup types ran recently
-- Server  : EW1D-MSSQL-01 (DEV)
-- Purpose : Checks FULL, DIFFERENTIAL and LOG backups
--           across all databases in the last 7 days
-- Action  : Any database missing a backup type = flag it
-- READ ONLY — safe to execute
-- ============================================================

SELECT
    database_name,
    CASE type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFFERENTIAL'
        WHEN 'L' THEN 'LOG'
    END                             AS backup_type,
    MAX(backup_start_date)          AS last_backup_date,
    DATEDIFF(HOUR,
        MAX(backup_start_date),
        GETDATE())                  AS hours_since_backup,
    COUNT(*)                        AS total_backups_7_days,
    CAST(AVG(backup_size
        / 1048576.0)
        AS DECIMAL(10,2))           AS avg_backup_size_mb
FROM msdb.dbo.backupset
WHERE type IN ('D', 'I', 'L')
AND backup_start_date >= GETDATE() - 7
GROUP BY database_name, type
ORDER BY database_name, type
What to expect:

Every FULL recovery database should show all three backup types. SIMPLE recovery databases will only show FULL and DIFFERENTIAL — no LOG backups, which is normal. The avg_backup_size_mb column is important — a backup that is suspiciously small like 0 or 1 MB on a large database could mean something went wrong.

Step 2 — Check SQL Agent job history for backup errors
A backup job can run and still produce errors. This query checks whether the backup jobs completed successfully or with failures.
sql-- ============================================================
-- TICKET: Review and Validate SQL Server Backup Integrity
-- STEP 2: Check SQL Agent backup job history for errors
-- Server  : EW1D-MSSQL-01 (DEV)
-- Purpose : Confirms backup jobs completed without errors
-- Action  : Any failure = flag immediately to manager
-- READ ONLY — safe to execute
-- ============================================================

SELECT
    j.name                          AS job_name,
    h.run_date,
    h.run_time,
    CASE h.run_status
        WHEN 0 THEN 'FAILED'
        WHEN 1 THEN 'SUCCEEDED'
        WHEN 2 THEN 'RETRY'
        WHEN 3 THEN 'CANCELLED'
        WHEN 4 THEN 'IN PROGRESS'
    END                             AS job_status,
    h.message                       AS error_message
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobhistory h
    ON j.job_id = h.job_id
WHERE j.name LIKE '%backup%'        -- Filters to backup jobs only
AND h.run_date >= CONVERT(INT,
    CONVERT(VARCHAR,
    GETDATE() - 7, 112))            -- Last 7 days
AND h.step_id = 0                   -- Step 0 = overall job result
ORDER BY h.run_date DESC, h.run_time DESC
What to expect:

Every row should show SUCCEEDED in the job_status column. If you see FAILED anywhere, note the job name, the date, and copy the error_message — that goes straight to your manager.

Step 3 — Check backup file sizes are healthy
This catches backups that ran but produced suspiciously small files — which could indicate a corrupt or incomplete backup.
sql-- ============================================================
-- TICKET: Review and Validate SQL Server Backup Integrity
-- STEP 3: Validate backup file sizes are reasonable
-- Server  : EW1D-MSSQL-01 (DEV)
-- Purpose : A backup that ran but is 0 MB is useless
--           Compare backup size against database size
-- Action  : Flag any backup smaller than 1 MB on a large DB
-- READ ONLY — safe to execute
-- ============================================================

SELECT
    b.database_name,
    CASE b.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFFERENTIAL'
        WHEN 'L' THEN 'LOG'
    END                             AS backup_type,
    b.backup_start_date,
    b.backup_finish_date,
    DATEDIFF(MINUTE,
        b.backup_start_date,
        b.backup_finish_date)       AS duration_minutes,
    CAST(b.backup_size
        / 1048576.0
        AS DECIMAL(10,2))           AS backup_size_mb,
    CAST(b.compressed_backup_size
        / 1048576.0
        AS DECIMAL(10,2))           AS compressed_size_mb,
    bmf.physical_device_name        AS backup_file_location
FROM msdb.dbo.backupset b
JOIN msdb.dbo.backupmediafamily bmf
    ON b.media_set_id = bmf.media_set_id
WHERE b.backup_start_date >= GETDATE() - 7
AND b.type IN ('D', 'I', 'L')
ORDER BY b.backup_start_date DESC
