# Technical Report: PostgreSQL Backup & Recovery System

## 1. Introduction

### What Is a Database Backup?

A database backup is a copy of the data stored in a database, taken at a specific point in time, so that it can be used to restore the database in the event of data loss. Backup systems can capture the full state of the database, or just the changes that happened since the last backup, depending on the strategy used.

### Why Does It Matter?

Data is one of the most valuable assets in any software system. Without a proper backup strategy, a single failure — a corrupted disk, a bad deployment, an accidental `DELETE` without a `WHERE` clause — can cause permanent, irreversible data loss.

Backup systems protect against:

- **Hardware failure** — disks die, servers crash
- **Human error** — accidental deletion or modification of data
- **Software bugs** — a bad migration or a flawed deploy corrupting data
- **Security incidents** — ransomware can encrypt or delete entire databases

In production systems, databases are typically backed up continuously, with the ability to restore to any point in time. This project implements exactly that kind of system for a PostgreSQL database.

---

## 2. Backup Strategy

### The Two Backup Types Used

This project uses a combination of two backup types:

**Full Backup**  
A complete snapshot of the entire database at a given moment. It is self-contained — to restore from it, no other backup is needed.

**Differential Backup**  
A backup of everything that has changed since the last full backup. It is smaller and faster to take than a full backup. To restore from a differential backup, you need the most recent full backup plus the differential.

### Why This Combination?

| Criteria           | Full Only       | Differential Strategy     |
| ------------------ | --------------- | ------------------------- |
| Backup size        | Large every day | Small daily, large weekly |
| Backup speed       | Slow every day  | Fast daily, slow weekly   |
| Restore complexity | Simple          | Requires full + diff      |
| Storage efficiency | Poor            | Good                      |

A pure full-backup-every-day approach wastes storage and takes too long. A differential strategy gives a good balance: one complete baseline per week, and small incremental captures every day. In the worst case, restoring requires only two backup sets — the last full and the last differential.

### WAL Archiving (Point-in-Time Recovery)

In addition to full and differential backups, the system continuously archives **WAL (Write-Ahead Log)** files. WAL is PostgreSQL's internal transaction log — every change to the database is first written to WAL before being applied to the data files. By archiving WAL files continuously, it is possible to replay the transaction log from any backup to any specific moment in time. This is called **Point-in-Time Recovery (PITR)**.

This means the system can restore the database to the exact state it was in at, say, `2026-05-10 14:59:50` — one second before a bad `DROP TABLE` was executed.

---

## 3. Tools & Technologies

| Tool               | Role                                                |
| ------------------ | --------------------------------------------------- |
| **PostgreSQL 15**  | The database engine being backed up                 |
| **pgBackRest**     | The backup and restore tool                         |
| **Docker**         | Containerizes the entire system for reproducibility |
| **Docker Compose** | Orchestrates the PostgreSQL and pgAdmin containers  |
| **cron**           | Schedules automated backups inside the container    |
| **pgAdmin 4**      | Web-based GUI for interacting with the database     |
| **LZ4**            | Compression algorithm used for backup files         |

---

## 4. Implementation

### Step 1: Define the Docker Environment

The project uses a custom `Dockerfile` built on top of the official `postgres:15` image. On top of the base image, two packages are installed: `cron` and `pgbackrest`.

```dockerfile
FROM postgres:15

RUN apt-get update \
    && apt-get install -y --no-install-recommends cron pgbackrest \
    && rm -rf /var/lib/apt/lists/*
```

Docker Compose defines two services: `postgres` (the main container) and `pgadmin` (the web UI). The `backups/` directory on the host is mounted into the container at `/backups`, so all backup files are persisted on the host even if the container is recreated.

```yaml
services:
  postgres:
    build: .
    container_name: pg_backup_db
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./backups:/backups
```

### Step 2: Configure PostgreSQL for WAL Archiving

PostgreSQL must be configured to archive WAL files. The key settings in `postgresql.conf` are:

```
wal_level = replica          # enables full WAL logging needed for archiving
archive_mode = on            # turns on WAL archiving
archive_command = '...'      # the command pgBackRest uses to archive each WAL file
```

With `archive_mode = on`, PostgreSQL calls the `archive_command` for every WAL segment it finishes writing. pgBackRest intercepts this command and stores the WAL file in its repository.

### Step 3: Configure pgBackRest

pgBackRest is configured via `/etc/pgbackrest/pgbackrest.conf`. The configuration defines where backups are stored, how long to keep them, what compression to use, and where PostgreSQL's data directory is.

```ini
[global]
repo1-path=/backups/pgbackrest
repo1-retention-full=2        # keep the last 2 full backups
repo1-retention-diff=14       # keep the last 14 differential backups
compress-type=lz4

[main]
pg1-path=/var/lib/postgresql/data
pg1-user=admin
```

The retention settings mean the system always keeps at least two weeks of history (2 full backups × 7 days) and up to 14 differential backups.

### Step 4: Initialize the pgBackRest Stanza

A "stanza" in pgBackRest is the configuration block for a specific PostgreSQL cluster. Before the first backup can run, the stanza must be created — this sets up the repository structure on disk. This is done automatically on the first container start via an `initdb.d` script:

```bash
# 02_stanza_create.sh (runs once after initdb)
pgbackrest --stanza=main stanza-create
```

### Step 5: Create the Sample Database

A sample "Online Shop" database is initialized automatically using `01_init.sql`. It contains three tables — `users`, `products`, and `orders` — with sample data, giving the backup system real data to protect.

```sql
CREATE TABLE users   (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(150), ...);
CREATE TABLE products(id SERIAL PRIMARY KEY, name VARCHAR(150), price NUMERIC(10,2), ...);
CREATE TABLE orders  (id SERIAL PRIMARY KEY, user_id INT, product_id INT, quantity INT, ...);
```

### Step 6: Write the Backup Scripts

Two Shell scripts handle backup execution:

**Full backup** (`scripts/backup/full.sh`):
```bash
pgbackrest --stanza=main backup --type=full
```

**Differential backup** (`scripts/backup/differential.sh`):
```bash
pgbackrest --stanza=main backup --type=diff
```

Both scripts use `set -euo pipefail` and an `ERR` trap to ensure failures are logged clearly and the script exits with a non-zero code so cron can detect them.

### Step 7: Set Up the Cron Schedule

The `cron.d/pg-backup` file defines the automated schedule. It is copied into the container and loaded by the system cron daemon:

```cron
# Full backup every Friday at 2AM
0 2 * * 5 postgres /scripts/backup/full.sh >> /backups/logs/backup.log 2>&1

# Differential backup Saturday–Thursday at 2AM
0 2 * * 0-4,6 postgres /scripts/backup/differential.sh >> /backups/logs/backup.log 2>&1

# Health check every hour
0 * * * * postgres /scripts/maintenance/health_check.sh >> /backups/logs/health.log 2>&1
```

All output is appended to log files in `/backups/logs/`, which are accessible on the host via the mounted volume.

### Step 8: Implement Health Monitoring

A health check script runs every hour. It reads the timestamp of the last backup via pgBackRest's JSON output and alerts if no backup has been taken in more than 25 hours:

```bash
AGE_HOURS=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))

if [ "$AGE_HOURS" -ge 25 ]; then
    echo "[ALERT] Last backup was ${AGE_HOURS}h ago!"
fi
```

The 25-hour threshold is chosen to be slightly greater than 24 hours, giving the daily backup job a small grace window before raising an alert.

### Step 9: Implement the Entrypoint

A custom entrypoint script (`scripts/docker/entrypoint.sh`) runs when the container starts. It:

1. Creates required directories (`/backups/pgbackrest`, `/backups/logs`)
2. Sets correct ownership for the `postgres` user
3. Verifies the pgBackRest stanza is healthy (on restarts)
4. Starts the cron daemon
5. Hands off to the standard PostgreSQL entrypoint

```bash
mkdir -p /backups/pgbackrest /backups/logs /backups/wal_archive
chown -R postgres:postgres /backups
service cron start
exec docker-entrypoint.sh "$@" -c config_file=/etc/postgresql/postgresql.conf
```

---

## 5. Backup Schedule

### The Schedule

| Day        | Time        | Type                | Rationale                      |
| ---------- | ----------- | ------------------- | ------------------------------ |
| Friday     | 2:00 AM     | Full backup         | Weekly baseline                |
| Sat – Thu  | 2:00 AM     | Differential backup | Daily incremental changes      |
| Every hour | On the hour | Health check        | Early failure detection        |
| Continuous | —           | WAL archiving       | Enables point-in-time recovery |

---

## 6. Restore Demo

This section walks through the two restore scenarios the system supports.

### Scenario A: Full Restore (Latest Backup)

This is used when the database needs to be restored to the state of the most recent backup — for example after a hardware failure.

**Step 1:** Check what backups are available.

```bash
docker exec -u postgres pg_backup_db pgbackrest info
```

Example output:
```
stanza: main
    status: ok
    cipher: none

    db (current)
        wal archive min/max (15): 000000010000000000000001/000000010000000000000007

        full backup: 20260510-084258F
            timestamp start/stop: 2026-05-10 08:42:58+00 / 2026-05-10 08:43:03+00
            wal start/stop: 000000010000000000000006 / 000000010000000000000006
            database size: 29.5MB, database backup size: 29.5MB
            repo1: backup size: 5.8MB
```

**Step 2:** Run the restore script from the host.

```bash
./scripts/host/restore_full.sh
```

The script stops the PostgreSQL container, runs `pgbackrest restore` inside a temporary container instance, then restarts PostgreSQL. pgBackRest handles clearing the data directory and writing all files from the backup.

### Scenario B: Point-in-Time Recovery

This is used when the database must be restored to a specific moment — for example, right before a bad `DELETE` statement was executed.

**Step 1:** Identify the target time. In this demo, the goal is to recover to `2026-05-10 14:59:50` — one second before a table was accidentally deleted.

**Step 2:** Run the PITR restore script.

```bash
./scripts/host/restore_point_in_time.sh "2026-05-10 14:59:50"
```

Internally, this command runs:
```bash
pgbackrest --stanza=main restore --target="2026-05-10 14:59:50" --target-action=promote
```

pgBackRest:
1. Restores the most recent full backup taken before the target time
2. Replays archived WAL files, applying transactions one by one, stopping at the target timestamp
3. Promotes the database to a writable state

**Step 3:** Verify the recovered state.

```bash
docker exec -u postgres pg_backup_db psql -U admin -d shop -c "\dt"
```

All tables that existed at `14:59:50` will be present. Any changes made after that timestamp — including the accidental truncation — will not be present.
