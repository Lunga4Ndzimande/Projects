#!/usr/bin/env bash
# =============================================================================
# Offsite S3 Backup Verification — demo companion to SQL assessment
# =============================================================================
# Server:  ew1d-mssql-01 (non-prod)
# Bucket:  ksys-ew1d-general-dbbackup
#
# Usage:
#   ./run_s3_backup_demo.sh              # full demo
#   ./run_s3_backup_demo.sh list         # list backup buckets only
#   ./run_s3_backup_demo.sh objects      # sample objects + storage class
#   ./run_s3_backup_demo.sh lifecycle    # lifecycle / tiering rules
#   ./run_s3_backup_demo.sh browse      # folder structure
#
# Requires: aws CLI configured (aws configure or exported session credentials)
# =============================================================================

set -euo pipefail

BUCKET_EW1D="ksys-ew1d-general-dbbackup"
BUCKET_EW1D_RDS="ksys-ew1d-ip-rds-dbbackup"
BUCKET_EW1R="ksys-ew1r-general-dbbackup"
STEP="${1:-all}"

header() {
  echo ""
  echo "================================================================"
  echo "  $1"
  echo "================================================================"
}

list_buckets() {
  header "Backup buckets (dbbackup)"
  aws s3api list-buckets \
    --query "Buckets[?contains(Name, 'dbbackup')].Name" \
    --output table
  echo ""
  echo "  ew1d-general-dbbackup  → non-prod on-prem SQL (ew1d-mssql-01)"
  echo "  ew1d-ip-rds-dbbackup   → non-prod AWS RDS backups"
  echo "  ew1r-general-dbbackup  → production general DB backups"
}

sample_objects() {
  header "Sample objects — $BUCKET_EW1D (storage class)"
  aws s3api list-objects-v2 \
    --bucket "$BUCKET_EW1D" \
    --max-items 5 \
    --query "Contents[].{Key:Key,StorageClass:StorageClass,SizeMB:Size,LastModified:LastModified}" \
    --output table
  echo ""
  echo "  INTELLIGENT_TIERING = AWS auto-moves old backups to cheaper tiers"
  echo "  (blank StorageClass) = STANDARD"
}

lifecycle_rules() {
  header "Lifecycle / Intelligent-Tiering — $BUCKET_EW1D"
  if aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_EW1D" 2>/dev/null; then
    :
  else
    echo "  No lifecycle configuration (or no permission). Trying Intelligent-Tiering config..."
    aws s3api list-bucket-intelligent-tiering-configurations \
      --bucket "$BUCKET_EW1D" 2>/dev/null || echo "  No Intelligent-Tiering bucket config returned."
  fi
}

browse_structure() {
  header "Folder structure — s3://$BUCKET_EW1D/ (first 20 objects)"
  aws s3 ls "s3://${BUCKET_EW1D}/" --recursive | head -20
  echo ""
  echo "  Compare with on-prem path: M:\\SQL\\Backup\\ew1d-mssql-01\\{DatabaseName}\\{BackupType}\\"
}

case "$STEP" in
  list)      list_buckets ;;
  objects)   sample_objects ;;
  lifecycle) lifecycle_rules ;;
  browse)    browse_structure ;;
  all)
    list_buckets
    sample_objects
    lifecycle_rules
    browse_structure
    ;;
  *)
    echo "Unknown step: $STEP"
    echo "Use: list | objects | lifecycle | browse | all"
    exit 1
    ;;
esac

echo ""
echo "Done."
