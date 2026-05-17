# PostgreSQL Production-Ready Backup Management System

A fully containerized PostgreSQL backup and recovery solution using **pgBackRest**.

## Quick Start

```bash
cp .env.example .env
docker compose up --build
```

---

## Access pgAdmin (GUI)

1. Open: http://localhost:8080
2. Login:
   - Email: `PGADMIN_DEFAULT_EMAIL`
   - Password: `PGADMIN_DEFAULT_PASSWORD`
3. Add a server in pgAdmin:
   - Host: `postgres` (Docker service name)
   - Username: `POSTGRES_USER`
   - Password: `POSTGRES_PASSWORD`

---

## Backup Operations

| #   | Operation                      | Command                                                                     |
| --- | ------------------------------ | --------------------------------------------------------------------------- |
| 1   | Check repository status        | `docker exec -u postgres pg_backup_db pgbackrest info`                      |
| 2   | Full backup                    | `docker exec -u postgres pg_backup_db /scripts/backup/full.sh`              |
| 3   | Differential backup            | `docker exec -u postgres pg_backup_db /scripts/backup/differential.sh`      |
| 4   | Verify integrity (weekly)      | `docker exec -u postgres pg_backup_db /scripts/maintenance/verify.sh`       |
| 5   | Health check (hourly via cron) | `docker exec -u postgres pg_backup_db /scripts/maintenance/health_check.sh` |

---

## Restore Operations

| #   | Operation                      | Command                                                         |
| --- | ------------------------------ | --------------------------------------------------------------- |
| 1   | Full restore (latest backup)   | `./scripts/host/restore_full.sh`                                |
| 2   | Full restore (specific backup) | `./scripts/host/restore_full.sh <BACKUP_LABEL>`                 |
| 3   | Point-in-time recovery         | `./scripts/host/restore_point_in_time.sh "2026-05-10 12:30:45"` |

> For restore #2, run `docker exec -u postgres pg_backup_db pgbackrest info` first to find the backup label.

---

## Monitoring & Alerts

### View Backup Logs

```bash
# Backup activity
tail -f ./backups/logs/main-backup.log

# Expiry/retention activity
tail -f ./backups/logs/main-expire.log

# Restore activity
tail -f ./backups/logs/main-restore.log

# Verify results
tail -f ./backups/logs/main-verify.log
```

### Verify WAL Archiving is Working

WAL files are continuously archived to `/backups/pgbackrest/archive/default/`. Each WAL segment is compressed with lz4.

```bash
ls -lh ./backups/pgbackrest/archive/main/
```

Each WAL file should be ~16MB uncompressed, ~1-2MB compressed.

---

## Automated Cron Schedule

Backups run automatically. No manual intervention needed (unless monitoring for failures).

| Time              | Operation           | Frequency  | Result                  |
| ----------------- | ------------------- | ---------- | ----------------------- |
| Every Fri 2AM     | Full backup         | Weekly     | ~5.8MB backup set       |
| Every Sat–Thu 2AM | Differential backup | 6x/week    | ~1-5MB per day          |
| Every 60 seconds  | WAL archiving       | Continuous | ~1-5MB/hour (automatic) |
| Every hour        | Health check        | Hourly     | Alert if no backup >25h |
