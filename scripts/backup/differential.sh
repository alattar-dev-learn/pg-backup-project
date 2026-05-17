#!/bin/bash
export MSYS_NO_PATHCONV=1
set -euo pipefail
trap 'echo "[ERROR] Differential backup FAILED at: $(date)"; exit 1' ERR

pgbackrest --stanza=main backup --type=diff

echo "[SUCCESS] Differential backup completed at: $(date)"
