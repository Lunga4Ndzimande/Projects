#!/usr/bin/env bash
# =============================================================================
# SQL Server Health Assessment — sqlcmd demo runner
# =============================================================================
# Usage:
#   export SQLSERVER="ew1d-mssql-01"
#   export SQLUSER="your_login"
#   export SQLPASS="your_password"        # or use -E for Windows auth on Windows
#   ./run_demo_sqlcmd.sh                  # run all sections
#   ./run_demo_sqlcmd.sh 1                # run section 1 only
#
# Requires: sqlcmd (SQL Server command-line tools)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="${SQLSERVER:-ew1d-mssql-01}"
USER="${SQLUSER:-}"
PASS="${SQLPASS:-}"
SECTION="${1:-all}"

run_query() {
  local label="$1"
  local query="$2"
  echo ""
  echo "================================================================"
  echo "  $label"
  echo "================================================================"
  if [[ -n "$USER" && -n "$PASS" ]]; then
    sqlcmd -S "$SERVER" -U "$USER" -P "$PASS" -Q "$query" -W -s "|"
  else
    echo "Set SQLUSER and SQLPASS, or edit this script for your auth method."
    exit 1
  fi
}

SECTION_1='SELECT DISTINCT volume_mount_point AS drive, total_bytes/1024/1024/1024 AS total_gb, available_bytes/1024/1024/1024 AS free_gb, CAST(available_bytes*100.0/total_bytes AS DECIMAL(5,2)) AS free_pct FROM sys.dm_os_volume_stats(1,1) ORDER BY drive;'

SECTION_2="SELECT TOP 20 database_name, CAST(backup_start_date AS DATE) AS backup_date, CASE type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' END AS backup_type, CAST(backup_size/1024.0/1024.0 AS DECIMAL(10,2)) AS size_mb, physical_device_name AS backup_path FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id=bmf.media_set_id WHERE backup_start_date>=GETDATE()-7 ORDER BY backup_start_date DESC;"

SECTION_3A="SELECT DB_NAME(database_id) AS database_name, name AS log_file_name, CAST(size*8.0/1024 AS DECIMAL(10,2)) AS log_size_mb, CAST(FILEPROPERTY(name,'SpaceUsed')*8.0/1024 AS DECIMAL(10,2)) AS space_used_mb, CAST((size-FILEPROPERTY(name,'SpaceUsed'))*8.0/1024 AS DECIMAL(10,2)) AS recoverable_mb FROM sys.master_files WHERE type_desc='LOG' AND DB_NAME(database_id) NOT IN ('tempdb') ORDER BY log_size_mb DESC;"

SECTION_3B="SELECT name AS database_name, recovery_model_desc, log_reuse_wait_desc FROM sys.databases WHERE name NOT IN ('tempdb') ORDER BY name;"

case "$SECTION" in
  1) run_query "SECTION 1: Drive Space" "$SECTION_1" ;;
  2) run_query "SECTION 2: Backup Health" "$SECTION_2" ;;
  3a) run_query "SECTION 3a: Log File Sizes" "$SECTION_3A" ;;
  3b) run_query "SECTION 3b: Log Shrink Eligibility" "$SECTION_3B" ;;
  all)
    run_query "SECTION 1: Drive Space" "$SECTION_1"
    run_query "SECTION 2: Backup Health" "$SECTION_2"
    run_query "SECTION 3a: Log File Sizes" "$SECTION_3A"
    run_query "SECTION 3b: Log Shrink Eligibility" "$SECTION_3B"
    ;;
  *)
    echo "Unknown section: $SECTION"
    echo "Use: 1 | 2 | 3a | 3b | all"
    exit 1
    ;;
esac

echo ""
echo "Done."
