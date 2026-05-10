#!/bin/bash
set -euo pipefail

pgbackrest --stanza=main verify

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Backup verification completed successfully at $(date)"
else
    echo "[ERROR] Backup Verification FAILED — backup repository may be corrupted!"
    exit 1
fi
