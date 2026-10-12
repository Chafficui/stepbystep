#!/usr/bin/env bash
# Backup script for the stepbystep deployment.
#
# Usage: run on the VPS from the repo root:  ./scripts/backup.sh
# Reads POSTGRES_USER / POSTGRES_DB from deploy/.env.
#
# Creates one dated archive per run containing the database dump (db.sql)
# and the contents of the uploads volume. Keeps the newest 72 archives
# (enough for hourly runs over 3 days); older ones are deleted.
#
# Run hourly via cron, e.g.:
#   0 * * * * cd /opt/stepbystep && ./scripts/backup.sh >> /var/log/stepbystep-backup.log 2>&1
# Copy the newest archive off-site, e.g.:
#   rsync -a --delete /var/backups/stepbystep/ backup@offsite:/backups/stepbystep/

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/stepbystep}"
COMPOSE_FILE="deploy/docker-compose.yml"
ENV_FILE="deploy/.env"
KEEP=72

cd "$(dirname "$0")/.."

# Fail loudly if prerequisites are missing.
command -v docker >/dev/null || { echo "ERROR: docker not found" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: 'docker compose' plugin not available" >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE not found" >&2; exit 1; }
# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a
: "${POSTGRES_USER:?POSTGRES_USER not set in $ENV_FILE}"
: "${POSTGRES_DB:?POSTGRES_DB not set in $ENV_FILE}"

docker compose -f "$COMPOSE_FILE" ps --status running db >/dev/null 2>&1 \
  || { echo "ERROR: db service is not running (docker compose -f $COMPOSE_FILE ps)" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y-%m-%dT%H%M)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Dumping database $POSTGRES_DB ..."
docker compose -f "$COMPOSE_FILE" exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$TMP_DIR/db.sql"

echo "Copying uploads volume ..."
# The uploads volume is mounted at /data/uploads inside the api container.
mkdir -p "$TMP_DIR/uploads"
docker compose -f "$COMPOSE_FILE" exec -T api sh -c 'mkdir -p /data/uploads && tar -C /data/uploads -cf - .' | tar -C "$TMP_DIR/uploads" -xf -

ARCHIVE="$BACKUP_DIR/stepbystep-backup-$STAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$TMP_DIR" db.sql uploads
echo "Created $ARCHIVE"

# Keep only the newest $KEEP archives.
ls -1t "$BACKUP_DIR"/stepbystep-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
  echo "Deleting old backup: $old"
  rm -f -- "$old"
done
