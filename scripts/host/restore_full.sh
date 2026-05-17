#!/bin/bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

BACKUP_SET=${1:-}

echo "[INFO] Stopping PostgreSQL..."
docker compose stop postgres

echo "[INFO] Running restore inside container..."
docker compose run --rm -u postgres --entrypoint /scripts/restore/full.sh postgres ${BACKUP_SET:+"$BACKUP_SET"}

echo "[INFO] Starting PostgreSQL..."
docker compose start postgres

echo "[SUCCESS] Restore complete and PostgreSQL is back online at: $(date)"
