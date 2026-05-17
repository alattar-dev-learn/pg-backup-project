#!/bin/bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

TARGET_TIME=${1:-}

echo "[INFO] Stopping PostgreSQL..."
docker compose stop postgres

echo "[INFO] Running point-in-time recovery inside container..."
docker compose run --rm -u postgres --entrypoint /scripts/restore/point_in_time.sh postgres "$TARGET_TIME"

echo "[INFO] Starting PostgreSQL..."
docker compose start postgres

echo "[SUCCESS] Recovery to '$TARGET_TIME' complete and PostgreSQL is back online at: $(date)"
