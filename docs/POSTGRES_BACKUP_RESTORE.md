# PostgreSQL Backup and Restore

This setup creates a daily custom-format PostgreSQL dump, verifies it locally and after upload, keeps 14 days on the VPS, and retains 90 days in a private Cloudflare R2 bucket. The timer is scheduled for 02:17 UTC with up to 15 minutes of jitter.

The backup service runs as `atlas`. It reads only `DATABASE_URL` from `fittrack.env`; R2 credentials live in the mode-600 rclone config and are never stored in Git. Database passwords are written only to a temporary mode-600 pgpass file while `pg_dump` or `pg_restore` runs. Restore refuses the configured production database and refuses any target containing user relations.

This covers PostgreSQL only. Cached exercise media under `/opt/fittrack/storage/exercise_media` needs a separate file backup policy.

## One-Time Setup

1. Create a private R2 bucket named `fittrack-backups`. Create an API token scoped to that bucket with object read, write, list, and delete permissions. Delete permission is needed for remote retention.
2. Install `rclone` on the VPS. This host uses `/home/atlas/.local/bin/rclone`; the systemd unit includes that directory in `PATH`.
3. As `atlas`, run `rclone config` and create a remote named `r2` with the S3 storage type and provider `Cloudflare` (case-sensitive). Enter the R2 access key ID, secret access key, and endpoint (`https://<account-id>.r2.cloudflarestorage.com`) directly into the interactive terminal prompts; use region `auto`. Do not put credentials on a command line or in chat. If using a bucket-scoped Object Read & Write token, set `no_check_bucket = true` because the bucket already exists. Then protect the config file:

   ```sh
   chmod 600 /home/atlas/.config/rclone/rclone.conf
   rclone listremotes
   ```

   Confirm the VPS can list, write, read, and delete a temporary object in the bucket:

   ```sh
   rclone lsf r2:fittrack-backups
   test_object="r2:fittrack-backups/.fittrack-write-test-$(date +%s)"
   printf 'FitTrack R2 write test\n' | rclone rcat "$test_object"
   rclone cat "$test_object"
   rclone deletefile "$test_object"
   ```

4. Create the local backup directory with restrictive permissions:

   ```sh
   sudo install -d -o atlas -g atlas -m 700 /opt/fittrack/backups/postgres
   ```

5. Install the backup units and reload systemd:

   ```sh
   sudo install -m 644 ops/systemd/fittrack-db-backup.service /etc/systemd/system/fittrack-db-backup.service
   sudo install -m 644 ops/systemd/fittrack-db-backup.timer /etc/systemd/system/fittrack-db-backup.timer
   sudo systemctl daemon-reload
   ```

6. Run the first backup now and inspect its result:

   ```sh
   sudo systemctl start fittrack-db-backup.service
   systemctl status fittrack-db-backup.service --no-pager
   journalctl -u fittrack-db-backup.service -n 80 --no-pager
   ```

   A successful run logs `Backup uploaded and verified`. Confirm the compressed custom-format dump and checksum exist in `/opt/fittrack/backups/postgres` and in `r2:fittrack-backups/postgres/`.

7. Complete Restore Verification below. Only after the restore checks pass and the temporary database is removed, enable the daily timer:

   ```sh
   sudo systemctl enable --now fittrack-db-backup.timer
   systemctl list-timers fittrack-db-backup.timer --no-pager
   ```

   `Persistent=true` can trigger a missed backup immediately on activation. The next scheduled run should be between 02:17 and 02:32 UTC.

## Restore Verification

The `restore-verify` command selects the newest dump in R2, downloads its checksum sidecar, verifies both the SHA-256 and PostgreSQL archive listing, and restores into a uniquely named temporary database. It uses a dedicated non-production role with `CREATEDB`, checks that `schema_migrations`, `users`, and `exercise_templates` exist and that migrations are present, then drops only the database it created, including when verification fails.

As `atlas`, create `/home/atlas/.config/fittrack/restore-db.env` with mode `600`. The URL must connect as the dedicated test role to the maintenance database `postgres`, not to `fittrack_prod`:

```text
FITTRACK_RESTORE_DATABASE_URL=ecto://fittrack_test_user:URL_ENCODED_PASSWORD@127.0.0.1/postgres
```

Use URL encoding for special characters in the password. Keep this file private and do not source it together with `fittrack.env` or paste its contents into chat.

After a first backup has succeeded and been verified, install the manual restore-verification unit (do not add a timer unless a separate cadence is chosen):

```sh
sudo install -m 644 ops/systemd/fittrack-db-restore-verify.service /etc/systemd/system/fittrack-db-restore-verify.service
sudo systemctl daemon-reload
sudo systemctl start fittrack-db-restore-verify.service
systemctl status fittrack-db-restore-verify.service --no-pager
journalctl -u fittrack-db-restore-verify.service -n 100 --no-pager
```

The restore-verification role must have permission to create/drop databases. Never configure it with the production `fittrack` role or target `fittrack_prod`. If cleanup fails, the journal will include the generated temporary database name so it can be removed after checking that name carefully.

## Production Operations

Systemd manages `fittrack.service`, `caddy.service`, `postgresql.service`, and `fittrack-db-backup.timer`. The application, reverse proxy, database, and backup timer should all be enabled at boot. Inspect their status with:

```sh
systemctl is-enabled fittrack caddy postgresql fittrack-db-backup.timer
systemctl status fittrack caddy postgresql fittrack-db-backup.timer --no-pager
systemctl list-timers fittrack-db-backup.timer --no-pager
```

Run `./deploy.sh` as `atlas`. It builds the release, applies migrations, and calls `sudo systemctl restart fittrack`; the deploying user needs sudo permission for that command. Systemd remains the process manager. `--skip-restart` builds without restarting the application. Check the application journal and local endpoint after deployment; the script also performs these checks.

Periodically inspect the backup service journal for `Backup uploaded and verified`, check the timer's last and next runs, and rerun the restore-verification command above. Successful oneshot services normally become `inactive (dead)` with `Result=success`; inactivity alone does not indicate failure. The restore check proves archive readability, required table presence, and a nonzero migration count, but does not exercise every application query or validate every row.

Backups are stored locally in `/opt/fittrack/backups/postgres` and remotely in the private R2 bucket `fittrack-backups`, prefix `postgres/`, using rclone remote `r2`. Protect the application environment, restore environment, and rclone configuration; never include their contents in logs, tickets, or Git.

A reboot test remains a planned maintenance task. During an agreed maintenance window, reboot the VPS and run the service checks above after reconnecting. Confirm the application responds through Caddy and rerun restore verification. Do not count enabled units alone as proof that a reboot test passed.

## Recovery

1. Select a known-good dump and its matching `.sha256` sidecar from R2. Download both with `rclone copyto` into a private directory. Preserve existing backups and the damaged database while investigating.
2. Provision a separate, empty recovery database with appropriate ownership. Run `python3 scripts/postgres_backup.py restore /path/to/fittrack-TIMESTAMP.dump` with `FITTRACK_RESTORE_DATABASE` set to that database and `DATABASE_URL` supplied privately for the connecting role. The helper refuses the production database and nonempty targets; it does not create the target database.
3. Validate migrations, required tables, and application data in the recovered database. Use restore verification to confirm the newest R2 archive independently, but use the selected recovery dump for the actual recovery.
4. During a maintenance window, stop `fittrack.service`, privately update the production database connection to the validated recovery database, and start `fittrack.service` through systemd. Check the journal, local endpoint, and public site. Retain the previous database for investigation or rollback.
5. Confirm a fresh backup and restore verification succeed after recovery. Exercise media and other server configuration require their own recovery copies; this database backup does not cover them.
