#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-profitcenter}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

export PGPASSWORD="$DB_PASSWORD"

psql \
  --host "$DB_HOST" \
  --port "$DB_PORT" \
  --username "$DB_USER" \
  --dbname "$DB_NAME" <<'SQL'
INSERT INTO profit_center.cost_events (
  idempotency_key,
  schema_version,
  event_time,
  service_id,
  tenant_id,
  team_id,
  profit_center_id,
  resource_type,
  usage_quantity,
  usage_unit,
  raw_cost,
  amortized_cost,
  currency,
  tags,
  namespace,
  pod_name
)
VALUES
  ('seed-api-gateway-01', '1.0', NOW() - INTERVAL '2 days',  'api-gateway',     'tenant-a', 'team-123', 'pc-core',     'compute',   12, 'request', 18.25, 18.25, 'USD', '{"cluster":"cluster-a","cluster_id":"cluster-a"}'::jsonb, 'gateway', 'api-gateway-7f9d'),
  ('seed-api-gateway-02', '1.0', NOW() - INTERVAL '6 days',  'api-gateway',     'tenant-a', 'team-123', 'pc-core',     'network',   42, 'gb',      11.10, 11.10, 'USD', '{"cluster":"cluster-a","cluster_id":"cluster-a"}'::jsonb, 'gateway', 'api-gateway-7f9d'),
  ('seed-mimir-01',       '1.0', NOW() - INTERVAL '3 days',  'mimir',           'tenant-a', 'team-123', 'pc-ai',       'compute',   80, 'tokens',   9.75,  9.75, 'USD', '{"cluster":"cluster-a","cluster_id":"cluster-a"}'::jsonb, 'ai',      'mimir-5c66'),
  ('seed-mimir-02',       '1.0', NOW() - INTERVAL '14 days', 'mimir',           'tenant-a', 'team-123', 'pc-ai',       'k8s',       15, 'pod-hour', 7.90,  7.90, 'USD', '{"cluster":"cluster-a","cluster_id":"cluster-a"}'::jsonb, 'ai',      'mimir-5c66'),
  ('seed-sentinel-01',    '1.0', NOW() - INTERVAL '4 days',  'sentinel',        'tenant-b', 'team-456', 'pc-ops',      'compute',   10, 'run',      5.20,  5.20, 'USD', '{"cluster":"cluster-b","cluster_id":"cluster-b"}'::jsonb, 'ops',     'sentinel-886c'),
  ('seed-sentinel-02',    '1.0', NOW() - INTERVAL '20 days', 'sentinel',        'tenant-b', 'team-456', 'pc-ops',      'messaging', 18, 'message',  4.80,  4.80, 'USD', '{"cluster":"cluster-b","cluster_id":"cluster-b"}'::jsonb, 'ops',     'sentinel-886c'),
  ('seed-hw-01',          '1.0', NOW() - INTERVAL '8 days',  'holistic-world',  'tenant-b', 'team-456', 'pc-digital',  'storage',   25, 'reading',   6.40,  6.40, 'USD', '{"cluster":"cluster-b","cluster_id":"cluster-b"}'::jsonb, 'twins',   'holistic-world-01'),
  ('seed-hw-02',          '1.0', NOW() - INTERVAL '16 days', 'holistic-world',  'tenant-b', 'team-456', 'pc-digital',  'messaging', 31, 'message',   3.95,  3.95, 'USD', '{"cluster":"cluster-b","cluster_id":"cluster-b"}'::jsonb, 'twins',   'holistic-world-01'),
  ('seed-k8s-01',         '1.0', NOW() - INTERVAL '9 days',  'platform-k8s',    'tenant-a', 'team-123', 'pc-platform', 'k8s',       22, 'node-hour', 14.60, 14.60, 'USD', '{"cluster":"cluster-a","cluster_id":"cluster-a"}'::jsonb, 'shared',  'node-a-01'),
  ('seed-k8s-02',         '1.0', NOW() - INTERVAL '22 days', 'platform-k8s',    'tenant-b', 'team-456', 'pc-platform', 'k8s',       18, 'node-hour', 12.10, 12.10, 'USD', '{"cluster":"cluster-b","cluster_id":"cluster-b"}'::jsonb, 'shared',  'node-b-02');
SQL

echo "Seeded profit_center.cost_events with sample cost data."
