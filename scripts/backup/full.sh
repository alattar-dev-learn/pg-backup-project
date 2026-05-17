#!/bin/bash
export MSYS_NO_PATHCONV=1

set -euo pipefail
trap 'echo "[ERROR] Full backup FAILED at: $(date)"; exit 1' ERR

pgbackrest --stanza=main backup --type=full

echo "[SUCCESS] Full backup completed at: $(date)"
