#!/usr/bin/env bash
# scripts/restore.sh - Restore a PostgreSQL backup into the running stack
#
# Usage:
#   restore.sh              — interactive: list backups and prompt for choice
#   restore.sh <file>       — non-interactive: restore a specific backup file
#
# Environment variables (loaded from $DEPLOY_DIR/.env if present):
#   DEPLOY_DIR      Base directory on the server (default: /home/deploy/iu-alumni)
#   POSTGRES_USER   Database superuser (required)
#   POSTGRES_DB     Database name to restore into (required)

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/deploy/iu-alumni}"
BACKUP_DIR="$DEPLOY_DIR/data/backups"
ENV_FILE="$DEPLOY_DIR/.env"
STACK_NAME="iu_alumni_infra"

# ── Load environment ─────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    set -a && . "$ENV_FILE" && set +a
fi

POSTGRES_USER="${POSTGRES_USER:?POSTGRES_USER must be set in $ENV_FILE}"
POSTGRES_DB="${POSTGRES_DB:?POSTGRES_DB must be set in $ENV_FILE}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set in $ENV_FILE}"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die()  { echo "Error: $*" >&2; exit 1; }

# ── Resolve the backup file ──────────────────────────────────────────────────

if [[ $# -ge 1 ]]; then
    # Non-interactive: file path passed directly
    BACKUP_FILE="$1"
else
    # Interactive: list available backups and let the user choose
    mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 3 -name "*.sql.gz" | sort -r)

    if [[ ${#BACKUPS[@]} -eq 0 ]]; then
        die "No backup files found in $BACKUP_DIR"
    fi

    echo "Available backups:"
    for i in "${!BACKUPS[@]}"; do
        printf "  %3d) %s\n" "$((i + 1))" "$(basename "${BACKUPS[$i]}")"
    done
    echo

    read -rp "Enter selection (1-${#BACKUPS[@]}): " CHOICE

    # Validate: must be an integer in range
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#BACKUPS[@]} )); then
        die "Invalid selection: $CHOICE (must be between 1 and ${#BACKUPS[@]})"
    fi

    BACKUP_FILE="${BACKUPS[$((CHOICE - 1))]}"
fi

# ── Validate file exists ─────────────────────────────────────────────────────

[[ -f "$BACKUP_FILE" ]] || die "File not found: $BACKUP_FILE"

# ── Confirm before restoring ─────────────────────────────────────────────────

log "Selected backup: $(basename "$BACKUP_FILE")"
echo
echo "WARNING: This will DROP and recreate the '$POSTGRES_DB' database."
read -rp "Type 'yes' to continue: " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Aborted."; exit 0; }

# ── Restore ──────────────────────────────────────────────────────────────────

POSTGRES_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_postgres" --format "{{.ID}}" | head -1)
[[ -n "$POSTGRES_CONTAINER" ]] || die "Postgres container not found — is the stack running?"

log "Dropping and recreating database '$POSTGRES_DB'..."
docker exec -i "$POSTGRES_CONTAINER" \
    psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\";"
docker exec -i "$POSTGRES_CONTAINER" \
    psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"$POSTGRES_DB\";"

log "Restoring from $(basename "$BACKUP_FILE")..."
gunzip -c "$BACKUP_FILE" | docker exec -i "$POSTGRES_CONTAINER" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

log "Restore complete."
