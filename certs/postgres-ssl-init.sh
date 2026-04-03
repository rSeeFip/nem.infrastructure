#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# PostgreSQL TLS Initialization Script
# ═══════════════════════════════════════════════════════════════════════════════
# Mounted as an init script in docker-compose.tls.yml.
# Copies TLS certificates and configures PostgreSQL to accept SSL connections.
#
# ⚠️  DEV ONLY — Do NOT use in production.
# ═══════════════════════════════════════════════════════════════════════════════
set -e

CERT_SRC="/etc/postgresql/certs"
PG_DATA="/var/lib/postgresql/data"

echo "=== PostgreSQL TLS Init ==="

# Certificates are mounted read-only from host; PostgreSQL needs them
# owned by the postgres user (UID 999 in official image).
# Copy to data dir where postgres can read them with correct permissions.
if [ -f "${CERT_SRC}/postgres.crt" ]; then
  cp "${CERT_SRC}/postgres.crt" "${PG_DATA}/server.crt"
  cp "${CERT_SRC}/postgres.key" "${PG_DATA}/server.key"
  cp "${CERT_SRC}/ca-chain.crt" "${PG_DATA}/root.crt"

  # PostgreSQL requires key to be readable only by owner
  chmod 600 "${PG_DATA}/server.key"
  chmod 644 "${PG_DATA}/server.crt"
  chmod 644 "${PG_DATA}/root.crt"
  chown postgres:postgres "${PG_DATA}/server.crt" "${PG_DATA}/server.key" "${PG_DATA}/root.crt"

  echo "TLS certificates installed to ${PG_DATA}"
  echo "  server.crt: $(openssl x509 -in ${PG_DATA}/server.crt -noout -subject 2>/dev/null)"
  echo "  root.crt:   CA chain for client verification"
else
  echo "WARNING: No TLS certificates found at ${CERT_SRC}. SSL will not be configured."
  exit 0
fi

# Append SSL config to postgresql.conf if not already present
PG_CONF="${PG_DATA}/postgresql.conf"
if [ -f "$PG_CONF" ]; then
  if ! grep -q "^ssl = on" "$PG_CONF" 2>/dev/null; then
    cat >> "$PG_CONF" <<-PGEOF

# ─── TLS Configuration (DEV ONLY) ────────────────────────────────────────────
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'
# ssl_crl_file = ''
PGEOF
    echo "SSL configuration appended to postgresql.conf"
  else
    echo "SSL already configured in postgresql.conf"
  fi
fi

echo "=== PostgreSQL TLS Init Complete ==="
