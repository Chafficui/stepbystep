#!/usr/bin/env bash
# Seeds a test event ("Testlauf") plus two teams with fixed join codes
# (TESTAAAA / TESTBBBB) so the app and dashboard can be dry-run against it.
#
# Usage (from the repo root):
#   ./scripts/seed_test_event.sh        # production compose
#   ./scripts/seed_test_event.sh --dev  # dev compose (deploy/docker-compose.dev.yml)
#
# Idempotent: the event row is updated and the teams are upserted by code.
# Team codes use an alphabet without 0/O/1/I to avoid misreading.

set -euo pipefail

cd "$(dirname "$0")/.."

DEV=0
for arg in "$@"; do
  case "$arg" in
    --dev) DEV=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ "$DEV" -eq 1 ]; then
  COMPOSE_FILE="deploy/docker-compose.dev.yml"
  DB_USER=dev
  DB_NAME=stepbystep
else
  COMPOSE_FILE="deploy/docker-compose.yml"
  [ -f deploy/.env ] || { echo "ERROR: deploy/.env not found." >&2; exit 1; }
  # shellcheck disable=SC1091
  DB_USER="$(grep '^POSTGRES_USER=' deploy/.env | cut -d= -f2-)"
  DB_NAME="$(grep '^POSTGRES_DB=' deploy/.env | cut -d= -f2-)"
  : "${DB_USER:?POSTGRES_USER not set in deploy/.env}"
  : "${DB_NAME:?POSTGRES_DB not set in deploy/.env}"
fi

docker compose -f "$COMPOSE_FILE" ps --status running db >/dev/null 2>&1 \
  || { echo "ERROR: db service ($COMPOSE_FILE) is not running." >&2; exit 1; }

# start_time = now + 15 minutes, UTC; reveal_time = now, UTC.
START_TIME="$(date -u -d '+15 minutes' '+%Y-%m-%dT%H:%M:%SZ')"
REVEAL_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

SQL="
INSERT INTO event (id, name, start_time, reveal_time, duration_h, checkin_interval_min, checkin_window_min, silence_alarm_min, speed_flag_kmh, orga_phone)
VALUES (1, 'Testlauf', '${START_TIME}'::timestamptz, '${REVEAL_TIME}'::timestamptz, 24, 300, 30, 360, 12, '+491701234567')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  start_time = EXCLUDED.start_time,
  reveal_time = EXCLUDED.reveal_time,
  duration_h = EXCLUDED.duration_h,
  checkin_interval_min = EXCLUDED.checkin_interval_min,
  checkin_window_min = EXCLUDED.checkin_window_min,
  silence_alarm_min = EXCLUDED.silence_alarm_min,
  speed_flag_kmh = EXCLUDED.speed_flag_kmh,
  orga_phone = EXCLUDED.orga_phone;

INSERT INTO team (code, name) VALUES
  ('TESTAAAA', 'Team Rot'),
  ('TESTBBBB', 'Team Blau')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name;
"

docker compose -f "$COMPOSE_FILE" exec -T db psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL"

echo
echo "Test event seeded:"
echo "  Event:      Testlauf"
echo "  Start (UTC): $START_TIME"
echo "  Join codes: TESTAAAA, TESTBBBB"
