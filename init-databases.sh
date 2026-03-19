#!/bin/bash
set -e

for db in mcp knowhub holisticworld assetcore mediahub mimir homeassistant scheduler; do
  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE "$db";
EOSQL
done

echo "All databases created successfully!"
