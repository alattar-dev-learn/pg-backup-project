#!/bin/bash
set -e

mkdir -p /backups/pgbackrest /backups/logs /backups/wal_archive

chown -R postgres:postgres /backups
chmod 750 /backups/pgbackrest /backups/logs

service cron start

exec docker-entrypoint.sh "$@" -c config_file=/etc/postgresql/postgresql.conf
