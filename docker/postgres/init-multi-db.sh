#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE USER nemmcp WITH PASSWORD 'nemmcp';
  CREATE DATABASE nemmcp OWNER nemmcp;

  CREATE USER knowhub WITH PASSWORD 'knowhub_dev';
  CREATE DATABASE knowhub OWNER knowhub;

  CREATE USER mimir WITH PASSWORD 'mimir_dev_password';
  CREATE DATABASE mimir OWNER mimir;

  CREATE USER classification WITH PASSWORD 'classification_dev';
  CREATE DATABASE classification OWNER classification;

  CREATE USER comms WITH PASSWORD 'comms_dev';
  CREATE DATABASE comms OWNER comms;
EOSQL
