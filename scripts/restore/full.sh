#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Restore FAILED at: $(date)"; exit 1' ERR

if pg_ctl status -D "$PGDATA" > /dev/null 2>&1; then
    echo "[ERROR] PostgreSQL is still running. Use ./restore_full.sh from the project root."
    exit 1
fi

BACKUP_SET=${1:-}

# --delta: only restores files that differ (faster than a full file copy)
pgbackrest --stanza=main restore --delta ${BACKUP_SET:+--set="$BACKUP_SET"}

echo "[SUCCESS] Restore complete at: $(date)"
