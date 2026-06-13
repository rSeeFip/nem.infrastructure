#!/bin/bash
set -e

for db in mcp knowhub holisticworld assetcore mediahub mimir homeassistant scheduler keycloak profitcenter; do
  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE "$db";
EOSQL
done

echo "Enabling TimescaleDB extension on profitcenter"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname profitcenter <<-EOSQL
  CREATE EXTENSION IF NOT EXISTS timescaledb;
EOSQL

echo "All databases created successfully!"
