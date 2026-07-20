#!/usr/bin/env bash
# Daily pg_dump backup with N-day rotation for the recurya production DB.
# Intended to run from the compose project directory via host cron, e.g.:
#   0 4 * * * cd /opt/recurya && ./scripts/backup-db.sh >> backups/backup.log 2>&1
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.prod}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Pull DB/user from the env file if present (POSTGRES_DB / POSTGRES_USER).
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a; . "$ENV_FILE"; set +a
fi
DB="${POSTGRES_DB:-recurya}"
USER="${POSTGRES_USER:-postgres}"

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/recurya-$STAMP.sql.gz"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U "$USER" -d "$DB" | gzip > "$OUT"

echo "backup written: $OUT"

# Rotate: delete dumps older than KEEP_DAYS.
find "$BACKUP_DIR" -name 'recurya-*.sql.gz' -type f -mtime +"$KEEP_DAYS" -delete
