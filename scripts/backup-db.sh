#!/usr/bin/env bash
# Daily pg_dump backup with N-day rotation for the recurya production DB.
# Intended to run from the compose project directory via host cron, e.g.:
#   0 4 * * * cd /opt/recurya && ./scripts/backup-db.sh >> backups/backup.log 2>&1
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.prod}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Pull DB/user from the env file if present. Extract only the keys we need
# instead of sourcing the file, so a password containing shell metacharacters
# cannot break parsing or execute code in this context.
read_env() { [ -f "$ENV_FILE" ] && grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true; }
DB="${POSTGRES_DB:-$(read_env POSTGRES_DB)}"; DB="${DB:-recurya}"
USER="${POSTGRES_USER:-$(read_env POSTGRES_USER)}"; USER="${USER:-postgres}"

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/recurya-$STAMP.sql.gz"

# Dump to a temp file and rename on success, so a failed dump never leaves a
# truncated file that looks like a valid backup (and survives rotation).
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U "$USER" -d "$DB" | gzip > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

echo "backup written: $OUT"

# Rotate: delete dumps older than KEEP_DAYS.
find "$BACKUP_DIR" -name 'recurya-*.sql.gz' -type f -mtime +"$KEEP_DAYS" -delete
