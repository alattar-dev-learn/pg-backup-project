#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Point-in-time recovery FAILED at: $(date)"; exit 1' ERR

TARGET_TIME=${1:-}

pgbackrest --stanza=main restore --delta --type=time --target="$TARGET_TIME" --target-action=promote

echo "[SUCCESS] Recovery to '$TARGET_TIME' complete at: $(date)"
