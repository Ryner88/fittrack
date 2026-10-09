#!/usr/bin/env python3
"""Create verified PostgreSQL backups and restore them only to a separate database."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import os
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit

APP_DIR = Path("/home/atlas/apps/fittrack")
DEFAULT_BACKUP_DIR = Path("/opt/fittrack/backups/postgres")


def database_url() -> str:
    raw_url = os.environ.get("DATABASE_URL")
    if raw_url:
        return raw_url

    env_file = Path(
        os.environ.get("FITTRACK_ENV_FILE", str(APP_DIR / "fittrack.env"))
    )
    if not env_file.is_file():
        raise ValueError(f"DATABASE_URL is not set and env file is missing: {env_file}")

    for line in env_file.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator and key.strip() == "DATABASE_URL":
            try:
                fields = shlex.split(value.strip(), comments=False)
            except ValueError as error:
                raise ValueError("DATABASE_URL in env file is malformed") from error
            if len(fields) == 1 and fields[0]:
                return fields[0]
            raise ValueError("DATABASE_URL in env file is empty or malformed")

    raise ValueError(f"DATABASE_URL was not found in env file: {env_file}")


def parse_database_url(
    raw_url: str, database_override: str | None = None
) -> tuple[dict[str, str], str]:
    parsed = urlsplit(raw_url)

    if parsed.scheme not in {"ecto", "postgres", "postgresql"}:
        raise ValueError("DATABASE_URL must use ecto://, postgres://, or postgresql://")

    host = parsed.hostname
    username = unquote(parsed.username or "")
    database = unquote(parsed.path.lstrip("/"))
    password = unquote(parsed.password or "")

    if not host or not username or not database:
        raise ValueError("DATABASE_URL is missing its host, username, or database")

    try:
        port = str(parsed.port or 5432)
    except ValueError as error:
        raise ValueError("DATABASE_URL contains an invalid port") from error

    config = {
        "host": host,
        "port": port,
        "username": username,
        "database": database_override or database,
    }
    return config, password


def database_config(database_override: str | None = None) -> tuple[dict[str, str], str]:
    return parse_database_url(database_url(), database_override)


def make_pgpass(config: dict[str, str], password: str) -> str:
    def escape(value: str) -> str:
        return value.replace("\\", "\\\\").replace(":", "\\:")

    descriptor, path = tempfile.mkstemp(prefix="fittrack-pgpass-")
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as pgpass:
        pgpass.write(
            ":".join(
                escape(value)
                for value in (
                    config["host"],
                    config["port"],
                    config["database"],
                    config["username"],
                    password,
                )
            )
            + "\n"
        )
    return path


def connection_args(config: dict[str, str]) -> list[str]:
    return [
        "--host",
        config["host"],
        "--port",
        config["port"],
        "--username",
        config["username"],
        "--dbname",
        config["database"],
        "--no-password",
    ]


def run(command: list[str], *, env: dict[str, str] | None = None, **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=True, text=True, env=env, **kwargs)


def require_tools(*names: str) -> None:
    missing = [name for name in names if shutil.which(name) is None]
    if missing:
        raise RuntimeError(f"Required command(s) not installed: {', '.join(missing)}")


def positive_days(name: str, default: int) -> int:
    raw_value = os.environ.get(name, str(default))
    if not re.fullmatch(r"[1-9][0-9]*", raw_value):
        raise ValueError(f"{name} must be a positive integer")
    return int(raw_value)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_remote_checksum(backup: Path, remote_path: str) -> None:
    expected = sha256(backup)
    digest = hashlib.sha256()

    with tempfile.TemporaryFile() as error_output:
        process = subprocess.Popen(
            ["rclone", "cat", remote_path],
            stdout=subprocess.PIPE,
            stderr=error_output,
        )
        if process.stdout is None:
            raise RuntimeError("Could not read uploaded backup from R2")

        for chunk in iter(lambda: process.stdout.read(1024 * 1024), b""):
            digest.update(chunk)

        process.stdout.close()
        if process.wait() != 0:
            raise RuntimeError("Could not read uploaded backup from R2")

    if digest.hexdigest() != expected:
        raise ValueError("Uploaded R2 dump checksum does not match the local dump")


def write_checksum(backup: Path) -> Path:
    checksum = backup.with_name(backup.name + ".sha256")
    partial = checksum.with_name(checksum.name + ".partial")
    partial.write_text(f"{sha256(backup)}  {backup.name}\n", encoding="ascii")
    partial.chmod(0o600)
    os.replace(partial, checksum)
    return checksum


def verify_checksum(backup: Path) -> None:
    checksum_file = backup.with_name(backup.name + ".sha256")
    parts = checksum_file.read_text(encoding="ascii").strip().split(maxsplit=1)
    if len(parts) != 2 or parts[1].lstrip("* ") != backup.name:
        raise ValueError(f"Invalid checksum file: {checksum_file}")
    if sha256(backup) != parts[0]:
        raise ValueError(f"Checksum verification failed: {backup}")


def prune_local(backup_dir: Path, retention_days: int) -> None:
    cutoff = time.time() - retention_days * 24 * 60 * 60
    for backup in backup_dir.glob("fittrack-*.dump"):
        if backup.stat().st_mtime < cutoff:
            print(f"Local retention deleting expired backup: {backup.name}")
            backup.unlink()
            backup.with_name(backup.name + ".sha256").unlink(missing_ok=True)


def backup() -> None:
    require_tools("pg_dump", "pg_restore", "rclone")
    bucket = os.environ.get("FITTRACK_R2_BUCKET", "")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", bucket):
        raise ValueError("FITTRACK_R2_BUCKET must name an existing R2 bucket")

    remote_name = os.environ.get("FITTRACK_RCLONE_REMOTE", "r2")
    remotes = run(["rclone", "listremotes"], capture_output=True).stdout.splitlines()
    if f"{remote_name}:" not in remotes:
        raise ValueError(f"rclone remote {remote_name}: is not configured")

    backup_dir = Path(os.environ.get("FITTRACK_BACKUP_DIR", str(DEFAULT_BACKUP_DIR)))
    backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    backup_dir.chmod(0o700)
    local_retention = positive_days("FITTRACK_LOCAL_RETENTION_DAYS", 14)
    remote_retention = positive_days("FITTRACK_R2_RETENTION_DAYS", 90)

    with (backup_dir / ".backup.lock").open("a", encoding="ascii") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("A FitTrack PostgreSQL backup is already running.")
            return

        config, password = database_config()
        pgpass = make_pgpass(config, password)
        os.environ["PGPASSFILE"] = pgpass
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup_file = backup_dir / f"fittrack-{stamp}.dump"
        partial_file = backup_file.with_name(backup_file.name + ".partial")
        remote_dir = f"{remote_name}:{bucket}/postgres"

        try:
            run(
                [
                    "pg_dump",
                    *connection_args(config),
                    "--format=custom",
                    "--compress=6",
                    "--no-owner",
                    "--no-acl",
                    "--file",
                    str(partial_file),
                ]
            )
            run(["pg_restore", "--list", str(partial_file)], stdout=subprocess.DEVNULL)
            os.replace(partial_file, backup_file)
            backup_file.chmod(0o600)
            checksum_file = write_checksum(backup_file)
            verify_checksum(backup_file)
            print(f"Local checksum verified: {checksum_file.name}")

            remote_backup = f"{remote_dir}/{backup_file.name}"
            run(["rclone", "copyto", str(backup_file), remote_backup, "--immutable"])
            verify_remote_checksum(backup_file, remote_backup)
            print(f"R2 dump checksum verified: {backup_file.name}")
            run(
                [
                    "rclone",
                    "copyto",
                    str(checksum_file),
                    f"{remote_backup}.sha256",
                    "--immutable",
                ]
            )
            remote_checksum = run(
                ["rclone", "cat", f"{remote_backup}.sha256"],
                capture_output=True,
            ).stdout
            expected_checksum = checksum_file.read_text(encoding="ascii")
            if remote_checksum != expected_checksum:
                raise ValueError("Uploaded checksum sidecar did not match the local checksum")
            print(f"R2 checksum sidecar verified: {backup_file.name}.sha256")

            retention_command = [
                "rclone",
                "delete",
                remote_dir,
                "--min-age",
                f"{remote_retention}d",
                "--include",
                "fittrack-*.dump",
                "--include",
                "fittrack-*.dump.sha256",
            ]
            retention_preview = run(
                [*retention_command, "--dry-run", "-v"],
                capture_output=True,
            )
            preview_output = "\n".join(
                output.strip()
                for output in (retention_preview.stdout, retention_preview.stderr)
                if output.strip()
            )
            if preview_output:
                print("R2 retention dry run:")
                print(preview_output)
            else:
                print("R2 retention dry run: no expired backup objects")
            run(retention_command)
            prune_local(backup_dir, local_retention)
            print(f"Backup uploaded and verified: {backup_file.name}")
        finally:
            Path(pgpass).unlink(missing_ok=True)
            partial_file.unlink(missing_ok=True)
            os.environ.pop("PGPASSFILE", None)


def restore(backup_path: str) -> None:
    require_tools("pg_restore", "psql")
    backup_file = Path(backup_path).expanduser().resolve(strict=True)
    verify_checksum(backup_file)

    restore_database = os.environ.get("FITTRACK_RESTORE_DATABASE", "")
    if not restore_database:
        raise ValueError("Set FITTRACK_RESTORE_DATABASE to a separate, empty database")

    source_config, password = database_config()
    production_database = os.environ.get("FITTRACK_PRODUCTION_DATABASE", "fittrack_prod")
    if restore_database in {source_config["database"], production_database}:
        raise ValueError("Refusing to restore into the configured production database")

    config, _ = database_config(restore_database)
    pgpass = make_pgpass(config, password)
    environment = os.environ.copy()
    environment["PGPASSFILE"] = pgpass

    empty_database_query = """
      SELECT count(*)
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND n.nspname NOT LIKE 'pg_toast%'
        AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
    """

    try:
        result = run(
            ["psql", *connection_args(config), "--tuples-only", "--no-align", "--command", empty_database_query],
            env=environment,
            capture_output=True,
        )
        if result.stdout.strip() != "0":
            raise ValueError(f"Restore target {restore_database} is not empty")

        run(
            [
                "pg_restore",
                *connection_args(config),
                "--exit-on-error",
                "--no-owner",
                "--no-acl",
                str(backup_file),
            ],
            env=environment,
        )
        print(f"Restore completed to separate database: {restore_database}")
    finally:
        Path(pgpass).unlink(missing_ok=True)


def restore_verification() -> None:
    require_tools("pg_restore", "psql", "rclone")
    restore_url = os.environ.get("FITTRACK_RESTORE_DATABASE_URL", "")
    if not restore_url:
        raise ValueError("FITTRACK_RESTORE_DATABASE_URL must use a separate CREATEDB test role")

    restore_config, password = parse_database_url(restore_url)
    if restore_config["database"] not in {"postgres", "template1"}:
        raise ValueError("FITTRACK_RESTORE_DATABASE_URL must connect to postgres or template1")
    if restore_config["username"] == "fittrack":
        raise ValueError("Restore verification must not use the production fittrack role")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,62}", restore_config["username"]):
        raise ValueError("Restore verification role must be a simple PostgreSQL identifier")

    remote_name = os.environ.get("FITTRACK_RCLONE_REMOTE", "r2")
    bucket = os.environ.get("FITTRACK_R2_BUCKET", "fittrack-backups")
    remote_dir = f"{remote_name}:{bucket}/postgres"
    listing = run(["rclone", "lsf", remote_dir, "--files-only"], capture_output=True).stdout
    backup_names = [
        name
        for name in listing.splitlines()
        if re.fullmatch(r"fittrack-\d{8}T\d{6}Z\.dump", name)
    ]
    if not backup_names:
        raise ValueError(f"No FitTrack dumps found in {remote_dir}")

    backup_name = max(backup_names)
    scratch_database = f"fittrack_restore_verify_{secrets.token_hex(6)}"
    scratch_config = {**restore_config, "database": scratch_database}
    base_pgpass = make_pgpass(restore_config, password)
    scratch_pgpass = make_pgpass(scratch_config, password)
    base_environment = os.environ.copy()
    base_environment["PGPASSFILE"] = base_pgpass
    scratch_environment = os.environ.copy()
    scratch_environment["PGPASSFILE"] = scratch_pgpass
    database_created = False

    try:
        with tempfile.TemporaryDirectory(prefix="fittrack-restore-verify-") as temp_dir:
            backup_file = Path(temp_dir) / backup_name
            checksum_file = backup_file.with_name(backup_file.name + ".sha256")
            remote_backup = f"{remote_dir}/{backup_name}"
            run(["rclone", "copyto", remote_backup, str(backup_file)])
            run(["rclone", "copyto", f"{remote_backup}.sha256", str(checksum_file)])
            verify_checksum(backup_file)
            run(["pg_restore", "--list", str(backup_file)], stdout=subprocess.DEVNULL)

            run(
                [
                    "psql",
                    *connection_args(restore_config),
                    "--command",
                    f'CREATE DATABASE "{scratch_database}" OWNER "{restore_config["username"]}"',
                ],
                env=base_environment,
                stdout=subprocess.DEVNULL,
            )
            database_created = True

            run(
                [
                    "pg_restore",
                    *connection_args(scratch_config),
                    "--exit-on-error",
                    "--no-owner",
                    "--no-acl",
                    str(backup_file),
                ],
                env=scratch_environment,
            )

            integrity_query = (
                "SELECT current_database() = "
                f"'{scratch_database}' AND "
                "to_regclass('public.schema_migrations') IS NOT NULL AND "
                "to_regclass('public.users') IS NOT NULL AND "
                "to_regclass('public.exercise_templates') IS NOT NULL"
            )
            integrity_result = run(
                [
                    "psql",
                    *connection_args(scratch_config),
                    "--tuples-only",
                    "--no-align",
                    "--command",
                    integrity_query,
                ],
                env=scratch_environment,
                capture_output=True,
            ).stdout.strip()
            if integrity_result != "t":
                raise ValueError("Restored database failed required relation/database checks")

            migration_count = run(
                [
                    "psql",
                    *connection_args(scratch_config),
                    "--tuples-only",
                    "--no-align",
                    "--command",
                    "SELECT count(*) FROM public.schema_migrations",
                ],
                env=scratch_environment,
                capture_output=True,
            ).stdout.strip()
            if not migration_count.isdigit() or int(migration_count) == 0:
                raise ValueError("Restored database has no applied Ecto migrations")

            print(
                f"Restore checks passed for {backup_name}: "
                f"required tables present, migrations={migration_count}"
            )
    finally:
        try:
            if database_created:
                run(
                    [
                        "psql",
                        *connection_args(restore_config),
                        "--command",
                        f'DROP DATABASE "{scratch_database}"',
                    ],
                    env=base_environment,
                    stdout=subprocess.DEVNULL,
                )
                print(f"Temporary database removed: {scratch_database}")
        finally:
            Path(base_pgpass).unlink(missing_ok=True)
            Path(scratch_pgpass).unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("backup", help="dump, verify, and upload the production database")
    restore_parser = subparsers.add_parser("restore", help="restore a dump to a separate empty database")
    restore_parser.add_argument("backup_file", help="path to a dump and its adjacent .sha256 file")
    subparsers.add_parser(
        "restore-verify",
        help="restore the newest R2 dump to a temporary database and drop it after integrity checks",
    )
    arguments = parser.parse_args()

    try:
        if arguments.command == "backup":
            backup()
        elif arguments.command == "restore":
            restore(arguments.backup_file)
        else:
            restore_verification()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"FitTrack PostgreSQL {arguments.command} failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
