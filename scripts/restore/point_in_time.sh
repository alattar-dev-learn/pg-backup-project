#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Point-in-time recovery FAILED at: $(date)"; exit 1' ERR

if pg_ctl status -D "$PGDATA" > /dev/null 2>&1; then
    echo "[ERROR] PostgreSQL is still running. Use ./restore_point_in_time.sh from the project root."
    exit 1
fi

TARGET_TIME=${1:-}

if [ -z "$TARGET_TIME" ]; then
    echo "Usage: $0 \"YYYY-MM-DD HH:MM:SS\""
    exit 1
fi

pgbackrest --stanza=main restore --delta --type=time --target="$TARGET_TIME" --target-action=promote

echo "[SUCCESS] Recovery to '$TARGET_TIME' complete at: $(date)"
