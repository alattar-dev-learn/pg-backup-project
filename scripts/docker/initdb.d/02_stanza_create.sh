#!/bin/bash
set -e

pgbackrest --stanza=main stanza-create --no-online
echo "[pgBackRest] Stanza created successfully."
