#!/bin/bash

set -e

: "${BACKUP_DIR:=/var/tmp/zammad}"
: "${BACKUP_TIME:=03:00}"
: "${HOLD_DAYS:=10}"

function zammad_backup {
  TIMESTAMP="$(date +'%Y%m%d%H%M%S')"

  echo "${TIMESTAMP} - backing up zammad..."

  # delete old backups
  if [ -d "${BACKUP_DIR}" ] && [ -n "$(ls "${BACKUP_DIR}")" ]; then
    find "${BACKUP_DIR}"/*_zammad_*.gz -type f -mtime +"${HOLD_DAYS}" -delete
  fi

  if [ "${NO_FILE_BACKUP}" != "yes" ]; then
    # tar files
    tar -czf "${BACKUP_DIR}"/"${TIMESTAMP}"_zammad_files.tar.gz /opt/zammad/storage
  fi

  #db backup
  pg_dump --dbname=postgresql://"${POSTGRESQL_USER}:${POSTGRESQL_PASS}@${POSTGRESQL_HOST}:${POSTGRESQL_PORT}/${POSTGRESQL_DB}" | gzip > "${BACKUP_DIR}"/"${TIMESTAMP}"_zammad_db.psql.gz

  echo "backup finished :)"
}

# Wait for BACKUP_TIME before the first run: backing up on container start put a full
# pg_dump + storage tar on top of every restart, exactly when all agents reconnect.
while true; do
  NOW_TIMESTAMP=$(date +%s)
  NEXT_TIMESTAMP=$(date -d "today $BACKUP_TIME" +%s)
  if [ "$NEXT_TIMESTAMP" -le "$NOW_TIMESTAMP" ]; then
    NEXT_TIMESTAMP=$(date -d "tomorrow $BACKUP_TIME" +%s)
  fi
  SLEEP_SECONDS=$((NEXT_TIMESTAMP - NOW_TIMESTAMP))

  echo "sleeping $SLEEP_SECONDS seconds until the next backup run..."

  sleep $SLEEP_SECONDS

  zammad_backup
done
