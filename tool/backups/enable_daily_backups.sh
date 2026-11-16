#!/usr/bin/env bash
# Daily Firestore backups for Crown & Blade.
#
# BLAZE PLAN ONLY: scheduled backups and point-in-time recovery are billed
# (backup storage and restore), so Google refuses them on the free Spark plan.
# Run once, by hand, after upgrading the project to Blaze:
#
#   gcloud auth login
#   bash tool/backups/enable_daily_backups.sh            # daily backups only
#   bash tool/backups/enable_daily_backups.sh --pitr     # also turn on PITR
#
# Restore a backup into a NEW database (Firestore cannot restore in place):
#   gcloud firestore backups list --project=barbershop-booking-syste-8a9b8
#   gcloud firestore databases restore --project=barbershop-booking-syste-8a9b8 \
#     --source-backup=projects/barbershop-booking-syste-8a9b8/locations/LOCATION/backups/BACKUP_ID \
#     --destination-database=restored-YYYYMMDD
set -euo pipefail

PROJECT="barbershop-booking-syste-8a9b8"
DATABASE="(default)"

# One backup a day, each kept for 7 days. Re-running fails if a daily
# schedule already exists; list them with:
#   gcloud firestore backups schedules list --project="$PROJECT" --database="$DATABASE"
gcloud firestore backups schedules create \
  --project="$PROJECT" \
  --database="$DATABASE" \
  --recurrence=daily \
  --retention=7d

# Optional: point-in-time recovery (read any version from the last 7 days,
# minute by minute). Adds storage cost on Blaze.
if [[ "${1:-}" == "--pitr" ]]; then
  gcloud firestore databases update \
    --project="$PROJECT" \
    --database="$DATABASE" \
    --enable-pitr
fi

gcloud firestore backups schedules list --project="$PROJECT" --database="$DATABASE"
