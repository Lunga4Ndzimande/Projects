/*
================================================================================
DISK SPACE MONITOR — SQL AGENT JOB (P3 Recommendation)
================================================================================
Server:      ew1d-mssql-01
Purpose:     Alert at 20%, 10%, and 5% free space thresholds
Owner:       DBA Team
Timeline:    Within 2 weeks (per assessment action plan)

Run this script on the SQL Server instance to create the monitoring job.
Requires:    sysadmin or sufficient msdb permissions
================================================================================
*/

USE msdb;
GO

-- ---------------------------------------------------------------------------
-- Step 1: Create operator (update email address before running)
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = N'DBA_Alerts')
BEGIN
    EXEC msdb.dbo.sp_add_operator
        @name               = N'DBA_Alerts',
        @enabled            = 1,
        @email_address      = N'dba-team@yourcompany.com';  -- UPDATE THIS
END
GO

-- ---------------------------------------------------------------------------
-- Step 2: Create the monitoring job
-- ---------------------------------------------------------------------------
DECLARE @jobId UNIQUEIDENTIFIER;

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Disk Space Monitor - ew1d-mssql-01')
BEGIN
    EXEC msdb.dbo.sp_add_job
        @job_name       = N'Disk Space Monitor - ew1d-mssql-01',
        @enabled        = 1,
        @description    = N'Alerts when drive free space drops below 20%, 10%, or 5%.',
        @category_name  = N'Database Maintenance',
        @owner_login_name = N'sa',
        @job_id         = @jobId OUTPUT;

    EXEC msdb.dbo.sp_add_jobstep
        @job_id             = @jobId,
        @step_name          = N'Check drive space and alert',
        @subsystem          = N'TSQL',
        @command            = N'
DECLARE @body NVARCHAR(MAX) = N'''';

SELECT @body = @body +
    N''Drive: '' + volume_mount_point +
    N'' | Free: '' + CAST(CAST(available_bytes * 100.0 / total_bytes AS DECIMAL(5,2)) AS NVARCHAR(10)) + N''%'' +
    N'' ('' + CAST(available_bytes / 1024 / 1024 / 1024 AS NVARCHAR(10)) + N'' GB)'' + CHAR(13) + CHAR(10)
FROM sys.dm_os_volume_stats(1, 1)
WHERE CAST(available_bytes * 100.0 / total_bytes AS DECIMAL(5,2)) < 20
ORDER BY available_bytes * 100.0 / total_bytes;

IF LEN(@body) > 0
BEGIN
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name   = N''Default Database Mail Profile'',  -- UPDATE IF NEEDED
        @recipients     = N''dba-team@yourcompany.com'',       -- UPDATE THIS
        @subject        = N''[ALERT] ew1d-mssql-01 — Low disk space detected'',
        @body           = @body;
END
',
        @database_name      = N'master',
        @on_success_action  = 1,
        @on_fail_action     = 2;

    EXEC msdb.dbo.sp_add_jobschedule
        @job_id             = @jobId,
        @name               = N'Every 15 minutes',
        @freq_type          = 4,
        @freq_interval      = 1,
        @freq_subday_type   = 4,
        @freq_subday_interval = 15,
        @active_start_time  = 0;

    EXEC msdb.dbo.sp_add_jobserver
        @job_id     = @jobId,
        @server_name = N'(LOCAL)';
END
GO

-- ---------------------------------------------------------------------------
-- Step 3: Manual test — run the check query without sending mail
-- ---------------------------------------------------------------------------
SELECT
    volume_mount_point                                      AS drive,
    CAST(available_bytes * 100.0 / total_bytes AS DECIMAL(5,2)) AS free_pct,
    available_bytes / 1024 / 1024 / 1024                    AS free_gb,
    CASE
        WHEN available_bytes * 100.0 / total_bytes < 5  THEN 'CRITICAL'
        WHEN available_bytes * 100.0 / total_bytes < 10 THEN 'WARNING'
        WHEN available_bytes * 100.0 / total_bytes < 20 THEN 'MONITOR'
        ELSE 'OK'
    END                                                     AS alert_level
FROM sys.dm_os_volume_stats(1, 1)
ORDER BY free_pct;
