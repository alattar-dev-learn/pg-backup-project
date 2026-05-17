#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Restore FAILED at: $(date)"; exit 1' ERR

BACKUP_SET=${1:-}

pgbackrest --stanza=main restore --delta ${BACKUP_SET:+--set="$BACKUP_SET"}

echo "[SUCCESS] Restore complete at: $(date)"
