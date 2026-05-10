FROM postgres:15

# Install cron and pgBackRest
RUN apt-get update \
    && apt-get install -y --no-install-recommends cron pgbackrest \
    && rm -rf /var/lib/apt/lists/*

COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf

# initdb.d/ scripts run automatically after initdb on first boot, in filename order
COPY scripts/docker/initdb.d/01_init.sql /docker-entrypoint-initdb.d/01_init.sql
COPY scripts/docker/initdb.d/02_stanza_create.sh /docker-entrypoint-initdb.d/02_stanza_create.sh

RUN chmod +x /docker-entrypoint-initdb.d/02_stanza_create.sh

COPY scripts/backup/full.sh /scripts/backup/full.sh
COPY scripts/backup/differential.sh /scripts/backup/differential.sh
COPY scripts/restore/full.sh /scripts/restore/full.sh
COPY scripts/restore/point_in_time.sh /scripts/restore/point_in_time.sh
COPY scripts/maintenance/verify.sh /scripts/maintenance/verify.sh
COPY scripts/maintenance/health_check.sh /scripts/maintenance/health_check.sh

RUN chmod +x /scripts/backup/*.sh /scripts/restore/*.sh /scripts/maintenance/*.sh

# Jobs run as the `postgres` OS user so pgBackRest can use peer auth
COPY cron.d/pg-backup /etc/cron.d/pg-backup
RUN chmod 0644 /etc/cron.d/pg-backup

# Entrypoint: prepare directories, create stanza, start cron, then start postgres
COPY scripts/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["postgres"]
