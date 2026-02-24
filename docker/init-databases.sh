#!/bin/bash
# This script runs on first PostgreSQL startup to create databases.
# It's mounted into /docker-entrypoint-initdb.d/

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE $POSTGRES_DB;
EOSQL

echo "Created database: $POSTGRES_DB"
