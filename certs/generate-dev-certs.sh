#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# nem.* Ecosystem — Development Certificate Generator
# ═══════════════════════════════════════════════════════════════════════════════
#
# Generates a complete PKI hierarchy for local mTLS development:
#   Root CA → Intermediate CA → Service Certificates + Client Certificates
#
# ⚠️  DEV ONLY — Do NOT use these certificates in production.
#
# Usage:
#   ./generate-dev-certs.sh              # Generate all certs (skip existing)
#   ./generate-dev-certs.sh --force      # Regenerate everything
#   ./generate-dev-certs.sh --service X  # Generate cert for service X only
#
# Environment Variables (optional overrides):
#   CERT_OUTPUT_DIR   — Output directory (default: ./output)
#   CA_VALIDITY_DAYS  — Root CA validity in days (default: 3650)
#   ICA_VALIDITY_DAYS — Intermediate CA validity (default: 1825)
#   SVC_VALIDITY_DAYS — Service cert validity (default: 365)
#   KEY_SIZE          — RSA key size in bits (default: 4096)
#
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${CERT_OUTPUT_DIR:-${SCRIPT_DIR}/output}"

CA_VALIDITY_DAYS="${CA_VALIDITY_DAYS:-3650}"
ICA_VALIDITY_DAYS="${ICA_VALIDITY_DAYS:-1825}"
SVC_VALIDITY_DAYS="${SVC_VALIDITY_DAYS:-365}"
KEY_SIZE="${KEY_SIZE:-4096}"

# Organization details for certificate subjects
ORG_COUNTRY="NL"
ORG_STATE="Noord-Holland"
ORG_LOCALITY="Amsterdam"
ORG_NAME="nem Development"
ORG_UNIT="Engineering"

# Services that need server certificates
# Each entry: "service_name:dns_alt_names:ip_sans"
SERVICES=(
  "postgres:nem-postgres,localhost,postgres:127.0.0.1"
  "rabbitmq:nem-rabbitmq,localhost,rabbitmq:127.0.0.1"
  "keycloak:nem-keycloak,localhost,keycloak:127.0.0.1"
  "gateway:nem-gateway,localhost,gateway:127.0.0.1"
  "mcp:nem-mcp,localhost,mcp:127.0.0.1"
  "knowhub:nem-knowhub,localhost,knowhub:127.0.0.1"
  "holisticworld:nem-holisticworld,localhost,holisticworld:127.0.0.1"
  "assetcore:nem-assetcore,localhost,assetcore:127.0.0.1"
  "mediahub:nem-mediahub,localhost,mediahub:127.0.0.1"
  "mimir:nem-mimir,localhost,mimir:127.0.0.1"
  "scheduler:nem-scheduler,localhost,scheduler:127.0.0.1"
  "workflow:nem-workflow,localhost,workflow:127.0.0.1"
  "inferencegateway:nem-inferencegateway,localhost,inferencegateway:127.0.0.1"
)

# Client certificates for service-to-service mTLS
CLIENT_SERVICES=(
  "mcp-client"
  "knowhub-client"
  "holisticworld-client"
  "assetcore-client"
  "mediahub-client"
  "mimir-client"
  "scheduler-client"
  "workflow-client"
  "inferencegateway-client"
  "gateway-client"
)

# ─── CLI Parsing ──────────────────────────────────────────────────────────────

FORCE=false
SINGLE_SERVICE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    --service)
      SINGLE_SERVICE="$2"
      shift 2
      ;;
    --help|-h)
      head -25 "$0" | tail -20
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ─── Helper Functions ─────────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*" >&2; }
error() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

check_openssl() {
  command -v openssl >/dev/null 2>&1 || error "OpenSSL is required but not installed."
  log "Using $(openssl version)"
}

should_generate() {
  local file="$1"
  if [[ "$FORCE" == "true" ]]; then
    return 0
  fi
  if [[ -f "$file" ]]; then
    log "  ↳ Skipping (exists): $file"
    return 1
  fi
  return 0
}

# ─── Root CA ──────────────────────────────────────────────────────────────────

generate_root_ca() {
  local ca_dir="${OUTPUT_DIR}/ca"
  mkdir -p "$ca_dir"

  if ! should_generate "${ca_dir}/root-ca.crt"; then
    return
  fi

  log "🔐 Generating Root CA..."

  # Generate Root CA private key
  openssl genrsa -out "${ca_dir}/root-ca.key" "$KEY_SIZE" 2>/dev/null

  # Generate Root CA certificate
  openssl req -new -x509 \
    -key "${ca_dir}/root-ca.key" \
    -out "${ca_dir}/root-ca.crt" \
    -days "$CA_VALIDITY_DAYS" \
    -subj "/C=${ORG_COUNTRY}/ST=${ORG_STATE}/L=${ORG_LOCALITY}/O=${ORG_NAME}/OU=${ORG_UNIT}/CN=nem Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash" \
    2>/dev/null

  # Set restrictive permissions on CA key
  chmod 400 "${ca_dir}/root-ca.key"
  chmod 444 "${ca_dir}/root-ca.crt"

  log "  ↳ Root CA: ${ca_dir}/root-ca.crt"
}

# ─── Intermediate CA ─────────────────────────────────────────────────────────

generate_intermediate_ca() {
  local ca_dir="${OUTPUT_DIR}/ca"
  local ica_dir="${OUTPUT_DIR}/intermediate"
  mkdir -p "$ica_dir"

  if ! should_generate "${ica_dir}/intermediate-ca.crt"; then
    return
  fi

  log "🔐 Generating Intermediate CA..."

  # Generate Intermediate CA private key
  openssl genrsa -out "${ica_dir}/intermediate-ca.key" "$KEY_SIZE" 2>/dev/null

  # Generate CSR for Intermediate CA
  openssl req -new \
    -key "${ica_dir}/intermediate-ca.key" \
    -out "${ica_dir}/intermediate-ca.csr" \
    -subj "/C=${ORG_COUNTRY}/ST=${ORG_STATE}/L=${ORG_LOCALITY}/O=${ORG_NAME}/OU=${ORG_UNIT}/CN=nem Intermediate CA" \
    2>/dev/null

  # Sign Intermediate CA with Root CA
  openssl x509 -req \
    -in "${ica_dir}/intermediate-ca.csr" \
    -CA "${ca_dir}/root-ca.crt" \
    -CAkey "${ca_dir}/root-ca.key" \
    -CAcreateserial \
    -out "${ica_dir}/intermediate-ca.crt" \
    -days "$ICA_VALIDITY_DAYS" \
    -extfile <(cat <<EOF
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
    ) 2>/dev/null

  # Create CA chain (Intermediate + Root)
  cat "${ica_dir}/intermediate-ca.crt" "${ca_dir}/root-ca.crt" > "${OUTPUT_DIR}/ca-chain.crt"

  # Clean up CSR
  rm -f "${ica_dir}/intermediate-ca.csr"

  chmod 400 "${ica_dir}/intermediate-ca.key"
  chmod 444 "${ica_dir}/intermediate-ca.crt"
  chmod 444 "${OUTPUT_DIR}/ca-chain.crt"

  log "  ↳ Intermediate CA: ${ica_dir}/intermediate-ca.crt"
  log "  ↳ CA chain: ${OUTPUT_DIR}/ca-chain.crt"
}

# ─── Server Certificate ──────────────────────────────────────────────────────

generate_server_cert() {
  local service_name="$1"
  local dns_names="$2"
  local ip_sans="$3"

  local cert_dir="${OUTPUT_DIR}/services/${service_name}"
  mkdir -p "$cert_dir"

  if ! should_generate "${cert_dir}/${service_name}.crt"; then
    return
  fi

  log "📜 Generating server certificate: ${service_name}"

  local ica_dir="${OUTPUT_DIR}/intermediate"

  # Generate service private key
  openssl genrsa -out "${cert_dir}/${service_name}.key" 2048 2>/dev/null

  # Build SAN extension
  local san="DNS:${service_name}"
  IFS=',' read -ra NAMES <<< "$dns_names"
  for name in "${NAMES[@]}"; do
    san="${san},DNS:${name}"
  done
  IFS=',' read -ra IPS <<< "$ip_sans"
  for ip in "${IPS[@]}"; do
    san="${san},IP:${ip}"
  done

  # Generate CSR
  openssl req -new \
    -key "${cert_dir}/${service_name}.key" \
    -out "${cert_dir}/${service_name}.csr" \
    -subj "/C=${ORG_COUNTRY}/ST=${ORG_STATE}/O=${ORG_NAME}/OU=${ORG_UNIT}/CN=${service_name}.nem.local" \
    2>/dev/null

  # Sign with Intermediate CA
  openssl x509 -req \
    -in "${cert_dir}/${service_name}.csr" \
    -CA "${ica_dir}/intermediate-ca.crt" \
    -CAkey "${ica_dir}/intermediate-ca.key" \
    -CAcreateserial \
    -out "${cert_dir}/${service_name}.crt" \
    -days "$SVC_VALIDITY_DAYS" \
    -extfile <(cat <<EOF
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
subjectAltName = ${san}
EOF
    ) 2>/dev/null

  # Create full chain cert (server + intermediate + root)
  cat "${cert_dir}/${service_name}.crt" \
      "${ica_dir}/intermediate-ca.crt" \
      "${OUTPUT_DIR}/ca/root-ca.crt" \
      > "${cert_dir}/${service_name}-fullchain.crt"

  # Create PFX/PKCS12 for .NET services
  openssl pkcs12 -export \
    -out "${cert_dir}/${service_name}.pfx" \
    -inkey "${cert_dir}/${service_name}.key" \
    -in "${cert_dir}/${service_name}.crt" \
    -certfile "${OUTPUT_DIR}/ca-chain.crt" \
    -passout pass:dev-only \
    2>/dev/null

  # Clean up CSR
  rm -f "${cert_dir}/${service_name}.csr"

  chmod 400 "${cert_dir}/${service_name}.key"
  chmod 444 "${cert_dir}/${service_name}.crt"
  chmod 444 "${cert_dir}/${service_name}-fullchain.crt"
  chmod 444 "${cert_dir}/${service_name}.pfx"

  log "  ↳ ${cert_dir}/${service_name}.crt (+ .key, -fullchain.crt, .pfx)"
}

# ─── Client Certificate ──────────────────────────────────────────────────────

generate_client_cert() {
  local client_name="$1"

  local cert_dir="${OUTPUT_DIR}/clients/${client_name}"
  mkdir -p "$cert_dir"

  if ! should_generate "${cert_dir}/${client_name}.crt"; then
    return
  fi

  log "🔑 Generating client certificate: ${client_name}"

  local ica_dir="${OUTPUT_DIR}/intermediate"

  # Generate client private key
  openssl genrsa -out "${cert_dir}/${client_name}.key" 2048 2>/dev/null

  # Generate CSR
  openssl req -new \
    -key "${cert_dir}/${client_name}.key" \
    -out "${cert_dir}/${client_name}.csr" \
    -subj "/C=${ORG_COUNTRY}/ST=${ORG_STATE}/O=${ORG_NAME}/OU=${ORG_UNIT}/CN=${client_name}.nem.local" \
    2>/dev/null

  # Sign with Intermediate CA
  openssl x509 -req \
    -in "${cert_dir}/${client_name}.csr" \
    -CA "${ica_dir}/intermediate-ca.crt" \
    -CAkey "${ica_dir}/intermediate-ca.key" \
    -CAcreateserial \
    -out "${cert_dir}/${client_name}.crt" \
    -days "$SVC_VALIDITY_DAYS" \
    -extfile <(cat <<EOF
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
    ) 2>/dev/null

  # Create PFX/PKCS12 for .NET services
  openssl pkcs12 -export \
    -out "${cert_dir}/${client_name}.pfx" \
    -inkey "${cert_dir}/${client_name}.key" \
    -in "${cert_dir}/${client_name}.crt" \
    -certfile "${OUTPUT_DIR}/ca-chain.crt" \
    -passout pass:dev-only \
    2>/dev/null

  # Clean up CSR
  rm -f "${cert_dir}/${client_name}.csr"

  chmod 400 "${cert_dir}/${client_name}.key"
  chmod 444 "${cert_dir}/${client_name}.crt"
  chmod 444 "${cert_dir}/${client_name}.pfx"

  log "  ↳ ${cert_dir}/${client_name}.crt (+ .key, .pfx)"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  log "═══════════════════════════════════════════════════════════════"
  log "nem.* Development Certificate Generator"
  log "═══════════════════════════════════════════════════════════════"
  log ""
  log "⚠️  DEV ONLY — These certificates are NOT for production use."
  log ""
  log "Output directory: ${OUTPUT_DIR}"
  log "Force regenerate: ${FORCE}"
  [[ -n "$SINGLE_SERVICE" ]] && log "Single service: ${SINGLE_SERVICE}"
  log ""

  check_openssl

  if [[ "$FORCE" == "true" && -d "$OUTPUT_DIR" ]]; then
    log "🗑️  Removing existing certificates..."
    rm -rf "$OUTPUT_DIR"
  fi

  mkdir -p "$OUTPUT_DIR"

  # Always need CAs
  generate_root_ca
  generate_intermediate_ca

  log ""
  log "─── Server Certificates ────────────────────────────────────────"

  for entry in "${SERVICES[@]}"; do
    IFS=':' read -r svc_name dns_names ip_sans <<< "$entry"

    if [[ -n "$SINGLE_SERVICE" && "$svc_name" != "$SINGLE_SERVICE" ]]; then
      continue
    fi

    generate_server_cert "$svc_name" "$dns_names" "$ip_sans"
  done

  log ""
  log "─── Client Certificates ────────────────────────────────────────"

  if [[ -z "$SINGLE_SERVICE" ]]; then
    for client in "${CLIENT_SERVICES[@]}"; do
      generate_client_cert "$client"
    done
  fi

  log ""
  log "─── Summary ────────────────────────────────────────────────────"
  log ""
  log "Certificate hierarchy:"
  log "  Root CA (${CA_VALIDITY_DAYS} days)"
  log "  └── Intermediate CA (${ICA_VALIDITY_DAYS} days)"
  log "      ├── Server certs (${SVC_VALIDITY_DAYS} days)"
  log "      └── Client certs (${SVC_VALIDITY_DAYS} days)"
  log ""
  log "Key files:"
  log "  CA chain:     ${OUTPUT_DIR}/ca-chain.crt"
  log "  Root CA:      ${OUTPUT_DIR}/ca/root-ca.crt"
  log "  Service certs: ${OUTPUT_DIR}/services/<name>/"
  log "  Client certs:  ${OUTPUT_DIR}/clients/<name>/"
  log ""
  log "PFX password:   dev-only"
  log ""
  log "✅ Certificate generation complete."
}

main "$@"
