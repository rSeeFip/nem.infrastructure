# PostgreSQL 16 physical backup automation

This source package defines a credential-free, daily full physical backup for the PostgreSQL 16 primary on `sendo@192.168.1.85`. It is not installed by this change. The production namespace is exclusively:

`/mnt/nvme-ssd/postgres-backups/automated`

Existing manual backups (`20260925T150123Z`, `20260926T070647Z`), `postgres-recovery-tests`, AGE exports, and every path outside that namespace are out of scope and are never scanned or modified.

## Guarantees and boundaries

- Runs as OS user/group `postgres` and connects through the local Unix socket using peer authentication. There is no password, `.pgpass`, HBA change, replication role, or TCP connection.
- Uses PostgreSQL 16 `pg_basebackup -Fp -X stream`, SHA-256 backup manifests, a `32M` maximum transfer rate, spread checkpoints, and default fsync behavior.
- Runs `pg_verifybackup` before recording the backup-manifest SHA-256 or publication. A run becomes visible only after an atomic rename from `.basebackup-<UTC>.inprogress` to `basebackup-<UTC>`.
- Writes `COMPLETED`, an ownership marker, and exact verifier metadata only after support capture and verification succeed. State metadata is written with temporary-file plus atomic rename.
- Rejects a standby, a server not using the expected PGDATA, a non-16 server, external tablespaces, unreadable external configuration, a missing/wrong mount, symlinks in security-sensitive paths, wrong ownership/modes, overlap, and insufficient capacity.
- Requires free space equal to the greater of `PGDATA + 64 GiB` and `2 × PGDATA` before a backup and in hourly health checks.
- Captures the complete canonical `/etc/postgresql/16/main` directory tree after rejecting symlinks, special files, cross-filesystem entries, configuration parse errors, and active PostgreSQL/HBA/ident sources or HBA `@file` references outside that tree. Filesystem, SQL-source, database, and retention producers are materialized into private mode-`0600` inventories and their exit status is checked before consumption; the same checked tree inventory drives validation and copying. It also captures non-secret database/role/extension/server-setting inventories, `pg_controldata`, and PostgreSQL binary version. Role password hashes and database contents are not logged.
- Production uses the fixed path `/usr/lib/postgresql/16/bin:/usr/sbin:/usr/bin:/sbin:/bin` and rejects unexpected `NEM_BACKUP_*` overrides. Every PostgreSQL client/control binary must report major version 16 before backup activity.
- The service has a six-hour start timeout, five-minute graceful stop window, control-group termination, two-CPU quota, 2 GiB memory limit, idle I/O scheduling, low I/O weight, a strict read-only filesystem except for the dedicated backup namespace, no capabilities, and only Unix-domain sockets.
- Failures are represented by systemd service failure, local critical-priority journal output through `OnFailure`, and atomic `last-failure.json` when the validated state directory is available. No external alert recipient is invented.

This is a local-disk recovery control, not disaster recovery. The backup resides on the same host and physical NVMe device as the primary data. Off-host/offsite replication remains pending. This package does not configure WAL archiving and makes no point-in-time-recovery claim.

## Publication and retention model

Private runtime files are mode `0600`; run and state directories are mode `0700`. Installation makes scripts root-owned and non-writable by `postgres`, while the dedicated backup root is owned by `postgres`.

Overlap protection locks an open, validated `.state` directory descriptor. It never creates, truncates, follows, or trusts a legacy lock-file path. An inherited descriptor is reused only when its device and inode still match the validated state directory, and every path—including a matching inherited descriptor—must successfully acquire the nonblocking flock.

Retention keeps seven verified successful runs in this namespace. It considers only canonical mode-`0700` immediate children named `basebackup-YYYYMMDDTHHMMSSZ` that are real directories owned by the expected user and contain real data directories, a regular backup manifest matching its post-verification SHA-256 record, and matching regular, non-symlink ownership, completion, and verifier records. Before any pruning, standalone retention runs a fresh full `pg_verifybackup` against the newest retained run. Each eligible deletion is atomically renamed to a unique `.pruning-*` quarantine name and then removed with `--one-file-system`.

| Case | Result |
|---|---|
| Seven or fewer verified runs | Nothing removed |
| More than seven verified runs | Oldest verified excess runs quarantined and removed |
| Manual, unknown, failure, or `.inprogress` path | Ignored and preserved |
| Older malformed run with a newer verified run | Preserved; does not consume a retention slot |
| Lexically latest run malformed/unverified | All pruning refused (last-good guard) |
| Candidate or marker is a symlink | Preserved as ineligible |
| Wrong owner, marker mismatch, missing completion, or bad verifier record | Preserved as ineligible |
| Lock is held | Concurrent invocation fails without mutation |

Routine rotation is authorized only for future backups carrying this namespace's complete ownership and verification contract. There is no global cleanup behavior. `last-success.json` is published only after retention succeeds; a failure timestamp equal to or newer than the last success fails monitoring closed, and a later successful run safely removes the validated failure record. Retention need not delete anything at installation and must not be separately run against production before the first reviewed successful backup.

## Schedule and monitoring

- Backup timer: daily at `02:00 UTC`, up to 30 minutes randomized delay, persistent across downtime.
- Monitor timer: hourly and persistent; detects disabled configuration, missing/malformed/unsafe metadata, a failure newer than the last success, no verified target run, age over 36 hours, wrong mount/root, and inadequate next-run capacity.
- Alerts: local journal only, identifier `postgresql-backup-critical`, priority `crit`.

## Source validation

From this directory, without production access:

```bash
bash tests/run-tests.sh
bash -n bin/*.sh tests/*.sh tests/mocks/*
shellcheck -x bin/*.sh tests/*.sh tests/mocks/*
systemd-analyze verify systemd/*.service systemd/*.timer
```

Tests construct a disposable root and mocked PostgreSQL/system commands. Test overrides require `NEM_BACKUP_TESTING=1`, a canonical `NEM_BACKUP_TEST_ROOT`, and a backup root below it; the production root is explicitly rejected in test mode. Production rejects alternate config paths and ignores all path values from configuration.

## Exact installation plan (execute only after parent review)

Run the following through the already-approved SSH control master. Supply the sudo password only on stdin to `sudo -S`; never place it in a file, argument, environment variable, terminal output, or repository. `<SOURCE>` means this reviewed directory transferred to a temporary host path. Do not use `rsync --delete` anywhere near backup storage.

1. Reconfirm prerequisites with read-only commands:

   ```bash
   sudo -S -u postgres /usr/lib/postgresql/16/bin/psql -XAt -d postgres -c 'select version(), pg_is_in_recovery(), current_setting('"'"'data_directory'"'"')'
   sudo -S -u postgres /usr/lib/postgresql/16/bin/psql -XAt -d postgres -c "select count(*) from pg_tablespace where spcname not in ('pg_default','pg_global')"
   findmnt -T /mnt/nvme-ssd -o TARGET,SOURCE,FSTYPE,OPTIONS
   df -PB1 /mnt/nvme-ssd
   systemctl list-timers --all
   ```

2. Install immutable code/config and create only the new namespace:

   ```bash
   sudo -S install -d -o root -g root -m 0755 /usr/local/libexec/nem-postgresql-backup /etc/nem
   sudo -S install -o root -g root -m 0755 <SOURCE>/bin/common.sh <SOURCE>/bin/config-capture.sh <SOURCE>/bin/backup.sh <SOURCE>/bin/retention.sh <SOURCE>/bin/monitor.sh /usr/local/libexec/nem-postgresql-backup/
   sudo -S install -o root -g root -m 0644 <SOURCE>/postgresql-backup.conf /etc/nem/postgresql-backup.conf
   sudo -S install -d -o postgres -g postgres -m 0700 /mnt/nvme-ssd/postgres-backups/automated
   sudo -S install -o root -g root -m 0644 <SOURCE>/systemd/*.service <SOURCE>/systemd/*.timer /etc/systemd/system/
   sudo -S systemctl daemon-reload
   sudo -S systemd-analyze verify /etc/systemd/system/postgresql-backup*.service /etc/systemd/system/postgresql-backup*.timer
   ```

3. Inspect the installed security posture before any run:

   ```bash
   sudo -S systemctl cat postgresql-backup.service postgresql-backup-monitor.service
   sudo -S systemd-analyze security postgresql-backup.service postgresql-backup-monitor.service
   sudo -S -u postgres test -r /etc/postgresql/16/main/postgresql.conf
   sudo -S -u postgres test -r /etc/postgresql/16/main/pg_hba.conf
   sudo -S -u postgres test -r /etc/postgresql/16/main/pg_ident.conf
   sudo -S -u postgres /usr/lib/postgresql/16/bin/pg_controldata /mnt/nvme-ssd/postgres/main >/dev/null
   ```

4. Perform the separately approved first real run, then inspect without printing database contents or secrets:

   ```bash
   sudo -S systemctl start postgresql-backup.service
   sudo -S systemctl status --no-pager postgresql-backup.service
   sudo -S journalctl -u postgresql-backup.service --since today --no-pager
   sudo -S -u postgres /usr/local/libexec/nem-postgresql-backup/monitor.sh
   sudo -S find /mnt/nvme-ssd/postgres-backups/automated -maxdepth 2 -printf '%M %u:%g %p\n'
   ```

5. Only after the first run and monitor pass, enable future scheduling:

   ```bash
   sudo -S systemctl enable --now postgresql-backup.timer postgresql-backup-monitor.timer
   systemctl list-timers postgresql-backup.timer postgresql-backup-monitor.timer
   ```

## Restore operator runbook

Never restore over the production cluster as a test. Select a completed run referenced by verified metadata, run PostgreSQL 16 `pg_verifybackup` against its `data` directory again, and restore it to a new empty directory on an isolated clone host or isolated recovery instance. Reapply the captured external configuration only after reviewing host-specific paths, ports, TLS material, preload libraries, and authentication rules. Keep networking disabled or isolated until the clone's identity and intended clients are confirmed. Start with the same PostgreSQL 16 major version and required extension libraries, inspect recovery logs, connect locally, compare the captured database/role/extension inventory, and perform application-level checks. The existing isolated 32-database restore proof is evidence for recoverability, but each future backup still requires verification.

Do not automatically upgrade PostgreSQL or extensions during restore. Upgrade is a separate, planned operation after the clone is proven. Do not claim PITR; this is a full-backup restore to the backup's end state.

## Rollback

Rollback disables automation without deleting any backup:

```bash
sudo -S systemctl disable --now postgresql-backup.timer postgresql-backup-monitor.timer
sudo -S rm -f /etc/systemd/system/postgresql-backup.service /etc/systemd/system/postgresql-backup.timer /etc/systemd/system/postgresql-backup-monitor.service /etc/systemd/system/postgresql-backup-monitor.timer /etc/systemd/system/postgresql-backup-critical@.service
sudo -S systemctl daemon-reload
sudo -S rm -rf /usr/local/libexec/nem-postgresql-backup
sudo -S rm -f /etc/nem/postgresql-backup.conf
```

Preserve `/mnt/nvme-ssd/postgres-backups/automated` for operator review. Deleting backup data is not part of rollback.
