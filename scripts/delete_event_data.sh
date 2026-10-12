#!/usr/bin/env bash
# GDPR cleanup: deletes all event-related data (location points, check-ins,
# alerts, ranking snapshots, participants, teams) and empties the uploads
# volume. The event row itself is kept so the event can be reused.
#
# Usage (from the repo root on the VPS):
#   ./scripts/delete_event_data.sh            # asks for confirmation (type YES)
#   ./scripts/delete_event_data.sh --yes      # skip confirmation
#   ./scripts/delete_event_data.sh --dev      # run against the dev compose
#
# DANGER: irreversible. Back up first (scripts/backup.sh).

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIRMED=0
DEV=0
for arg in "$@"; do
  case "$arg" in
    --yes) CONFIRMED=1 ;;
    --dev) DEV=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ "$DEV" -eq 1 ]; then
  COMPOSE_FILE="deploy/docker-compose.dev.yml"
else
  COMPOSE_FILE="deploy/docker-compose.yml"
fi

# Dev compose uses fixed plain credentials; prod reads them from deploy/.env.
if [ "$DEV" -eq 1 ]; then
  DB_USER=dev
  DB_NAME=stepbystep
else
  [ -f deploy/.env ] || { echo "ERROR: deploy/.env not found." >&2; exit 1; }
  # shellcheck disable=SC1091
  DB_USER="$(grep '^POSTGRES_USER=' deploy/.env | cut -d= -f2-)"
  DB_NAME="$(grep '^POSTGRES_DB=' deploy/.env | cut -d= -f2-)"
  : "${DB_USER:?POSTGRES_USER not set in deploy/.env}"
  : "${DB_NAME:?POSTGRES_DB not set in deploy/.env}"
fi

# Refuse to run against the dev compose unless --dev was given explicitly.
if [ "$DEV" -eq 0 ]; then
  if [ "${DEPLOY_ENV:-}" = "dev" ]; then
    echo "ERROR: DEPLOY_ENV=dev looks like a dev environment; pass --dev to confirm." >&2
    exit 1
  fi
fi

# Sanity check: container must be reachable before asking for confirmation.
if ! docker compose -f "$COMPOSE_FILE" ps --status running db >/dev/null 2>&1; then
  echo "ERROR: db service ($COMPOSE_FILE) is not running." >&2
  exit 1
fi

echo "This will IRREVERSIBLY delete from the database:"
echo "  location_point, checkin, alert, ranking_snapshot, participant, team"
echo "and remove ALL files in the uploads volume."
echo "The event row itself is kept."

if [ "$CONFIRMED" -ne 1 ]; then
  read -r -p "Type YES to continue: " answer
  if [ "$answer" != "YES" ]; then
    echo "Aborted."
    exit 1
  fi
fi

SQL="
BEGIN;
DELETE FROM location_point;
DELETE FROM checkin;
DELETE FROM alert;
DELETE FROM ranking_snapshot;
DELETE FROM participant;
DELETE FROM team;
COMMIT;
"
echo "Deleting rows from tables ..."
docker compose -f "$COMPOSE_FILE" exec -T db psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL"

echo "Removing uploaded files ..."
docker compose -f "$COMPOSE_FILE" exec -T api sh -c 'rm -rf /data/uploads/*'

echo "Done: event data (participants, teams, check-ins, alerts, ranking snapshots,"
echo "location points) and uploaded files were deleted."
