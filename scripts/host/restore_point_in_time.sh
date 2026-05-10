#!/bin/bash
set -euo pipefail

TARGET_TIME=${1:-}

if [ -z "$TARGET_TIME" ]; then
    echo "Usage: $0 \"YYYY-MM-DD HH:MM:SS\""
    echo "Example: $0 \"2026-05-10 14:59:50\""
    exit 1
fi

echo "[INFO] Stopping PostgreSQL..."
docker compose stop postgres

echo "[INFO] Running point-in-time recovery inside container..."
docker compose run --rm -u postgres --entrypoint /scripts/restore/point_in_time.sh postgres "$TARGET_TIME"

echo "[INFO] Starting PostgreSQL..."
docker compose start postgres

echo "[SUCCESS] Recovery to '$TARGET_TIME' complete and PostgreSQL is back online at: $(date)"
