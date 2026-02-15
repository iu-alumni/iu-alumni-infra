#!/bin/bash
# This script runs on first PostgreSQL startup to create multiple databases.
# It's mounted into /docker-entrypoint-initdb.d/

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE iu_alumni_db;
    CREATE DATABASE bot_db;
EOSQL

echo "Created databases: iu_alumni_db, bot_db"
