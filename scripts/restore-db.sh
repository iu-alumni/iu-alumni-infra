#!/usr/bin/env bash
# Restore a PostgreSQL backup into the running Docker Swarm postgres container.
#
# Usage:
#   ./restore-db.sh                          # interactive: picks latest backup
#   ./restore-db.sh <path-to-backup.sql.gz>  # use a specific backup file
#
# The script reads POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB from
# $DEPLOY_DIR/.env (default: ~/iu-alumni/.env).

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-$HOME/iu-alumni}"
ENV_FILE="$DEPLOY_DIR/.env"
BACKUP_DIR="$DEPLOY_DIR/data/backups"

# ── Load env vars ────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set}"
: "${POSTGRES_DB:?POSTGRES_DB not set}"

# ── Pick backup file ─────────────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
  BACKUP_FILE="$1"
else
  echo "Available backups (newest first):"
  ls -lt "$BACKUP_DIR"/*.sql.gz 2>/dev/null | awk '{print NR". "$NF}' || {
    echo "No backups found in $BACKUP_DIR"
    exit 1
  }
  echo
  read -rp "Enter number (or full path): " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.sql.gz | sed -n "${CHOICE}p")
  else
    BACKUP_FILE="$CHOICE"
  fi
fi

[[ -f "$BACKUP_FILE" ]] || { echo "File not found: $BACKUP_FILE"; exit 1; }

# ── Find postgres container ──────────────────────────────────────────────────
CONTAINER=$(docker ps --filter name=postgres --format '{{.Names}}' | head -1)
[[ -n "$CONTAINER" ]] || { echo "No running postgres container found"; exit 1; }

echo "Backup file : $BACKUP_FILE"
echo "Container   : $CONTAINER"
echo "Database    : $POSTGRES_DB"
echo
read -rp "This will DROP and recreate '$POSTGRES_DB'. Continue? [y/N] " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ── Drop & recreate database ─────────────────────────────────────────────────
echo "Dropping and recreating database..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  psql -U "$POSTGRES_USER" -d postgres \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$POSTGRES_DB' AND pid <> pg_backend_pid();" \
  -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\";" \
  -c "CREATE DATABASE \"$POSTGRES_DB\";"

# ── Restore ──────────────────────────────────────────────────────────────────
echo "Restoring backup..."
gunzip -c "$BACKUP_FILE" | \
  docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

echo "Restore complete."
