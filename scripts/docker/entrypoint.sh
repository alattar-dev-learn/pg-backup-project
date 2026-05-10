#!/bin/bash
set -e

mkdir -p /backups/pgbackrest /backups/logs /backups/wal_archive

chown -R postgres:postgres /backups
chmod 750 /backups/pgbackrest /backups/logs

if [ -f "/var/lib/postgresql/data/global/pg_control" ]; then
    if ! su -s /bin/bash postgres -c "pgbackrest --stanza=main info" > /dev/null 2>&1; then
        echo "[ERROR] pgBackRest stanza is missing or broken."
        echo "[ERROR] Fix it by running: docker exec <container> /docker-entrypoint-initdb.d/02_stanza_create.sh"
        exit 1
    fi
fi

service cron start

exec docker-entrypoint.sh "$@" -c config_file=/etc/postgresql/postgresql.conf
