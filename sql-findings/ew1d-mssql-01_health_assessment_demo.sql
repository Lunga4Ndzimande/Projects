/*
================================================================================
SQL SERVER HEALTH ASSESSMENT — DEMO SCRIPT
================================================================================
Server:      ew1d-mssql-01
Environment: Non-Production
Date:        10 June 2026
Prepared by: DBA Team

Purpose:
  Read-only queries used during the proactive health assessment covering:
    1. Drive space utilisation
    2. Backup infrastructure health (FULL / DIFF / LOG)
    3. Transaction log file sizes and shrink eligibility
    4. Offsite S3 backup verification (run run_s3_backup_demo.sh in terminal)

Notes for demo:
  - All queries below are READ-ONLY — safe to run during the demo
  - Remediation scripts (log shrink) are in Section 4 — run only with approval
  - Update connection/server name before presenting if needed
================================================================================
*/


-- =============================================================================
-- SECTION 1: DRIVE SPACE ANALYSIS
-- =============================================================================
-- Checks free space across all volumes (C:\, H:\, L:\, M:\, T:\)
-- Uses sys.dm_os_volume_stats — no changes to the environment

SELECT DISTINCT
    volume_mount_point                                      AS drive,
    total_bytes / 1024 / 1024 / 1024                        AS total_gb,
    available_bytes / 1024 / 1024 / 1024                    AS free_gb,
    CAST(available_bytes * 100.0 / total_bytes AS DECIMAL(5,2)) AS free_pct
FROM sys.dm_os_volume_stats(1, 1)
ORDER BY drive;

/*
Expected findings (10 June 2026):
  C:\  —  2.3 GB free  — CRITICAL
  H:\  — 66 GB free   — MONITOR
  L:\  — 110 GB free  — HEALTHY
  M:\  — 326 GB free  — HEALTHY (backup drive)
  T:\  — 197 GB free  — HEALTHY (TempDB)
*/


-- =============================================================================
-- SECTION 2: BACKUP INFRASTRUCTURE HEALTH
-- =============================================================================
-- Verifies FULL, DIFFERENTIAL, and LOG backups over the last 7 days
-- Backup path pattern: M:\SQL\Backup\ew1d-mssql-01\{DatabaseName}\{BackupType}\

SELECT TOP 20
    database_name,
    CAST(backup_start_date AS DATE)                         AS backup_date,
    CASE type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFF'
        WHEN 'L' THEN 'LOG'
    END                                                     AS backup_type,
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2))    AS size_mb,
    physical_device_name                                    AS backup_path
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE backup_start_date >= GETDATE() - 7
ORDER BY backup_start_date DESC;

/*
Expected findings (10 June 2026):
  FULL  — Last run: 2026-06-08 (every 2 days)  — Healthy
  DIFF  — Last run: 2026-06-10 (daily)         — Healthy
  LOG   — Last run: 2026-06-10 (intraday)      — Healthy

Offsite S3 copy (P4 — confirmed via AWS CLI):
  Bucket:  ksys-ew1d-general-dbbackup   (non-prod — matches ew1d-mssql-01)
           ksys-ew1d-ip-rds-dbbackup    (non-prod RDS)
           ksys-ew1r-general-dbbackup   (production)
  Storage: S3 Intelligent-Tiering — older backups auto-move to cheaper tiers
  Demo:    ./run_s3_backup_demo.sh
*/


-- =============================================================================
-- SECTION 3: TRANSACTION LOG ANALYSIS
-- =============================================================================

-- 3a. Log file sizes and space actually used
SELECT
    DB_NAME(database_id)                                    AS database_name,
    name                                                    AS log_file_name,
    CAST(size * 8.0 / 1024 AS DECIMAL(10,2))                AS log_size_mb,
    CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(10,2)) AS space_used_mb,
    CAST(
        (size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024
        AS DECIMAL(10,2)
    )                                                       AS recoverable_mb
FROM sys.master_files
WHERE type_desc = 'LOG'
  AND DB_NAME(database_id) NOT IN ('tempdb')
ORDER BY log_size_mb DESC;

/*
Expected findings (10 June 2026):
  TROWEPRICE   — ~7.4 GB log, ~0.86% used, ~7 GB recoverable
  SSISDB       — ~10.4 GB log, ~0.72% used, ~10 GB recoverable
  INVESTEC_Dev — ~10.2 GB log, < 1% used, ~10 GB recoverable
  TOTAL        — ~27 GB recoverable on L:\
*/


-- 3b. Log shrink eligibility — confirms no active blockers
SELECT
    name                AS database_name,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name NOT IN ('tempdb')
ORDER BY name;

/*
Expected result: log_reuse_wait_desc = 'NOTHING' for all databases
  → Safe to shrink during off-peak hours (non-prod only)
*/


-- =============================================================================
-- SECTION 4: REMEDIATION (DO NOT RUN DURING READ-ONLY DEMO)
-- =============================================================================
-- Execute only with DBA write access and during off-peak hours.
-- Run a LOG backup before shrinking to preserve recoverability.

/*
-- TROWEPRICE (~7 GB log, 0.86% used)
USE TROWEPRICE;
DBCC SHRINKFILE(TROWEPRICE_PrimaryLogFileName, 512);  -- Target: 512 MB

-- SSISDB (~10 GB log, 0.72% used)
USE SSISDB;
DBCC SHRINKFILE(log, 512);  -- Target: 512 MB

-- INVESTEC_Dev (~10 GB log)
USE INVESTEC_Dev;
DBCC SHRINKFILE(INVESTEC_Dev_PrimaryLogFileName, 512);  -- Target: 512 MB
*/


-- =============================================================================
-- DEMO CHECKLIST
-- =============================================================================
/*
[ ] Connect to ew1d-mssql-01 (SSMS or sqlcmd)
[ ] Run Section 1 — show C:\ critical at ~2.3 GB free
[ ] Run Section 2 — confirm FULL / DIFF / LOG backups are healthy
[ ] Run Section 3a — highlight oversized logs (~27 GB recoverable)
[ ] Run Section 3b — confirm log_reuse_wait_desc = NOTHING (safe to shrink)
[ ] Run ./run_s3_backup_demo.sh — show offsite bucket + Intelligent-Tiering (P4)
[ ] Walk through action plan from assessment report (P1–P5)
[ ] Section 4 — explain only; do not execute unless approved
*/
