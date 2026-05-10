#!/bin/bash
set -euo pipefail

MAX_AGE_HOURS=25
ALERT_MARKER="[ALERT]"
LOG_PREFIX="[HEALTH CHECK] $(date +%F_%H-%M-%S)"

# Get latest backup stop time via JSON output
LAST_BACKUP=$(pgbackrest --stanza=main info --output=json | jq -r '.[] | .backup[-1].timestamp.stop | if . then (. | todate) else "" end' 2>/dev/null)

if [ -z "$LAST_BACKUP" ]; then
    echo "$LOG_PREFIX $ALERT_MARKER No backups found in repository!"
    exit 1
fi

LAST_EPOCH=$(date -d "$LAST_BACKUP" +%s)
NOW_EPOCH=$(date +%s)
AGE_HOURS=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))

if [ "$AGE_HOURS" -ge "$MAX_AGE_HOURS" ]; then
    echo "$LOG_PREFIX $ALERT_MARKER Last backup was ${AGE_HOURS}h ago (limit: ${MAX_AGE_HOURS}h). Last backup: $LAST_BACKUP"
    exit 1
else
    echo "$LOG_PREFIX [OK] Last backup was ${AGE_HOURS}h ago. Last backup: $LAST_BACKUP"
fi
